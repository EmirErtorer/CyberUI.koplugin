-- A CyberUI element shown over any other screen (the reader too, where the
-- CyberUI window is hidden): it paints only its own box, gives the same
-- press feedback, and a tap outside it calls on_outside. The drop-down menu
-- uses it inside books.

local Device = require("device")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Host = require("cyberui/host")
local Theme = require("cyberui/theme")

local Screen = Device.screen

local Popup = InputContainer:extend({
    name = "cyberui_popup",
    covers_fullscreen = false,
    modal = true,
    element = nil,     -- the element shown, laid out at its own size
    on_outside = nil,  -- a tap outside the element
    on_back = nil,     -- the Back key; true when it was used
    on_swipe = nil,    -- a swipe anywhere: function(direction)
    place = nil,       -- function(element) -> x, y for an element that floats
    passive = false,   -- a notice that takes no touches or keys (they go on to what is under it)
    under = nil,       -- function() -> the popup right below, which gets the touches outside this one
})

-- Touches anywhere on the screen come here (outside the element they close it).
function Popup:init()
    if self.passive then
        self.ges_events, self.key_events = {}, {}
        self.modal = false
        self.toast = true   -- KOReader's contract for notices: they never stop an event on its way to what is under
        self:setElement(self.element)
        return
    end
    local whole = function() return Geom:new({ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }) end
    self.ges_events = {
        Tap = { GestureRange:new({ ges = "tap", range = whole }) },
        Hold = { GestureRange:new({ ges = "hold", range = whole }) },
        Swipe = { GestureRange:new({ ges = "swipe", range = whole }) },
        Pan = { GestureRange:new({ ges = "pan", range = whole }) },
        PanRelease = { GestureRange:new({ ges = "pan_release", range = whole }) },
    }
    Host.addKeys(self)
    self:setElement(self.element)
end

-- Show another element (a rebuilt menu) in place of the current one.
function Popup:setElement(el)
    self.element = el
    el:layout(el:naturalWidth() or Screen:getWidth(), nil)
    -- a docked element sits on its edge; `place(el)` may give x, y instead (a floating one)
    self.ox, self.oy = 0, el.dock == "bottom" and Screen:getHeight() - el.h or 0
    if self.place then self.ox, self.oy = self.place(el) end
    self.dimen = Geom:new({ x = self.ox, y = self.oy, w = el.w, h = el.h })
end

-- The area to refresh.
function Popup:box()
    return Geom:new({ x = self.ox, y = self.oy, w = self.element.w, h = self.element.h })
end

-- Paint the element at the top left (or on the bottom edge).
function Popup:paintTo(bb, x, y)
    Theme.sync()
    self.element:paint(bb, x + self.ox, y + self.oy)
end

-- The pressed element gets the same feedback as in the CyberUI window.
Popup.press = Host.press

-- Touches outside the element go to the popup below when there is one.
local function below(self, call)
    local under = self.under and self.under()
    if under then return call(under) end
end

-- A tap or hold inside runs the element's handler; outside, a tap goes to the
-- popup below, else closes.
local function touch(self, ges, handler)
    local el = self.element:hit(ges.pos.x, ges.pos.y, handler)
    if el then
        el.touch = ges.pos
        self:press(el, handler)
    elseif not self.element:contains(ges.pos.x, ges.pos.y) then
        if below(self, function(u) return handler == "on_tap" and u:onTap(nil, ges) or u:onHold(nil, ges) end) then return true end
        if handler == "on_tap" and self.on_outside then self.on_outside() end
    end
    return true
end

function Popup:onTap(_, ges) return touch(self, ges, "on_tap") end
function Popup:onHold(_, ges) return touch(self, ges, "on_hold") end
-- A finger moving over an element with on_drag moves it (as in the CyberUI window).
function Popup:target(pos, handler)
    local el = self.element:hit(pos.x, pos.y, handler)
    if el then el.touch = pos end
    return el
end
function Popup:stale() return false end
function Popup:onPan(arg, ges)
    if not self.element:contains(ges.pos.x, ges.pos.y) and below(self, function(u) return u:onPan(arg, ges) end) then return true end
    Host.onPan(self, arg, ges)
    return true
end
function Popup:onPanRelease(arg, ges)
    if not self.element:contains(ges.pos.x, ges.pos.y) and below(self, function(u) return u:onPanRelease(arg, ges) end) then return true end
    Host.onPanRelease(self, arg, ges)
    return true
end

-- A swipe goes to on_swipe(direction) when there is one (outside, to the popup below).
function Popup:onSwipe(arg, ges)
    if not self.element:contains(ges.pos.x, ges.pos.y) and below(self, function(u) return u:onSwipe(arg, ges) end) then return true end
    if self.on_swipe then self.on_swipe(ges.direction) end
    return true
end

-- The page turn keys page the element when it pages.
function Popup:onPageNext() local f = self.element.on_page; if f then f(1) end; return true end
function Popup:onPagePrev() local f = self.element.on_page; if f then f(-1) end; return true end

-- Back goes to on_back, else closes.
function Popup:onBack()
    if not (self.on_back and self.on_back()) and self.on_outside then self.on_outside() end
    return true
end

-- Show it, refreshing only its box.
function Popup:open()
    UIManager:show(self, "ui", self:box())
end

-- Redraw with a new element.
function Popup:redraw(el)
    local before = self:box()
    self:setElement(el)
    local after = self:box()
    if after.w < before.w or after.h < before.h then
        -- the strip no longer covered belongs to what is under the popup, which
        -- only a close repaints
        UIManager:close(self, "ui", before)
        UIManager:show(self, "ui", after)
    else
        UIManager:setDirty(self, "ui", after:combine(before))
    end
end

-- Close it, repainting what it covered.
function Popup:close()
    UIManager:close(self, "ui", self:box())
end

return Popup
