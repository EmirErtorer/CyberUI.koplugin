-- The home screen: the masthead, today's date and reading streak, the book
-- being read with Resume, recent books and the launcher to every section.

local Actions = require("cyberui/actions")
local App = require("cyberui/app")
local Banner = require("cyberui/data/banner")
local Books = require("cyberui/data/books")
local Button = require("cyberui/ui/button")
local Cover = require("cyberui/ui/cover")
local Deco = require("cyberui/ui/deco")
local Files = require("cyberui/data/files")
local Format = require("cyberui/format")
local History = require("cyberui/data/history")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Launcher = require("cyberui/ui/launcher")
local Library = require("cyberui/data/library")
local ListRow = require("cyberui/ui/listrow")
local Masthead = require("cyberui/ui/masthead")
local Panel = require("cyberui/ui/panel")
local ProfileFlow = require("cyberui/profileflow")
local Progress = require("cyberui/ui/progress")
local Screen = require("cyberui/screens/screen")
local Settings = require("cyberui/settings")
local ShardCard = require("cyberui/ui/shardcard")
local Shards = require("cyberui/data/shards")
local Stats = require("cyberui/data/stats")
local StatusBar = require("cyberui/ui/statusbar")
local Theme = require("cyberui/theme")
local Version = require("cyberui/version")
local _ = require("cyberui/gettext")

local Home = Screen:extend()

-- A fresh highlight each time home is opened.
function Home:init()
    Banner.shuffle()
    Shards.shuffle()
    -- highlights are collected while the device is idle; show the first one found
    require("ui/uimanager"):scheduleIn(2, function()
        Shards.collect(function()
            local s = App.current()
            if s and s.id == "home" and s.no_shard then App.update() end
        end)
    end)
end

-- Shown again after a book: a fresh highlight, and the book just read back
-- in the active panel.
function Home:onRaise()
    Banner.shuffle()
    Shards.shuffle()
    self.picked = nil
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
                Label:new({ text = count and string.format(_.n("%d BOOK", "%d BOOKS", count), count) or _("SCANNING"), kind = "mono", color = "on_accent" }),
            } }) }),
    } })
end

-- The date block with the streak line and a button to the reading log.
-- The streak line under the date.
local function streakLine()
    local goal = Settings.get("daily_goal", 30)
    return string.format(_.n("STREAK %d DAY // %d MIN TODAY // GOAL %d", "STREAK %d DAYS // %d MIN TODAY // GOAL %d", Stats.streak()), Stats.streak(), Format.minutes(Stats.today()), goal)
end

local function dateRow(home)
    local th = Theme.get()
    home.streak = Label:new({ text = streakLine(), kind = "mono_small", color = "muted" })
    return Layout.Row:new({ gap = th.space.l, children = {
        Panel:new({ shape = "chamfer", corners = "l", cut = "cut", fill = "accent2", line = false,
            width = Theme.px(64), height = Theme.px(64),
            child = Label:new({ text = os.date("%d"), kind = "hero", color = "on_accent2", align = "center" }) }),
        Layout.Column:new({ grow = true, children = {
            Label:new({ text = Format.date("%A, %B %d"), kind = "title" }),
            home.streak,
        } }),
        Button:new({ icon = "stats", label = _("SYS"), variant = "secondary", on_tap = function() App.push("diagnostics") end }),
    } })
end

-- The book has now really closed (home was shown before it did): its
-- reading time is counted, so redraw the streak line alone if it changed.
function Home:onBookClosed()
    local line = streakLine()
    if not self.streak or self.streak.text == line then return end
    self.streak.text = line
    self.streak:layout(self.streak.w, self.streak.h)
    App.repaint(self.streak)
end

-- The book in the active panel: the one picked from the recent list, or the
-- one being read. { path, time } or nil.
function Home:shown()
    if self.picked and Files.exists(self.picked) then
        return { path = self.picked, time = History.lastOpened(self.picked) }
    end
    return History.current()
end

