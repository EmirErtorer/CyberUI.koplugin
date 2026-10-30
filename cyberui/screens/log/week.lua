-- The log tab: this week's totals, minutes per day against the daily goal,
-- twelve weeks of activity and the latest reading sessions.

local App = require("cyberui/app")
local Charts = require("cyberui/ui/charts")
local Format = require("cyberui/format")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local ListRow = require("cyberui/ui/listrow")
local Settings = require("cyberui/settings")
local Stats = require("cyberui/data/stats")
local Theme = require("cyberui/theme")
local tile = require("cyberui/ui/stattile")
local _ = require("gettext")

local Week = {}

-- Build the tab; `screen.day` is the selected bar (today at first).
function Week.build(screen)
    local th = Theme.get()
    local goal = Settings.get("daily_goal", 30)
    local week = Stats.daily(7)
    local totals = Stats.totals(7)
    local values, labels = {}, {}
    for i, d in ipairs(week) do
        values[i] = d.seconds / 60
        labels[i] = os.date("%a", d.time):upper():sub(1, 3)
    end
    local sel = week[screen.day] or week[#week]

    local tiles = Layout.Row:new({ gap = th.space.m, children = {
        tile(_("TIME"), Format.duration(totals.seconds), _("this week")),
        tile(_("PAGES"), tostring(totals.pages), _("this week")),
        tile(_("STREAK"), tostring(Stats.streak()), string.format(_("days, best %d"), Stats.bestStreak())),
    } })

    local chart = Layout.Column:new({ gap = th.space.s, children = {
        Layout.Row:new({ children = {
            Label:new({ text = _("MINUTES READ // THIS WEEK"), kind = "label", grow = true }),
            Label:new({ text = string.format("%s = %d MIN", os.date("%a", sel.time):upper(), Format.minutes(sel.seconds)), kind = "mono_small" }),
        } }),
        Charts.Bars:new({ values = values, labels = labels, goal = goal, selected = screen.day, height = Theme.px(130),
            on_select = function(i) screen.day = i; App.update() end }),
    } })

    local levels = {}
    for i, d in ipairs(Stats.daily(84)) do levels[i] = Charts.level(d.seconds, goal) end
    local heat = Layout.Column:new({ gap = th.space.s, children = {
        Label:new({ text = _("ACTIVITY // 12 WEEKS"), kind = "label" }),
        Charts.Heatmap:new({ levels = levels }),
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
