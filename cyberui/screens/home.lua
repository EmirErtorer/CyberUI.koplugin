-- The home screen: identity strip, today's date and reading streak, the book
-- being read with Resume, recent books and the launcher to every section.

local Actions = require("cyberui/actions")
local App = require("cyberui/app")
local Books = require("cyberui/data/books")
local Button = require("cyberui/ui/button")
local Cover = require("cyberui/ui/cover")
local Deco = require("cyberui/ui/deco")
local Format = require("cyberui/format")
local DeviceInfo = require("cyberui/data/device")
local History = require("cyberui/data/history")
local Icon = require("cyberui/ui/icon")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Library = require("cyberui/data/library")
local ListRow = require("cyberui/ui/listrow")
local Panel = require("cyberui/ui/panel")
local Progress = require("cyberui/ui/progress")
local Screen = require("cyberui/screens/screen")
local Settings = require("cyberui/settings")
local Stats = require("cyberui/data/stats")
local StatusBar = require("cyberui/ui/statusbar")
local Theme = require("cyberui/theme")
local Collections = require("cyberui/data/collections")
local _ = require("gettext")

local Home = Screen:extend()

-- The identity strip: logo, device line, title and a barcode.
local function identity()
    local th = Theme.get()
    return Panel:new({ shape = "chamfer", corners = "t", pad = { th.space.s, th.space.m, th.space.s, th.space.l },
        child = Layout.Row:new({ gap = th.space.m, children = {
            Icon:new({ name = "book", size = 28, color = "accent" }),
            Layout.Column:new({ grow = true, children = {
                Label:new({ text = "CYBERDECK // " .. DeviceInfo.name() .. " // " .. _("OPERATOR ACCESS"), kind = "micro", color = "muted" }),
                Label:new({ text = _("READER ONLINE"), kind = "title" }),
            } }),
            Deco.Barcode:new({ width = Theme.px(96), height = Theme.px(32) }),
        } }) })
end

-- The index strip: a rule ending in a tag with the library size.
local function indexStrip()
    local th = Theme.get()
    local count = Library.count()
    return Layout.Row:new({ children = {
        Layout.Column:new({ grow = true, children = {
            Layout.Spacer:new({ grow = true }),
            Deco.Divider:new({ color = "ink", height = Theme.px(3) }),
        }, height = Theme.px(26) }),
        Panel:new({ shape = "chamfer", corners = "l", cut = "cut_small", fill = "accent", line = false,
            pad = { Theme.px(3), th.space.m, Theme.px(3), th.space.xl },
            child = Layout.Row:new({ gap = th.space.xl, children = {
                Label:new({ text = _("INDEX OK ..."), kind = "mono", color = "on_accent" }),
                Label:new({ text = count and string.format(_("%d BOOKS"), count) or _("SCANNING"), kind = "mono", color = "on_accent" }),
            } }) }),
    } })
end

-- The date block with the streak line and a button to the reading log.
local function dateRow()
    local th = Theme.get()
    local goal = Settings.get("daily_goal", 30)
    local line = string.format(_("STREAK %d DAYS // %d MIN TODAY // GOAL %d"), Stats.streak(), Format.minutes(Stats.today()), goal)
    return Layout.Row:new({ gap = th.space.l, children = {
        Panel:new({ shape = "chamfer", corners = "l", cut = "cut", fill = "accent2", line = false,
            width = Theme.px(64), height = Theme.px(64),
            child = Label:new({ text = os.date("%d"), kind = "hero", color = "on_accent2", align = "center" }) }),
        Layout.Column:new({ grow = true, children = {
            Label:new({ text = os.date("%A, %B %d"), kind = "title" }),
            Label:new({ text = line, kind = "mono_small", color = "muted" }),
        } }),
        Button:new({ icon = "stats", variant = "icon", width = th.size.touch, on_tap = function() App.go("history") end }),
    } })
end

