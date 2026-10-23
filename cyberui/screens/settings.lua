-- System settings in six sections: Look (colour scheme, light or dark, custom
-- colours), Covers (style, characters, size, ASCII sleep screen), Fonts (the font
-- in use, the font page, text size), Home (start with CyberUI, the banner's
-- lines, top bar, daily goal, KOReader menu), Speed (refresh, library index)
-- and About.

local App = require("cyberui/app")
local Ascii = require("cyberui/gfx/ascii")
local Banner = require("cyberui/data/banner")
local Button = require("cyberui/ui/button")
local Controls = require("cyberui/ui/controls")
local Device = require("device")
local Cover = require("cyberui/ui/cover")
local Custom = require("cyberui/themes/custom")
local Deco = require("cyberui/ui/deco")
local Fonts = require("cyberui/screens/fonts")
local Frame = require("cyberui/screens/frame")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Library = require("cyberui/data/library")
local Panel = require("cyberui/ui/panel")
local Registry = require("cyberui/theme/registry")
local Screen = require("cyberui/screens/screen")
local Settings = require("cyberui/settings")
local Sleep = require("cyberui/sleep")
local Swatch = require("cyberui/ui/swatch")
local Theme = require("cyberui/theme")
local Version = require("cyberui/version")
local util = require("util")
local _ = require("gettext")

local SettingsScreen = Screen:extend()

local SECTIONS = { { _("Look"), "look" }, { _("Covers"), "covers" }, { _("Fonts"), "fonts" }, { _("Home"), "home" }, { _("Speed"), "speed" },
    { _("About"), "about" } }

-- Open on the Look section.
function SettingsScreen:init()
    self.section = "look"
end

-- A setting: its name and explanation on the left, a control on the right.
local function row(label, sub, control)
    local th = Theme.get()
    local text = { Label:new({ text = label, kind = "heading" }) }
    if sub then text[2] = Label:new({ text = sub, kind = "small", color = "muted", lines = 2 }) end
    return Layout.Column:new({ children = {
        Layout.Row:new({ gap = th.space.m, pad = { th.space.s, 0 }, children = {
            Layout.Column:new({ grow = true, children = text }), control,
        } }),
        Deco.Divider:new({}),
    } })
end

-- Save a plain setting and redraw.
local function save(key, value)
    Settings.save(key, value)
    App.update()
end

