-- Choosing CyberUI's font: the bundled cyberpunk sets first, then any font
-- installed on the device, each shown in its own face. Paged, so any number
-- of fonts fits.

local App = require("cyberui/app")
local Controls = require("cyberui/ui/controls")
local Frame = require("cyberui/screens/frame")
local Grid = require("cyberui/ui/grid")
local Icon = require("cyberui/ui/icon")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Registry = require("cyberui/theme/registry")
local Screen = require("cyberui/screens/screen")
local Settings = require("cyberui/settings")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local FontsScreen = Screen:extend()

-- The fonts installed on the device, as sets sorted by name.
local function deviceSets()
    local out, seen = {}, {}
    for _i, path in ipairs(require("fontlist"):getFontList()) do
        if path:lower():match("%.[ot]tf$") and not seen[path] then
            seen[path] = true
            out[#out + 1] = Registry.fontSet("device:" .. path)
        end
    end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    return out
end

-- One font set as a card, its name set in its own face; tapping it picks the set.
function FontsScreen.card(set, chosen)
    local th = Theme.get()
    return Panel:new({ shape = chosen and "chamfer" or "frame", corners = "r", fill = chosen and "soft" or nil,
        pad = { th.space.s, th.space.m }, on_tap = function() Theme.set("fontset", set.id) end,
        child = Layout.Row:new({ gap = th.space.m, children = {
            Layout.Column:new({ grow = true, children = {
                Label:new({ text = set.name, kind = { "title", set.id } }),
                Label:new({ text = set.note, kind = "micro", color = "muted" }),
            } }),
            chosen and Icon:new({ name = "check", size = 26 }) or Layout.Spacer:new({ width = 1 }),
        } }) })
end

-- Start on the tab of the font in use.
function FontsScreen:init()
    self.tab = Settings.get("fontset", ""):match("^device:") and "device" or "cyber"
    self.page = 1
end

-- Build the tabs and one page of cards.
function FontsScreen:build()
    local th = Theme.get()
    local chosen = Settings.get("fontset", "oxanium")
    if self.tab == "device" and not self.device then self.device = deviceSets() end
    local sets = self.tab == "device" and self.device or Registry.fontSets()
    local body = {
        Controls.Segmented({ options = { { _("Cyberpunk"), "cyber" }, { _("Device"), "device" } }, value = self.tab, kind = "label",
            on_change = function(v) self.tab, self.page = v, 1; App.update() end }),
    }
    if #sets == 0 then
        body[#body + 1] = Label:new({ grow = true, text = _("No fonts found on this device."), kind = "body", color = "muted", align = "center" })
    else
        body[#body + 1] = Grid:new({ grow = true, items = sets, page = self.page, cols = 1, cell_h = Theme.px(64), row_gap = th.space.s,
            make = function(set) return FontsScreen.card(set, set.id == chosen) end,
            on_layout = function(_c, pages, page) self.pages, self.page = pages, page end })
        body[#body + 1] = Frame.pager(self, self.tab == "device" and _("FONTS") or _("SETS"), function(p) self:setPage(p) end)
    end
    return Frame.page({ screen = self, title = _("Fonts"), path = string.format(_("%d AVAILABLE"), #sets), tab = "settings",
        body = Layout.Column:new({ gap = th.space.m, children = body }) })
end

return FontsScreen
