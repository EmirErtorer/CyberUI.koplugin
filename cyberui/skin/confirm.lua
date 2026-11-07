-- KOReader's questions in CyberUI's style: the confirm box and the one with
-- two choices. The text, the icon and every button come from the widget
-- (Anatomy), and a tap on a button runs KOReader's own callback, which closes
-- the box and does what was asked.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Specs = require("cyberui/skin/specs")

local Screen = Device.screen

local Skin = {}

-- A question's buttons: the first is the way out (a quiet button with a cross), and in
-- a pair the second is the one that goes ahead (the main button, with a tick).
local function ways(row, i)
    if i == 1 then return "ghost", "close" end
    if #row == 2 then return "primary", "check" end
end

local function takes(widget)
    return Anatomy.is(widget, "ui/widget/confirmbox") or Anatomy.is(widget, "ui/widget/multiconfirmbox")
end

Core.register({
    name = "confirm",
    matches = function(widget) return takes(widget) and not widget._added_widgets end,
    present = function(widget)
        local Dialog = require("cyberui/ui/dialog")
        local kind = Specs.kind(Anatomy.icon(widget))
        local element = Dialog.card({
            tag = kind.tag, icon = kind.icon, danger = kind.danger, text = Anatomy.text(widget),
            rows = Specs.rows(Anatomy.buttons(widget), ways),
        }, Screen:getWidth())
        return {
            element = element,
            place = Core.centered,
            on_outside = widget.dismissable ~= false and function() Core.dismiss(widget) end or nil,
        }
    end,
})

return Skin
