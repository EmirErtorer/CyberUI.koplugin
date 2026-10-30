-- System settings in six sections: Look (colour scheme, light or dark, custom
-- colours), Covers (style, characters, size, ASCII sleep screen), Fonts (the font
-- in use, the font page, text size), Home (start with CyberUI, the banner's
-- lines, top bar, daily goal, KOReader menu), Speed (refresh, keeping the book open, library index)
-- and About.

local Actions = require("cyberui/actions")
local App = require("cyberui/app")
local Ascii = require("cyberui/gfx/ascii")
local Banner = require("cyberui/data/banner")
local Button = require("cyberui/ui/button")
local Controls = require("cyberui/ui/controls")
local Cover = require("cyberui/ui/cover")
local Covers = require("cyberui/data/covers")
local Custom = require("cyberui/themes/custom")
local Files = require("cyberui/data/files")
local Fonts = require("cyberui/screens/fonts")
local Frame = require("cyberui/screens/frame")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Library = require("cyberui/data/library")
local Panel = require("cyberui/ui/panel")
local ProfileFlow = require("cyberui/profileflow")
local Progress = require("cyberui/ui/progress")
local Registry = require("cyberui/theme/registry")
local Screen = require("cyberui/screens/screen")
local Settings = require("cyberui/settings")
local row = require("cyberui/ui/settingrow")
local Sleep = require("cyberui/sleep")
local Swatch = require("cyberui/ui/swatch")
local Theme = require("cyberui/theme")
local Version = require("cyberui/version")
local util = require("util")
local _ = require("cyberui/gettext")

local SettingsScreen = Screen:extend()

local SECTIONS = { { _("Look"), "look" }, { _("Covers"), "covers" }, { _("Fonts"), "fonts" }, { _("Home"), "home" }, { _("Speed"), "speed" },
    { _("About"), "about" } }

-- Open on the Look section.
function SettingsScreen:init()
    self.section, self.page = "look", 1
end

-- Save a plain setting and redraw.
local function save(key, value)
    Settings.save(key, value)
    App.update()
end

