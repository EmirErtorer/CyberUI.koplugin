-- The one full-screen window CyberUI lives in. It paints the current screen's
-- element tree and an optional overlay (dialog or toast), turns touches into
-- taps, holds and swipes on elements, and gives instant press feedback.

local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local Paint = require("cyberui/gfx/paint")
local Perf = require("cyberui/perf")
local Theme = require("cyberui/theme")

local Screen = Device.screen

local Host = InputContainer:extend({
    name = "cyberui",
    covers_fullscreen = true,
    root = nil,        -- element tree of the current screen
    overlay = nil,     -- dialog element shown over it
    toast = nil,       -- notice element at the top
})

-- Full-screen gesture ranges and the Back key.
function Host:init()
    self.dimen = Geom:new({ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() })
    local whole = function() return self.dimen end
    self.ges_events = {
        Tap = { GestureRange:new({ ges = "tap", range = whole }) },
        Hold = { GestureRange:new({ ges = "hold", range = whole }) },
        Swipe = { GestureRange:new({ ges = "swipe", range = whole }) },
    }
    if Device:hasKeys() then self.key_events.Back = { { "Back" } } end
end

-- Lay out the tree and overlays for the current screen size.
function Host:relayout()
    local w, h = Screen:getWidth(), Screen:getHeight()
    self.dimen.w, self.dimen.h = w, h
    if self.root then self.root:layout(w, h) end
    if self.overlay then self.overlay:layout(self.overlay:naturalWidth() or w, nil) end
    if self.toast then self.toast:layout(nil, nil) end
    self.laid_w, self.laid_h = w, h
end

-- Show a new element tree.
function Host:setRoot(root)
    self.root = root
    self:relayout()
end

-- Where the overlay sits: centred.
function Host:overlayPos()
    local o = self.overlay
    if o.dock == "bottom" then return 0, self.dimen.h - o.h end
    return math.floor((self.dimen.w - o.w) / 2), math.floor((self.dimen.h - o.h) / 2)
end

-- Where the toast sits: centred near the bottom, clear of the tab bar.
function Host:toastPos()
    local t = self.toast
    local th = Theme.get()
    return math.floor((self.dimen.w - t.w) / 2), self.dimen.h - th.size.tabbar - th.space.xl - t.h
end

-- Paint background, screen, overlay and toast (timed).
function Host:paintTo(bb, x, y)
    Perf.measure("paint", self.paintAll, self, bb, x, y)
end

-- The painting itself. A size change (rotation) re-lays everything out first.
function Host:paintAll(bb, x, y)
    Theme.sync()
    if self.laid_w ~= Screen:getWidth() or self.laid_h ~= Screen:getHeight() then
        if self.on_resize then self.on_resize() else self:relayout() end
    end
    Paint.fill(bb, x, y, self.dimen.w, self.dimen.h, Theme.get().c.bg)
    if self.root then self.root:paint(bb, x, y) end
    if self.overlay then
        -- a hard offset shadow lifts a centred dialog off the screen behind it
        local ox, oy = self:overlayPos()
        local th = Theme.get()
        local o = self.overlay
        local off = th.space.s
        if not o.dock then
            if o.shape == "chamfer" and th.decor.chamfer then
                Paint.chamfer(bb, x + ox + off, y + oy + off, o.w, o.h, th.size[o.cut] or o.cut, o.corners, th.c.ink)
            else
                Paint.fill(bb, x + ox + off, y + oy + off, o.w, o.h, th.c.ink)
            end
        end
        o:paint(bb, x + ox, y + oy)
    end
    if self.toast then
        local tx, ty = self:toastPos()
        self.toast:paint(bb, x + tx, y + ty)
    end
end

-- The box an element was painted in, as a Geom.
local function box(el)
    return Geom:new({ x = el.x, y = el.y, w = el.w, h = el.h })
end
Host.box = box

-- Flash the element inverted at once, run its action, then repaint the area
-- unless the action already redrew the screen.
function Host:press(el, handler)
    local d = box(el)
    Screen.bb:invertRect(d.x, d.y, d.w, d.h)
    UIManager:setDirty(nil, "fast", d)
    UIManager:forceRePaint()
    self.repainted = false
    -- a failing action must never take KOReader down: log it and say so
    local ok, err = xpcall(el[handler], debug.traceback, el)
    if not ok then
        logger.err("CyberUI: action failed:", err)
        if self.on_error then self.on_error(err) end
    end
    if not self.repainted and UIManager:isWidgetShown(self) then
        UIManager:setDirty(self, "ui", d)
    end
end

-- Mark that the screen was redrawn by the action (so press needs no restore).
function Host:markRepainted()
    self.repainted = true
end

-- Find what was touched: the overlay is modal and closes on a touch outside it.
function Host:target(pos, handler)
    if self.overlay then
        local el = self.overlay:hit(pos.x, pos.y, handler)
        if not el and not self.overlay:contains(pos.x, pos.y) and handler == "on_tap" and self.on_outside then
            self.on_outside()
        end
        return el
    end
    return self.root and self.root:hit(pos.x, pos.y, handler)
end

-- Key input CyberUI does not use stops here, so it never reaches the hidden
-- file list.
local KEYS = { onKeyPress = true, onKeyRepeat = true, onKeyRelease = true }

-- Handle an event; stray keys are swallowed. Other events CyberUI does not
-- handle (night mode, rotation, frontlight...) reach the file browser's
-- modules through `active_widgets`, which KOReader feeds only on that path.
function Host:handleEvent(event)
    if InputContainer.handleEvent(self, event) then return true end
    return KEYS[event.handler] == true
end

-- Let the file browser underneath receive the events CyberUI leaves.
function Host:attachFileManager()
    local FileManager = require("apps/filemanager/filemanager")
    self.active_widgets = FileManager.instance and { FileManager.instance } or nil
end

-- Gestures CyberUI does not use go to the file browser's own gesture zones,
-- where KOReader keeps the gestures set up by the reader (corner taps,
-- rotation...). Only those zones: the hidden file list never sees them.
function Host:onGesture(ev)
    if InputContainer.onGesture(self, ev) then return true end
    if self.overlay then return true end
    local FileManager = require("apps/filemanager/filemanager")
    local fm = FileManager.instance
    if fm and fm ~= self then InputContainer.onGesture(fm, ev) end
    return true
end

-- A tap runs the innermost element's on_tap; false when nothing took it.
function Host:onTap(_, ges)
    local el = self:target(ges.pos, "on_tap")
    if el then self:press(el, "on_tap") end
    return el ~= nil or self.overlay ~= nil
end

-- A hold runs on_hold; false when nothing took it.
function Host:onHold(_, ges)
    local el = self:target(ges.pos, "on_hold")
    if el then self:press(el, "on_hold") end
    return el ~= nil or self.overlay ~= nil
end

-- Swipes go to the app (paging, the KOReader menu from the top edge);
-- false when it did not use the swipe.
function Host:onSwipe(_, ges)
    if self.overlay then return true end
    return self.on_swipe ~= nil and self.on_swipe(ges.direction, ges.pos) == true
end

-- The Back key goes back a screen.
function Host:onBack()
    if self.on_back then self.on_back() end
    return true
end

return Host
