-- KOReader's QR window (a link in a book, a page to open on a phone) in
-- CyberUI's style: the code on a white square, the text it holds under it, and
-- a Close. The code is drawn from the same text KOReader would draw it from.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Specs = require("cyberui/skin/specs")

local Screen = Device.screen

local Skin = {}

Core.register({
    name = "qr",
    matches = function(widget) return Anatomy.is(widget, "ui/widget/qrmessage") and type(widget.text) == "string" end,
    present = function(widget)
        local Dialog = require("cyberui/ui/dialog")
        local Label = require("cyberui/ui/label")
        local Layout = require("cyberui/ui/layout")
        local QRCode = require("cyberui/ui/qrcode")
        local _ = require("cyberui/gettext")
        local code = QRCode:new({ text = widget.text, size = 300 })
        local rows = {
            Layout.Row:new({ children = { Layout.Spacer:new({ grow = true }), code, Layout.Spacer:new({ grow = true }) } }),
            Label:new({ text = widget.text, kind = "mono_small", color = "muted", align = "center", lines = 3 }),
            Specs.wide({ text = _("Close"), callback = function() Core.dismiss(widget) end }, "ghost", "close"),
        }
        return {
            element = Dialog.card({ tag = _("// SCAN"), rows = rows }, Screen:getWidth()),
            place = Core.centered,
            on_outside = function() Core.dismiss(widget) end,
            on_back = function() Core.dismiss(widget); return true end,
        }
    end,
})

return Skin
