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
})

-- Touches anywhere on the screen come here (outside the element they close it).
function Popup:init()
    local whole = function() return Geom:new({ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }) end
    self.ges_events = {
        Tap = { GestureRange:new({ ges = "tap", range = whole }) },
        Hold = { GestureRange:new({ ges = "hold", range = whole }) },
        Swipe = { GestureRange:new({ ges = "swipe", range = whole }) },
    }
    Host.addKeys(self)
    self:setElement(self.element)
end

-- Show another element (a rebuilt menu) in place of the current one.
function Popup:setElement(el)
    self.element = el
    el:layout(el:naturalWidth() or Screen:getWidth(), nil)
    self.dimen = Geom:new({ x = 0, y = 0, w = el.w, h = el.h })
end

-- The area to refresh.
function Popup:box()
    return Geom:new({ x = 0, y = 0, w = self.element.w, h = self.element.h })
end

-- Paint the element at the top left.
function Popup:paintTo(bb, x, y)
    Theme.sync()
    self.element:paint(bb, x, y)
end

-- The pressed element gets the same feedback as in the CyberUI window.
Popup.press = Host.press

-- A tap or hold inside runs the element's handler; outside, a tap closes.
local function touch(self, ges, handler)
    local el = self.element:hit(ges.pos.x, ges.pos.y, handler)
    if el then
        self:press(el, handler)
    elseif handler == "on_tap" and not self.element:contains(ges.pos.x, ges.pos.y) and self.on_outside then
        self.on_outside()
    end
    return true
end

function Popup:onTap(_, ges) return touch(self, ges, "on_tap") end
function Popup:onHold(_, ges) return touch(self, ges, "on_hold") end
function Popup:onSwipe() return true end

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
    UIManager:setDirty(self, "ui", before:combine(self:box()))
end

-- Close it, repainting what it covered.
function Popup:close()
    UIManager:close(self, "ui", self:box())
end

return Popup