-- The panel of the book being read, or a prompt when there is none.
local function activeFile()
    local th = Theme.get()
    local cur = History.current()
    if not cur then
        return Panel:new({ shape = "brackets", label = _("ACTIVE_FILE"), pad = th.space.l, child = Layout.Column:new({
            gap = th.space.m, children = {
                Label:new({ text = _("NO ACTIVE FILE"), kind = "display" }),
                Label:new({ text = _("Open a book from the library and it will wait for you here."), kind = "body", color = "muted", lines = 2 }),
                Button:new({ label = _("OPEN LIBRARY"), icon = "library", variant = "primary", on_tap = function() App.go("library") end }),
            } }) })
    end
    local path = cur.path
    local info, st = Books.info(path), Books.state(path)
    local pct = math.floor(st.percent * 100 + 0.5)
    local who = info.author or ""
    if info.series then who = who .. " // " .. info.series .. (info.series_index and (" #" .. info.series_index) or "") end
    local pages = st.pages and string.format(_("PG %d/%d"), math.floor(st.percent * st.pages + 0.5), st.pages) or ""
    return Panel:new({ shape = "brackets", label = _("ACTIVE_FILE"), pad = { th.space.l, th.space.l, th.space.l, th.space.l },
        child = Layout.Row:new({ gap = th.space.l, valign = "stretch", children = {
            Cover:new({ path = path, width = Theme.px(104), height = Theme.px(152), on_tap = function() Actions.details(path) end }),
            Layout.Column:new({ grow = true, gap = th.space.s, children = {
                Label:new({ text = info.title, kind = "display", lines = 2 }),
                Label:new({ text = who, kind = "body", color = "muted" }),
                Progress:new({ value = st.percent }),
                Layout.Row:new({ children = {
                    Label:new({ text = string.format(_("%d%% DECRYPTED"), pct), kind = "mono", grow = true }),
                    Label:new({ text = pages, kind = "mono", color = "muted" }),
                } }),
                Label:new({ text = _("LAST OPEN ") .. Format.ago(cur.time), kind = "mono_small", color = "muted" }),
                Layout.Spacer:new({ grow = true }),
                Button:new({ label = _("RESUME"), icon = "forward", variant = "primary", width = Theme.px(160),
                    on_tap = function() Actions.open(path) end }),
            } }),
        } }) })
end

-- Recent books after the current one, as many as fit.
local function recentList()
    local th = Theme.get()
    local kids = { Label:new({ text = _("RECENT_FILES"), kind = "micro", color = "muted" }) }
    local list = History.recent(8)
    for i = 2, #list do
        local p = list[i].path
        local badge = Books.badge(p)
        kids[#kids + 1] = ListRow.build({ path = p, title = Books.info(p).title, meta = badge .. " // " .. Format.ago(list[i].time),
            height = Theme.px(54), on_tap = function() Actions.open(p) end, on_hold = function() Actions.details(p) end })
    end
    if #list < 2 then
        kids[#kids + 1] = Label:new({ text = _("Books you open show up here."), kind = "small", color = "muted" })
    end
    return Panel:new({ shape = "rail", line = "accent", grow = true, pad = { 0, 0, 0, th.space.l },
        child = Layout.Column:new({ gap = th.space.s, clip = true, children = kids }) })
end

-- The launcher column: one button per section.
local function launcher()
    local th = Theme.get()
    local count = Library.count()
    local items = {
        { "library", _("LIBRARY"), count and string.format(_("%d FILES // GRID"), count) or _("FILES // GRID"), function() App.go("library") end },
        { "collections", _("COLLECTIONS"), string.format(_("%d CACHES"), #Collections.list()), function() App.go("collections") end },
        { "history", _("HISTORY"), _("TELEMETRY.LOG"), function() App.go("history") end },
        { "search", _("SEARCH"), _("GREP THE ARCHIVE"), function() App.push("search") end },
        { "files", _("FILES"), _("KOREADER BROWSER"), function() App.fileBrowser() end },
        { "settings", _("SYSTEM"), _("THEME // SETTINGS"), function() App.go("settings") end },
    }
    local kids = {}
    for i, it in ipairs(items) do
        kids[i] = Button:new({ icon = it[1], label = it[2], sub = it[3], align = "left", variant = i == 1 and "primary" or "soft",
            corners = "r", height = Theme.px(44), on_tap = it[4] })
    end
    return Panel:new({ shape = "frame", width = Theme.px(212), pad = th.space.s,
        child = Layout.Column:new({ gap = th.space.xs, clip = true, children = kids }) })
end

-- The footer: barcode, prompt and version.
local function footer()
    local th = Theme.get()
    return Layout.Row:new({ gap = th.space.m, children = {
        Deco.Barcode:new({ width = Theme.px(84), height = Theme.px(18) }),
        Label:new({ text = "ROOT@" .. DeviceInfo.name() .. ":~#", kind = "mono_small", grow = true }),
        Label:new({ text = "CYBERUI " .. require("cyberui/version"), kind = "micro", color = "muted" }),
    } })
end

-- Build the home screen.
function Home:build()
    local th = Theme.get()
    local status, clock = StatusBar.build()
    self.clock = clock
    return Layout.Column:new({ pad = { th.space.s, th.space.xl, th.space.m, th.space.xl }, gap = th.space.m, children = {
        status,
        identity(),
        indexStrip(),
        dateRow(),
        activeFile(),
        Layout.Row:new({ grow = true, gap = th.space.l, valign = "stretch", children = { recentList(), launcher() } }),
        footer(),
    } })
end

-- The library index is ready: show the real counts.
function Home:onIndexed()
    App.update()
end

return Home