-- Pick one of the preset colours for a custom accent.
local function pickColour(key, title)
    local th = Theme.get()
    App.dialog(function(close, screen_w)
        local cells = {}
        for _i, hex in ipairs(Custom.PRESETS) do
            cells[#cells + 1] = Panel:new({ shape = "frame", pad = Theme.px(4), on_tap = function()
                close()
                Theme.set(key, hex)
            end, child = Swatch:new({ colors = { hex }, size = 40, height = Theme.px(40) }) })
        end
        local grid_rows = {}
        for i = 1, #cells, 4 do
            grid_rows[#grid_rows + 1] = Layout.Row:new({ gap = th.space.m, children = { cells[i], cells[i + 1], cells[i + 2], cells[i + 3] } })
        end
        table.insert(grid_rows, 1, Label:new({ text = title, kind = "title" }))
        grid_rows[#grid_rows + 1] = Button:new({ label = _("Close"), variant = "ghost", on_tap = close })
        return Panel:new({ shape = "chamfer", corners = "tb", fill = "bg", pad = th.space.xl,
            width = math.min(screen_w - 2 * th.space.xl, Theme.px(420)),
            child = Layout.Column:new({ gap = th.space.m, align = "center", children = grid_rows }) })
    end)
end

-- The Look section.
function SettingsScreen:look()
    local th = Theme.get()
    local scheme = Settings.get("scheme", "mono")
    local dark = Theme.paintsDark()
    local schemes = {}
    for _i, s in ipairs(Registry.schemeList()) do
        local data = Registry.scheme(s.id)
        local pal = dark and data.dark or data.light
        schemes[#schemes + 1] = Button:new({ label = s.name, align = "left", variant = s.id == scheme and "chip_on" or "chip",
            grow = true, on_tap = function() Theme.set("scheme", s.id) end })
        schemes[#schemes + 1] = Swatch:new({ colors = { pal.bg, pal.ink, pal.accent, pal.accent2 }, width = Theme.px(96) })
    end
    -- one scheme to a row, two on a wide (landscape) screen so the rest fits
    local per_row = Device.screen:getWidth() > Device.screen:getHeight() and 2 or 1
    local scheme_rows = {}
    for i = 1, #schemes, 2 * per_row do
        local kids = {}
        for j = i, math.min(#schemes, i + 2 * per_row - 1) do kids[#kids + 1] = schemes[j] end
        -- a lone last scheme keeps the width of the others
        if per_row == 2 and #kids == 2 then
            kids[3] = Layout.Spacer:new({ grow = true })
            kids[4] = Layout.Spacer:new({ width = Theme.px(96) })
        end
        scheme_rows[#scheme_rows + 1] = Layout.Row:new({ gap = th.space.m, children = kids })
    end
    local kids = {
        Label:new({ text = _("COLOUR SCHEME"), kind = "label" }),
        Layout.Column:new({ gap = th.space.s, children = scheme_rows }),
        Label:new({ text = _("MODE"), kind = "label" }),
        Controls.Segmented({ options = { { _("Light"), "light" }, { _("Dark"), "dark" }, { _("System"), "system" } },
            value = Theme.mode(), kind = "label", on_change = function(v) Theme.set("mode", v) end }),
    }
    if scheme == "custom" then
        local a = row(_("Accent"), _("Buttons, badges and the active tab"), Button:new({ label = _("Pick"), on_tap = function()
            pickColour("custom_accent", _("Accent")) end }))
        local b = row(_("Second accent"), _("The date block and highlights"), Button:new({ label = _("Pick"), on_tap = function()
            pickColour("custom_accent2", _("Second accent")) end }))
        if per_row == 2 then
            a.grow, b.grow = true, true
            kids[#kids + 1] = Layout.Row:new({ gap = th.space.xl, children = { a, b } })
        else
            kids[#kids + 1] = a
            kids[#kids + 1] = b
        end
    end
    return kids
end

-- The Covers section: style, character set, size in the library and the
-- sleep screen.
function SettingsScreen:covers()
    local set = Ascii.set()
    local kids = {
        Label:new({ text = _("STYLE"), kind = "label" }),
        Controls.Segmented({ options = { { _("ASCII"), "ascii" }, { _("Image"), "image" }, { _("Card"), "card" } },
            value = Cover.style(), kind = "label", on_change = function(v) save("cover_style", v) end }),
        row(_("Characters"), _("What ASCII covers are drawn with"), Button:new({ label = set.name, on_tap = function()
            local options = {}
            for _i, s in ipairs(Ascii.SETS) do
                options[#options + 1] = { label = s.name, checked = s.id == set.id, on_tap = function() save("ascii_set", s.id) end }
            end
            App.choose({ title = _("Characters"), cols = 2, options = options })
        end })),
        Label:new({ text = _("SIZE IN THE LIBRARY"), kind = "label" }),
        Controls.Segmented({ options = { { "S", "s" }, { "M", "m" }, { "L", "l" }, { "XL", "xl" } },
            value = Settings.get("cover_size", "m"), kind = "label", on_change = function(v) save("cover_size", v) end }),
        Label:new({ text = _("ASCII SLEEP SCREEN"), kind = "label" }),
        Controls.Segmented({ options = (function()
                local o = {}
                for _i, m in ipairs(Sleep.MODES) do o[#o + 1] = { m.name, m.id } end
                return o
            end)(), value = Sleep.mode(), kind = "label", on_change = function(v) save("ascii_sleep_mode", v) end }),
    }
    return kids
end

-- The Fonts section: the font in use, the way to every font, and text size.
function SettingsScreen:fonts()
    local kids = {
        Fonts.card(Registry.fontSet(Settings.get("fontset", "oxanium")), true),
        row(_("All fonts"), string.format(_("%d cyberpunk sets, or any font installed on this device"), #Registry.fontSets()),
            Button:new({ label = _("Choose"), on_tap = function() App.push("fonts") end })),
    }
    kids[#kids + 1] = row(_("Text size"), _("Makes every text in CyberUI larger or smaller"),
        Controls.Stepper({ value = math.floor(Settings.get("text_scale", 1) * 100 + 0.5), min = 80, max = 140, step = 10,
            format = function(v) return v .. "%" end, value_w = 64,
            on_change = function(v) Theme.set("text_scale", v / 100) end }))
    return kids
end

-- Ask for the reader's handle, then call after().
local function askHandle(after)
    App.input(_("Your handle"), Settings.get("handle", ""), function(text)
        Settings.save("handle", util.trim(text or ""))
        if after then after() end
        App.update()
    end, _("Save"), { placeholder = _("OPERATOR") })
end

-- Pick what the banner's big line says. Shared with home's long-press.
function SettingsScreen.pickBannerTitle()
    local cur = Settings.get("banner_title", "online")
    local options = {}
    for _i, p in ipairs(Banner.PRESETS) do
        options[#options + 1] = { label = p.text, checked = cur == p.id, on_tap = function() save("banner_title", p.id) end }
    end
    for _i, l in ipairs(Banner.LIVE) do
        options[#options + 1] = { label = l.label, sub = l.sub, checked = cur == l.id, on_tap = function()
            if l.id == "custom" then
                App.input(_("Banner text"), Settings.get("banner_text", ""), function(text)
                    Settings.set("banner_text", util.trim(text or ""))
                    save("banner_title", "custom")
                end, _("Save"), { placeholder = Banner.PRESETS[1].text })
            elseif l.id == "greeting" and not Settings.get("handle") then
                askHandle(function() save("banner_title", "greeting") end)
            else
                save("banner_title", l.id)
            end
        end }
    end
    App.choose({ title = _("Banner"), cols = 2, options = options })
end

-- Pick what the banner's small line says.
function SettingsScreen.pickBannerTop()
    local cur = Settings.get("banner_top", "device")
    local options = {}
    for _i, t in ipairs(Banner.TOPS) do
        options[#options + 1] = { label = t.label, sub = t.sub, checked = cur == t.id, on_tap = function()
            if t.id == "handle" and not Settings.get("handle") then
                askHandle(function() save("banner_top", "handle") end)
            else
                save("banner_top", t.id)
            end
        end }
    end
    options[#options + 1] = { label = _("Change handle"), sub = Banner.handle(), icon = "edit", on_tap = function() askHandle() end }
    App.choose({ title = _("Banner top line"), cols = 2, options = options })
end

-- The Home section.
function SettingsScreen:home()
    local is_home = G_reader_settings:readSetting("start_with") == "cyberui"
    return {
        row(_("Start with CyberUI"), _("Open CyberUI when KOReader starts and after closing a book"),
            Controls.Toggle:new({ on = is_home, on_change = function(on)
                G_reader_settings:saveSetting("start_with", on and "cyberui" or "filemanager")
                App.update()
            end })),
        row(_("Top bar"), _("The tag and the readouts across the top of every screen"),
            Button:new({ label = _("Change"), on_tap = function() App.push("topbar") end })),
        row(_("Banner top line"), _("The small line above the banner, and your handle"),
            Button:new({ label = _("Change"), on_tap = SettingsScreen.pickBannerTop })),
        row(_("Banner"), _("The big line at the top of home; hold it there to change it too"),
            Button:new({ label = _("Change"), on_tap = SettingsScreen.pickBannerTitle })),
        row(_("Daily goal"), _("Minutes of reading a day, shown on home and in the log"),
            Controls.Stepper({ value = Settings.get("daily_goal", 30), min = 5, max = 240, step = 5,
                format = function(v) return v .. " MIN" end, value_w = 76, on_change = function(v) save("daily_goal", v) end })),
        row(_("KOReader menu"), _("In CyberUI's style (off: KOReader's own); also opens with a swipe down from the top"),
            Layout.Row:new({ gap = Theme.get().space.s, children = {
                Controls.Toggle:new({ on = Settings.get("styled_menu", true), on_change = function(on) save("styled_menu", on) end }),
                Button:new({ label = _("Open"), on_tap = function() App.koreaderMenu() end }),
            } })),
        row(_("File browser"), _("Leave CyberUI for KOReader's own file browser"),
            Button:new({ label = _("Open"), on_tap = function() App.fileBrowser() end })),
    }
end

-- The Speed section.
function SettingsScreen:speed()
    local th = Theme.get()
    return {
        row(_("Full refresh every"), _("Screens between flashing refreshes that clear ghosting (0 never)"),
            Controls.Stepper({ value = Settings.get("full_refresh_every", 6), min = 0, max = 20,
                format = function(v) return tostring(v) end, value_w = 48, on_change = function(v) save("full_refresh_every", v) end })),
        row(_("Library index"), string.format(_("%d books indexed; rebuild after copying books over"), Library.count() or 0),
            Button:new({ label = _("Rebuild"), on_tap = function()
                Library.reset()
                Library.all()
                App.toast(string.format(_("%d books indexed"), Library.count() or 0))
                App.update()
            end })),
        Panel:new({ shape = "frame", pad = th.space.m, child = Layout.Column:new({ gap = th.space.xs, children = {
            Label:new({ text = _("HOW CYBERUI STAYS FAST"), kind = "micro", color = "muted" }),
            Label:new({ text = _("Home stays loaded while you read, so closing a book is a redraw, not a rebuild. Everything is drawn with flat shapes and refreshed only where it changed."),
                kind = "small", lines = 4 }),
        } }) }),
    }
end

-- The About section.
function SettingsScreen:about()
    return {
        row(_("Version"), nil, Label:new({ text = Version, kind = "mono" })),
        row(_("Fonts"), _("Oxanium, Chakra Petch, Tomorrow, Rajdhani, Orbitron, Exo 2, Turret Road, Michroma, Electrolize, Audiowide, Wallpoet, Russo One, Iceland, VT323, Press Start 2P, Share Tech, Share Tech Mono and JetBrains Mono, SIL Open Font License"), Layout.Spacer:new({ width = 1 })),
        Label:new({ text = _("A fast cyberpunk home screen for KOReader."), kind = "body", color = "muted", lines = 2 }),
    }
end

-- Build the screen.
function SettingsScreen:build()
    local th = Theme.get()
    local tabs = Controls.Segmented({ options = SECTIONS, value = self.section, kind = "label", on_change = function(v) self.section = v; App.update() end })
    local body = { tabs }
    for _i, el in ipairs(self[self.section](self)) do body[#body + 1] = el end
    return Frame.page({
        screen = self, title = _("System"), path = "~/.cyberui/config", tab = "settings",
        body = Layout.Column:new({ gap = th.space.m, clip = true, children = body }),
    })
end

return SettingsScreen