-- Pick a colour for a custom accent with the colour dial.
local function pickColour(key, title)
    App.push("colourpick", { title = title, current = Settings.get(key) or Custom.DEFAULT_ACCENT,
        on_pick = function(hex) Theme.set(key, hex) end })
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
    -- two schemes to a row
    local scheme_rows = {}
    for i = 1, #schemes, 4 do
        local kids = {}
        for j = i, math.min(#schemes, i + 3) do kids[#kids + 1] = schemes[j] end
        -- a lone last scheme keeps the width of the others
        if #kids == 2 then
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
        a.grow, b.grow = true, true
        kids[#kids + 1] = Layout.Row:new({ gap = th.space.xl, children = { a, b } })
    end
    kids[#kids + 1] = row(_("Book progress"), _("On home and in a book's details; hold the bar on home to change it too"),
        Button:new({ label = Progress.bookStyle().name, on_tap = function() Progress.pickStyle() end }))
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
        row(_("Stretch covers"), _("Fill each cover frame, even if the proportions change"),
            Controls.Toggle:new({ on = Covers.stretch(), on_change = function(on) save("cover_stretch", on) end })),
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
        row(_("All fonts"), string.format(_.n("%d cyberpunk set, or any font installed on this device", "%d cyberpunk sets, or any font installed on this device", #Registry.fontSets()), #Registry.fontSets()),
            Button:new({ label = _("Choose"), on_tap = function() App.push("fonts") end })),
    }
    kids[#kids + 1] = row(_("Text size"), _("Makes every text in CyberUI larger or smaller"),
        Controls.Stepper({ value = math.floor(Settings.get("text_scale", 1) * 100 + 0.5), min = 80, max = 140, step = 10,
            format = function(v) return v .. "%" end, value_w = 64,
            on_change = function(v) Theme.set("text_scale", v / 100) end }))
    return kids
end

-- Ask for the reader's handle, then call after().
local askHandle = ProfileFlow.editHandle

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
        row(_("Jack-in card"), _("A card with the book shown while it opens"),
            Controls.Toggle:new({ on = Settings.get("jack_in", true), on_change = function(on) save("jack_in", on) end })),
        row(_("Data shard"), _("A highlight from your books on home, on by default (tall screens only); hold it there for another"),
            Controls.Toggle:new({ on = Settings.get("home_shard", true), on_change = function(on) save("home_shard", on) end })),
        row(_("Operator card"), _("Your face, handle and rank in the banner on home; tap the face to open the card"),
            Layout.Row:new({ gap = Theme.get().space.s, children = {
                Controls.Toggle:new({ on = Settings.get("home_card", true), on_change = function(on) save("home_card", on) end }),
                Button:new({ label = _("Open"), on_tap = ProfileFlow.card }),
            } })),
        row(_("Launcher"), _("The buttons on home: hide, reorder, replace or add your own that open anything in KOReader"),
            Button:new({ label = _("Edit"), on_tap = function() App.push("launcher") end })),
        row(_("Library opens in"), _("The folder the Library tab starts in; KOReader's home folder stays the top of the library"),
            Button:new({ label = Settings.get("library_start_dir") and Files.name(Settings.get("library_start_dir")) or _("Home folder"), on_tap = function()
                App.choose({ title = _("Library opens in"), options = {
                    { label = _("Home folder"), checked = not Settings.get("library_start_dir"), on_tap = function() Actions.setLibraryStart(nil) end },
                    { label = _("Pick a folder"), icon = "folder", on_tap = Actions.pickLibraryStart },
                } })
            end })),
        row(_("Double tap to open"), _("In the library a book opens on its second tap, so a stray touch does not start it"),
            Controls.Toggle:new({ on = Settings.get("double_tap_open", false), on_change = function(on) save("double_tap_open", on) end })),
        row(_("Top bar"), _("The tag and the readouts across the top of every screen"),
            Button:new({ label = _("Change"), on_tap = function() App.push("topbar") end })),
        row(_("Banner top line"), _("The small line above the banner, and your handle"),
            Button:new({ label = _("Change"), on_tap = SettingsScreen.pickBannerTop })),
        row(_("Banner"), _("The big line at the top of home; hold it there to change it too"),
            Button:new({ label = _("Change"), on_tap = SettingsScreen.pickBannerTitle })),
        row(_("Recent covers"), _("Cover size in the recent list on home"),
            Controls.Segmented({ options = { { "S", "s" }, { "M", "m" }, { "L", "l" }, { "XL", "xl" } },
                value = Cover.recentSizeKey(), kind = "label",
                on_change = function(v) save("recent_cover_size", v) end })),
        row(_("Daily goal"), _("Minutes of reading a day, shown on home and in the log"),
            Controls.Stepper({ value = Settings.get("daily_goal", 30), min = 5, max = 240, step = 5,
                format = function(v) return string.format(_("%d MIN"), v) end, value_w = 76, on_change = function(v) save("daily_goal", v) end })),
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
        row(_("Full refresh in dark mode"), _("Dark screens ghost more, so they flash sooner (0 never)"),
            Controls.Stepper({ value = Settings.get("dark_full_refresh_every", 2), min = 0, max = 20,
                format = function(v) return tostring(v) end, value_w = 48, on_change = function(v) save("dark_full_refresh_every", v) end })),
        row(_("Full refresh every"), _("Screens between flashing refreshes that clear ghosting (0 never)"),
            Controls.Stepper({ value = Settings.get("full_refresh_every", 6), min = 0, max = 20,
                format = function(v) return tostring(v) end, value_w = 48, on_change = function(v) save("full_refresh_every", v) end })),
        row(_("Keep the book open on Home"), _("Home shows at once and the same book opens again with no loading; the book is closed later"),
            Controls.Toggle:new({ on = Settings.get("park_reader", true), on_change = function(on)
                save("park_reader", on)
                if not on then require("cyberui/park").finish() end
            end })),
        Panel:new({ shape = "frame", pad = th.space.m, child = Layout.Column:new({ gap = th.space.xs, children = {
            Label:new({ text = _("PARKING // WHAT IT COSTS"), kind = "micro", color = "muted" }),
            Label:new({ text = _("Going home puts the book away instead of closing it. KOReader closes it for real when you open a different book, after 30 seconds of not touching the screen, or when you open KOReader's menu or its file browser."),
                kind = "small", lines = 5 }),
            Label:new({ text = _("- A different book, KOReader's menu and the file browser take a moment longer, since the close happens then."),
                kind = "small", lines = 4 }),
            Label:new({ text = _("- The book stays in memory while it is put away."), kind = "small", lines = 2 }),
            Label:new({ text = _("- Sleeping soon after leaving a book shows that book's sleep screen."), kind = "small", lines = 3 }),
            Label:new({ text = _("- KOReader's own gestures (corner taps, edge swipes) do not work on Home until the book is closed."),
                kind = "small", lines = 4 }),
            Label:new({ text = _("- A book read in landscape is closed the normal way."), kind = "small", lines = 2 }),
        } }) }),
        row(_("Library index"), string.format(_.n("%d book indexed; rebuild after copying books over", "%d books indexed; rebuild after copying books over", Library.count() or 0), Library.count() or 0),
            Button:new({ label = _("Rebuild"), on_tap = function()
                Library.reset()
                Library.all()
                App.toast(string.format(_.n("%d book indexed", "%d books indexed", Library.count() or 0), Library.count() or 0))
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
        row(_("Language"), _("CyberUI follows KOReader's language (set in KOReader's own settings). The texts are in the l10n folder and can be edited there."),
            Label:new({ text = require("cyberui/gettext").language():upper(), kind = "mono" })),
        row(_("Updates"), (function()
                local v = require("cyberui/update/updater").available()
                return v and string.format(_("CyberUI %s is ready to install"), v) or _("New versions from GitHub, with their notes")
            end)(),
            Button:new({ label = _("Open"), on_tap = function() App.push("updates") end })),
        row(_("Fonts"), _("Oxanium, Chakra Petch, Tomorrow, Rajdhani, Orbitron, Exo 2, Turret Road, Michroma, Electrolize, Audiowide, Wallpoet, Russo One, Iceland, VT323, Press Start 2P, Share Tech, Share Tech Mono and JetBrains Mono, SIL Open Font License"), Layout.Spacer:new({ width = 1 })),
        Label:new({ text = _("A fast cyberpunk home screen for KOReader."), kind = "body", color = "muted", lines = 2 }),
    }
end

-- Build the screen.
function SettingsScreen:build()
    local th = Theme.get()
    local tabs = Controls.Segmented({ options = SECTIONS, value = self.section, kind = "label", on_change = function(v) self.section, self.page = v, 1; App.update() end })
    return Frame.page({
        screen = self, title = _("System"), path = "~/.cyberui/config", tab = "settings",
        body = Layout.Column:new({ gap = th.space.m, children = { tabs, Frame.paged(self, self[self.section](self), _("PAGE")) } }),
    })
end

return SettingsScreen
