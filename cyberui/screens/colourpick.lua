-- Choosing a colour with the dial: pick the hue on the ring and the saturation
-- and brightness in the matrix, see it next to the one in use and as the grey a
-- black and white screen will show, with a note on whether it reads on the
-- page. The hex code can be typed and the ready-made colours are a tap away.
-- params: { title, current (hex), on_pick(hex) }.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Color = require("cyberui/theme/color")
local Controls = require("cyberui/ui/controls")
local Custom = require("cyberui/themes/custom")
local Dial = require("cyberui/ui/dial")
local Frame = require("cyberui/screens/frame")
local Icon = require("cyberui/ui/icon")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Screen = require("cyberui/screens/screen")
local Swatch = require("cyberui/ui/swatch")
local Theme = require("cyberui/theme")
local util = require("util")
local _ = require("gettext")

local ColourPick = Screen:extend()

-- Start on the colour in use.
function ColourPick:init(params)
    local rgb = Color.parse(params.current) or Color.parse(Custom.DEFAULT_ACCENT)
    self.hue, self.sat, self.val = Color.toHSV(rgb)
end

-- The colour chosen now, as {r, g, b} and as hex.
function ColourPick:rgb()
    return Color.fromHSV(self.hue, self.sat, self.val)
end

-- Take another colour (from a preset or a typed code).
function ColourPick:setHex(hex)
    local rgb = Color.parse(hex)
    if not rgb then return App.toast(_("That is not a colour code")) end
    self.hue, self.sat, self.val = Color.toHSV(rgb)
    App.update()
end

-- Is the colour readable as text and lines on the page (the page is white, or
-- black in the dark modes)?
local function readable(rgb)
    local page = Theme.paintsDark() and { 0, 0, 0 } or { 255, 255, 255 }
    return Color.contrast(rgb, page) >= 3
end

-- The two colours side by side with the grey a black and white screen shows.
function ColourPick:preview(rgb)
    local th = Theme.get()
    local grey = Color.grey(rgb)
    local function pair(name, swatch)
        return Layout.Column:new({ children = { Label:new({ text = name, kind = "micro", color = "muted" }), swatch } })
    end
    local ok = readable(rgb)
    return Layout.Row:new({ gap = th.space.l, valign = "center", children = {
        pair(_("IN USE"), Swatch:new({ colors = { self.params.current }, size = 34 })),
        pair(_("NEW"), Swatch:new({ colors = { Color.hex(rgb) }, size = 34 })),
        pair(_("IN GREY"), Swatch:new({ colors = { Color.hex({ grey, grey, grey }) }, size = 34 })),
        Layout.Row:new({ grow = true, gap = th.space.s, valign = "center", children = {
            Icon:new({ name = ok and "check" or "warning", size = 22, color = ok and "ink" or "accent" }),
            Label:new({ text = ok and _("READS ON THE PAGE") or _("TOO FAINT ON THE PAGE"), kind = "mono_small", lines = 2, grow = true }),
        } }),
    } })
end

-- The ready-made colours as a block of small squares.
function ColourPick:presets()
    local th = Theme.get()
    local rows = {}
    for i = 1, #Custom.PRESETS, 6 do
        local kids = {}
        for j = i, math.min(#Custom.PRESETS, i + 5) do
            local hex = Custom.PRESETS[j]
            kids[#kids + 1] = Panel:new({ shape = "frame", pad = Theme.px(3), grow = true, on_tap = function() self:setHex(hex) end,
                child = Swatch:new({ colors = { hex }, size = 28, height = Theme.px(28), stretch = true }) })
        end
        rows[#rows + 1] = Layout.Row:new({ gap = th.space.s, children = kids })
    end
    return Layout.Column:new({ gap = th.space.s, children = rows })
end

-- Build the screen: the dial, then what is chosen and the ways to change it.
function ColourPick:build()
    local th = Theme.get()
    local params = self.params
    local rgb = self:rgb()
    local hex = Color.hex(rgb)
    local dial = Dial:new({ hue = self.hue, sat = self.sat, val = self.val, size = 360,
        on_change = function(h, s, v) self.hue, self.sat, self.val = h, s, v; App.update() end })
    local readout = Layout.Row:new({ gap = th.space.m, valign = "center", children = {
        Label:new({ text = string.format("%s // H%d S%d V%d", hex, math.floor(self.hue + 0.5), math.floor(self.sat * 100 + 0.5), math.floor(self.val * 100 + 0.5)),
            kind = "mono", grow = true }),
        Button:new({ icon = "edit", label = _("HEX"), variant = "secondary", on_tap = function()
            App.input(_("Colour code"), hex, function(text) self:setHex(util.trim(text or "")) end, _("Use"), { placeholder = "#2457D6" })
        end }),
    } })
    local hue_row = Layout.Row:new({ gap = th.space.m, valign = "center", children = {
        Label:new({ text = _("HUE"), kind = "label", grow = true }),
        Controls.Stepper({ value = math.floor(self.hue / 5 + 0.5) * 5 % 360, min = 0, max = 355, step = 5, format = function(v) return v .. "\u{00B0}" end, value_w = 64,
            on_change = function(v) self.hue = v; App.update() end }),
    } })
    local buttons = Layout.Row:new({ gap = th.space.m, children = {
        Button:new({ label = _("CANCEL"), variant = "secondary", grow = true, on_tap = function() App.pop() end }),
        Button:new({ label = _("USE COLOUR"), icon = "check", variant = "primary", grow = true, corners = "tb", on_tap = function()
            App.pop()
            params.on_pick(hex)
        end }),
    } })
    local controls = Layout.Column:new({ gap = th.space.m, children = { readout, self:preview(rgb), hue_row, self:presets(), buttons } })
    local screen = require("device").screen
    local body
    if screen:getWidth() > screen:getHeight() then
        controls.width = math.floor(screen:getWidth() * 0.5)
        body = Layout.Row:new({ gap = th.space.l, valign = "stretch", children = { dial, controls } })
    else
        -- the dial centred in the room above the controls
        local centred = Layout.Row:new({ grow = true, valign = "stretch", children = { Layout.Spacer:new({ grow = true }), dial, Layout.Spacer:new({ grow = true }) } })
        body = Layout.Column:new({ gap = th.space.m, children = { centred, controls } })
    end
    return Frame.page({ screen = self, title = params.title or _("Colour"), path = "PICK // HSV", tab = "settings", body = body })
end

return ColourPick
