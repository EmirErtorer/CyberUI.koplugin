-- The log tab: the last seven days' totals, minutes (or pages) per day against
-- the daily goal, twelve weeks of activity and the latest reading sessions.

local App = require("cyberui/app")
local Charts = require("cyberui/ui/charts")
local Format = require("cyberui/format")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local ListRow = require("cyberui/ui/listrow")
local Insights = require("cyberui/data/insights")
local Metric = require("cyberui/data/metric")
local Settings = require("cyberui/settings")
local Skyline = require("cyberui/ui/skyline")
local Statsdb = require("cyberui/data/statsdb")
local Stats = require("cyberui/data/stats")
local Theme = require("cyberui/theme")
local tile = require("cyberui/ui/stattile")
local _ = require("gettext")

local Week = {}

-- The shade of every cell of the last twelve weeks, a column a week from
-- Monday to Sunday (days still to come are left out).
local function activity(goal)
    local by_date = {}
    for _i, d in ipairs(Insights.days()) do by_date[d.date] = d end
    local since_monday = (os.date("*t").wday + 5) % 7
    local values, top = {}, 0
    for i = 0, 83 do
        local ago = since_monday + 77 - i
        local d = ago >= 0 and (by_date[os.date("%Y-%m-%d", Statsdb.midnight(ago) + 43200)] or { seconds = 0, pages = 0 }) or nil
        values[i + 1] = d and Metric.value(d) or -1
        top = math.max(top, values[i + 1])
    end
    local levels = {}
    for i, v in ipairs(values) do levels[i] = v < 0 and -1 or Metric.level(v, goal, top) end
    return levels
end

-- Build the tab; `screen.day` is the selected bar (today at first).
function Week.build(screen)
    local th = Theme.get()
    local goal = Settings.get("daily_goal", 30)
    local week = Stats.daily(7)
    local totals = Stats.totals(7)
    local values, labels, buildings = {}, {}, {}
    for i, d in ipairs(week) do
        values[i] = Metric.value(d)
        labels[i] = os.date("%a", d.time):upper():sub(1, 3)
        buildings[i] = { pages = d.pages, minutes = d.seconds / 60, current = i == #week }
    end
    local sel = week[screen.day] or week[#week]
    local skyline = Settings.get("chart_view", "bars") == "skyline"

    local tiles = Layout.Row:new({ gap = th.space.m, children = {
        tile(_("TIME"), Format.duration(totals.seconds), _("last 7 days")),
        tile(_("PAGES"), tostring(totals.pages), _("last 7 days")),
        tile(_("STREAK"), tostring(Stats.streak()), string.format(_("days, best %d"), Stats.bestStreak())),
    } })

    local detail = skyline and _("HEIGHT = PAGES // WINDOWS = 5 MIN")
        or string.format("%s = %s", os.date("%a", sel.time):upper(), Metric.text(Metric.value(sel)))
    local shown = skyline and Skyline:new({ buildings = buildings, labels = labels, height = 150 })
        or Charts.Bars:new({ values = values, labels = labels, goal = Metric.goal(goal), selected = screen.day, height = Theme.px(130),
            on_select = function(i) screen.day = i; App.update() end })
    local chart = Layout.Column:new({ gap = th.space.s, children = {
        Layout.Row:new({ children = {
            Label:new({ text = Metric.title() .. _(" // LAST 7 DAYS"), kind = "label", grow = true }),
            Label:new({ text = detail, kind = "mono_small" }),
        } }),
        shown,
    } })

    local heat = Layout.Column:new({ gap = th.space.s, children = {
        Label:new({ text = Metric.title() .. _(" // 12 WEEKS"), kind = "label" }),
        Charts.Heatmap:new({ levels = activity(goal) }),
    } })

    local log = { Label:new({ text = _("SESSION LOG"), kind = "label" }) }
    for _i, s in ipairs(Stats.sessions(6)) do
        log[#log + 1] = ListRow.build({ thumb = false, title = s.title or "?", title_kind = "body",
            meta = os.date("%a %d %b %H:%M", s.time):upper(), value = string.format(_("%dM // %d PG"), Format.minutes(s.seconds), s.pages),
            height = Theme.px(46) })
    end
    if #log == 1 then log[2] = Label:new({ text = _("No reading recorded yet. Statistics must be on."), kind = "small", color = "muted" }) end

    return Layout.Column:new({ grow = true, gap = th.space.l, children = {
        tiles, chart, heat, Layout.Column:new({ grow = true, clip = true, gap = th.space.xs, children = log }),
    } })
end

return Week
