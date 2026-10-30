-- The streaks tab: streaks of days and weeks, the personal records, totals
-- since the first day and the clearance level (hours read against the next
-- milestone).

local Format = require("cyberui/format")
local Insights = require("cyberui/data/insights")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Progress = require("cyberui/ui/progress")
local Theme = require("cyberui/theme")
local tile = require("cyberui/ui/stattile")
local _ = require("cyberui/gettext")

local Streaks = {}

-- A label and its value on one line.
local function fact(k, v)
    return Layout.Row:new({ children = {
        Label:new({ text = k, kind = "mono_small", color = "muted", grow = true }),
        Label:new({ text = v, kind = "mono_small" }),
    } })
end

-- A date as "12 OCT 2026".
local function date(d)
    return d and d.date and Format.upper(Format.date("%d %b %Y", d.time)) or "-"
end

-- Build the tab.
function Streaks.build()
    local th = Theme.get()
    local s = Insights.streaks()
    local all = Insights.allTime()
    local rec = Insights.records()
    local hours = all.seconds / 3600
    local c = Insights.clearance(hours)
    local frac = c.next and (hours - (c.last or 0)) / (c.next - (c.last or 0)) or 1

    local tiles = Layout.Row:new({ gap = th.space.m, children = {
        tile(_("DAY STREAK"), tostring(s.day_now), string.format(_("BEST %d"), s.day_best)),
        tile(_("WEEK STREAK"), tostring(s.week_now), string.format(_("BEST %d"), s.week_best)),
        tile(_("HOURS"), string.format("%d", math.floor(hours)), string.format(_.n("%d PAGE", "%d PAGES", all.pages), all.pages)),
    } })
    local records = Panel:new({ shape = "frame", pad = th.space.m, child = Layout.Column:new({ gap = th.space.xs, children = {
        Label:new({ text = _("RECORDS"), kind = "micro", color = "muted" }),
        fact(_("LONGEST DAY"), string.format("%s // %s", Format.duration(rec.time.seconds), date(rec.time))),
        fact(_("MOST PAGES"), string.format("%d // %s", rec.pages.pages or 0, date(rec.pages))),
        fact(_("DAYS READ"), tostring(all.days)),
        fact(_("SINCE"), all.first and Format.upper(Format.date("%d %b %Y", all.first)) or "-"),
    } }) })
    local level = Layout.Column:new({ gap = th.space.s, children = {
        Layout.Row:new({ children = {
            Label:new({ text = string.format(_("CLEARANCE LEVEL %02d"), c.level), kind = "label", grow = true }),
            Label:new({ text = c.next and string.format(_("NEXT %dH // %dH LEFT"), c.next, math.ceil(c.next - hours)) or _("MAXED"),
                kind = "mono_small", color = "muted" }),
        } }),
        Progress:new({ value = math.max(0, math.min(frac, 1)) }),
    } })
    return Layout.Column:new({ grow = true, gap = th.space.l, children = { tiles, records, level } })
end

return Streaks
