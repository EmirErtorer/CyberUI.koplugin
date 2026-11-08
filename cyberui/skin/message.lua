-- KOReader's notices in CyberUI's style: the message boxes ("Saved", errors,
-- progress notes), which any tap closes and which close by themselves when
-- KOReader says so, and the small notifications that stack at the top of the
-- screen and let touches through. Both are KOReader's widgets still: their
-- timers, callbacks and closing stay its own.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Specs = require("cyberui/skin/specs")
local UIManager = require("ui/uimanager")

local Screen = Device.screen

local Skin = {}

-- A message box with an image, a scrolling text or a delayed appearance is more
-- than text: KOReader draws those.
local function plain(widget)
    return widget.image == nil and widget.height == nil and widget.show_delay == nil
end

Core.register({
    name = "infomessage",
    matches = function(widget)
        return Anatomy.is(widget, "ui/widget/infomessage") and plain(widget)
    end,
    present = function(widget)
        local Dialog = require("cyberui/ui/dialog")
        local kind = widget.show_icon == false and { tag = Specs.kind().tag } or Specs.kind(widget.icon)
        local element = Dialog.card({
            tag = kind.tag, icon = kind.icon, danger = kind.danger, text = Anatomy.text(widget), lines = 12,
        }, Screen:getWidth())
        if widget.dismissable ~= false then element.on_tap = function() UIManager:close(widget) end end
        return {
            element = element,
            place = Core.centered,
            on_outside = widget.dismissable ~= false and function() UIManager:close(widget) end or nil,
        }
    end,
})

Core.register({
    name = "notification",
    matches = function(widget) return Anatomy.is(widget, "ui/widget/notification") end,
    present = function(widget)
        local Dialog = require("cyberui/ui/dialog")
        local element = Dialog.toast(Anatomy.text(widget))
        local margin = widget.margin or 0
        return {
            element = element,
            passive = true,
            -- stacked from the top as KOReader stacks them: each below the one before
            place = function(el)
                local row = (widget._shown_idx or 1) - 1
                return math.floor((Screen:getWidth() - el.w) / 2), margin + row * (el.h + margin)
            end,
        }
    end,
})

return Skin