-- The panel of the shown book, or a prompt when there is none.
local function activeFile(cur)
    local th = Theme.get()
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
                -- hold the bar to change its style
                Panel:new({ shape = "none", pad = { Theme.px(4), 0 }, on_hold = function() Progress.pickStyle() end,
                    child = Progress:new({ value = st.percent, book = true }) }),
                Layout.Row:new({ children = {
                    Label:new({ text = string.format(_("%d%% DECRYPTED"), pct), kind = "mono", grow = true }),
                    Label:new({ text = pages, kind = "mono", color = "muted" }),
                } }),
                Label:new({ text = cur.time and string.format(_("LAST OPEN %s"), Format.ago(cur.time)) or _("NEVER OPENED"), kind = "mono_small", color = "muted" }),
                Layout.Spacer:new({ grow = true }),
                Button:new({ label = st.percent > 0 and _("RESUME") or _("OPEN"), icon = "forward", variant = "primary", width = Theme.px(160),
                    on_tap = function() Actions.open(path) end }),
            } }),
        } }) })
end

-- Recent books other than the shown one, as many as fit. Tapping one shows
-- it in the active panel; holding it opens its details.
local function recentList(home, shown, shard)
    local th = Theme.get()
    -- the shard (when there is one) sits first, so a short column clips recent books, not it
    local kids = { Label:new({ text = _("RECENT_FILES"), kind = "micro", color = "muted" }) }
    if shard then table.insert(kids, 1, shard) end
    local n = 0
    local row_h, thumb_w, thumb_h = Cover.recentSize()
    for _i, item in ipairs(History.recent(8)) do
        local p = item.path
        if not (shown and p == shown.path) then
            n = n + 1
            kids[#kids + 1] = ListRow.build({ path = p, title = Books.info(p).title, meta = Books.badge(p) .. " // " .. Format.ago(item.time),
                height = row_h, thumb_w = thumb_w, thumb_h = thumb_h,
                on_tap = function() home.picked = p; App.update() end,
                on_hold = function() Actions.details(p) end })
        end
    end
    if n == 0 then
        kids[#kids + 1] = Label:new({ text = _("Books you open show up here."), kind = "small", color = "muted" })
    end
    return Panel:new({ shape = "rail", line = "accent", grow = true, pad = { 0, 0, 0, th.space.l },
        child = Layout.Column:new({ gap = th.space.s, clip = true, children = kids }) })
end

-- A recovered highlight as a data shard at the top of the recent list, when
-- there is one and the screen is tall (not a wide, short one). Tapping opens all
-- the shards, holding draws another.
local function shardPanel(home)
    local screen = require("device").screen
    home.no_shard = false
    if not Settings.get("home_shard", true) or screen:getWidth() > screen:getHeight() then return nil end
    local pick = Shards.random()
    if not pick then
        home.no_shard = true
        return nil
    end
    return ShardCard.build({ shard = pick.shard, number = pick.number, of = pick.of, lines = 3,
        on_tap = function() App.push("shards") end,
        on_hold = function() Shards.another(); App.update() end })
end

-- The footer: barcode, prompt and version.
local function footer()
    local th = Theme.get()
    return Layout.Row:new({ gap = th.space.m, children = {
        Deco.Barcode:new({ width = Theme.px(84), height = Theme.px(18) }),
        Label:new({ text = "ROOT@" .. Banner.device() .. ":~#", kind = "mono_small", grow = true }), -- i18n: keep
        Label:new({ text = "CYBERUI " .. Version, kind = "micro", color = "muted" }), -- i18n: keep
    } })
end

-- Build the home screen.
function Home:build()
    local th = Theme.get()
    local status, clock = StatusBar.build()
    self.clock = clock
    local shown = self:shown()
    local card = Settings.get("home_card", true)
    local kids = {
        status,
        Masthead.build({ operator = card, on_open = ProfileFlow.card, on_photo = ProfileFlow.photo }),
    }
    if not card then table.insert(kids, indexStrip()) end
    table.insert(kids, dateRow(self))
    table.insert(kids, activeFile(shown))
    kids[#kids + 1] = Layout.Row:new({ grow = true, gap = th.space.l, valign = "stretch", children = { recentList(self, shown, shardPanel(self)), Launcher.build() } })
    kids[#kids + 1] = footer()
    return Layout.Column:new({ pad = { th.space.s, th.space.xl, th.space.m, th.space.xl }, gap = th.space.m, children = kids })
end

-- The library index is ready: show the real counts.
function Home:onIndexed()
    App.update()
end

return Home
