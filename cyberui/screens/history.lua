-- The reading log ("telemetry"): totals for the week, minutes per day with
-- the daily goal, twelve weeks of activity and the latest reading sessions.

local App = require("cyberui/app")
local Charts = require("cyberui/ui/charts")
local Format = require("cyberui/format")
local Frame = require("cyberui/screens/frame")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local ListRow = require("cyberui/ui/listrow")
local Panel = require("cyberui/ui/panel")
local Screen = require("cyberui/screens/screen")
local Settings = require("cyberui/settings")
local Stats = require("cyberui/data/stats")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local History = Screen:extend()

-- Today is selected in the chart at first.
function History:init()
    self.day = 7
end

-- A total in a chamfered tile.
local function tile(k, v, note)
    local th = Theme.get()
    return Panel:new({ shape = "chamfer", corners = "r", cut = "cut_small", grow = true, pad = th.space.s,
        child = Layout.Column:new({ children = {
            Label:new({ text = k, kind = "micro", color = "muted" }),
            Label:new({ text = v, kind = "number" }),
            Label:new({ text = note, kind = "small", color = "muted" }),
        } }) })
end

-- Heatmap levels 0..4 for the last `weeks` weeks from minutes per day.
local function levels(days, goal)
    local out = {}
    for i, d in ipairs(days) do
        local m = d.seconds / 60
        out[i] = m <= 0 and 0 or (m < goal / 3 and 1 or (m < goal and 2 or (m < goal * 2 and 3 or 4)))
    end
    return out
end

-- Build the log.
function History:build()
    local th = Theme.get()
    local goal = Settings.get("daily_goal", 30)
    local week = Stats.daily(7)
    local totals = Stats.totals(7)
    local values, labels = {}, {}
    for i, d in ipairs(week) do
        values[i] = d.seconds / 60
        labels[i] = os.date("%a", d.time):upper():sub(1, 3)
    end
    local sel = week[self.day] or week[#week]

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
        Charts.Bars:new({ values = values, labels = labels, goal = goal, selected = self.day, height = Theme.px(130),
            on_select = function(i) self.day = i; App.update() end }),
    } })

    local heat = Layout.Column:new({ gap = th.space.s, children = {
        Label:new({ text = _("ACTIVITY // 12 WEEKS"), kind = "label" }),
        Charts.Heatmap:new({ levels = levels(Stats.daily(84), goal) }),
    } })

    local log = { Label:new({ text = _("SESSION LOG"), kind = "label" }) }
    for _i, s in ipairs(Stats.sessions(6)) do
        log[#log + 1] = ListRow.build({ thumb = false, title = s.title or "?", title_kind = "body",
            meta = os.date("%a %d %b %H:%M", s.time):upper(), value = string.format(_("%dM // %d PG"), Format.minutes(s.seconds), s.pages),
            height = Theme.px(46) })
    end
    if #log == 1 then log[2] = Label:new({ text = _("No reading recorded yet. Statistics must be on."), kind = "small", color = "muted" }) end

    return Frame.page({
        screen = self, title = _("Telemetry.log"), path = "/VAR/LOG/", tab = "history",
        body = Layout.Column:new({ gap = th.space.l, children = {
            tiles, chart, heat, Layout.Column:new({ grow = true, clip = true, gap = th.space.xs, children = log }),
        } }),
    })
end

-- Coming back after reading: the numbers changed.
function History:onRaise()
    Stats.invalidate()
end

return History
