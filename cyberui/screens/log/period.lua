-- The stats tab: a week, month or year at a time, with a back and forward
-- step, a bar chart, averages and a comparison with the period before.

local App = require("cyberui/app")
local Charts = require("cyberui/ui/charts")
local Controls = require("cyberui/ui/controls")
local Format = require("cyberui/format")
local Insights = require("cyberui/data/insights")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Settings = require("cyberui/settings")
local Skyline = require("cyberui/ui/skyline")
local Statsdb = require("cyberui/data/statsdb")
local Theme = require("cyberui/theme")
local navrow = require("cyberui/ui/navrow")
local tile = require("cyberui/ui/stattile")
local _ = require("gettext")

local Period = {}

local DAY = 86400

-- Midnight at the start of a date table.
local function at(y, m, d)
    return os.time({ year = y, month = m, day = d, hour = 0 })
end

-- The period `back` steps before now: { from, to (times), caption, count (bars),
-- label(i), start(i) (the time bar i begins at), span (seconds per bar) }.
local function range(kind, back)
    local now = os.date("*t")
    if kind == "week" then
        local monday = Statsdb.midnight((now.wday + 5) % 7 + 7 * back)
        local last = monday + 6 * DAY
        return { from = monday, to = monday + 7 * DAY - 1, count = 7, span = DAY,
            caption = os.date("%d %b", monday):upper() .. " - " .. os.date("%d %b", last):upper(),
            label = function(i) return os.date("%a", monday + (i - 1) * DAY + 43200):upper():sub(1, 3) end,
            start = function(i) return monday + (i - 1) * DAY end }
    elseif kind == "month" then
        local first = at(now.year, now.month - back, 1)
        local t = os.date("*t", first)
        local days = tonumber(os.date("%d", at(t.year, t.month + 1, 0)))
        return { from = first, to = first + days * DAY - 1, count = days, span = DAY,
            caption = os.date("%B %Y", first):upper(),
            label = function(i) return (i == 1 or i % 5 == 0) and tostring(i) or "" end,
            start = function(i) return first + (i - 1) * DAY end }
    end
    local year = now.year - back
    return { from = at(year, 1, 1), to = at(year + 1, 1, 1) - 1, count = 12, month = true, year = year,
        caption = tostring(year),
        label = function(i) return os.date("%b", at(year, i, 1)):upper():sub(1, 1) end,
        start = function(i) return at(year, i, 1) end }
end

-- Seconds and pages read in each bar of a period, as two lists.
local function bars(r)
    local secs, pages = {}, {}
    for i = 1, r.count do secs[i], pages[i] = 0, 0 end
    if r.month then
        for i, m in ipairs(Insights.months(r.year)) do secs[i], pages[i] = m.seconds, m.pages end
        return secs, pages
    end
    for _i, d in ipairs(Insights.days()) do
        if d.time >= r.from and d.time <= r.to then
            local i = math.floor((d.time - r.from) / DAY) + 1
            if secs[i] then secs[i], pages[i] = d.seconds, d.pages end
        end
    end
    return secs, pages
end

-- Whole days of the period gone by now (all of it for a past period).
local function elapsed(r)
    local last = math.min(os.time(), r.to)
    return math.max(1, math.ceil((last - r.from) / DAY))
end

-- "+12% VS BEFORE", or nothing to compare with.
local function versus(now_s, before_s)
    if before_s <= 0 then return _("NOTHING BEFORE") end
    local pct = math.floor((now_s - before_s) / before_s * 100 + 0.5)
    return string.format(pct >= 0 and _("+%d%% VS BEFORE") or _("%d%% VS BEFORE"), pct)
end

-- One bar chart under its title, the picked bar's value (or the best) on the right.
local function barChart(screen, title, detail, values, labels, pick, height)
    return Layout.Column:new({ gap = Theme.get().space.s, children = {
        Layout.Row:new({ children = {
            Label:new({ text = title, kind = "label", grow = true }),
            Label:new({ text = detail, kind = "mono_small" }),
        } }),
        Charts.Bars:new({ values = values, labels = labels, selected = pick or 0, height = Theme.px(height),
            on_select = function(i) screen.bar = i; App.update() end }),
    } })
end

-- Build the tab. State on the screen: period ("week", "month", "year"),
-- back (steps back from now) and bar (the bar picked, or nil). Minutes and
-- pages each get a chart (or one skyline of both).
function Period.build(screen)
    local th = Theme.get()
    local kind, back = screen.period, screen.back
    local r, before = range(kind, back), range(kind, back + 1)
    local secs, pages = bars(r)
    local total = Insights.range(r.from, r.to)
    -- a period not over yet is set against the same stretch of the one before
    local prev = Insights.range(before.from, back == 0 and before.from + (os.time() - r.from) or before.to)
    local best_s, best_p = 0, 0
    local mins, labels, buildings, skyline_labels = {}, {}, {}, {}
    for i, s in ipairs(secs) do
        mins[i] = s / 60
        labels[i] = r.label(i)
        if labels[i] ~= "" then skyline_labels[i] = labels[i] end
        buildings[i] = { pages = pages[i], minutes = s / 60 }
        best_s, best_p = math.max(best_s, s), math.max(best_p, pages[i])
    end
    local pick = screen.bar and secs[screen.bar] and screen.bar or nil
    local when = pick and os.date("%d %b", r.start(pick) + 43200):upper()

    local seg = Controls.Segmented({ options = { { _("Week"), "week" }, { _("Month"), "month" }, { _("Year"), "year" } },
        value = kind, kind = "label", on_change = function(v) screen.period, screen.back, screen.bar = v, 0, nil; App.update() end })
    local nav = navrow({ label = r.caption, can_next = back > 0,
        on_prev = function() screen.back, screen.bar = back + 1, nil; App.update() end,
        on_next = function() screen.back, screen.bar = back - 1, nil; App.update() end })
    local tiles = Layout.Row:new({ gap = th.space.m, children = {
        tile(_("TIME"), Format.duration(total.seconds), versus(total.seconds, prev.seconds)),
        tile(_("PAGES"), tostring(total.pages), string.format(_("%d DAYS READ"), total.days)),
        tile(_("AVG / DAY"), Format.duration(math.floor(total.seconds / elapsed(r))), _("OVER THE PERIOD")),
    } })
    local body = { seg, nav, tiles }
    if Settings.get("chart_view", "bars") == "skyline" then
        body[#body + 1] = Layout.Column:new({ gap = th.space.s, children = {
            Label:new({ text = _("HEIGHT = PAGES // LIT WINDOWS = TIME READ"), kind = "label" }),
            Skyline:new({ buildings = buildings, labels = skyline_labels, height = 210 }),
        } })
    else
        body[#body + 1] = barChart(screen, _("MINUTES READ"), pick and string.format("%s = %d MIN", when, Format.minutes(secs[pick]))
            or string.format(_("BEST %s"), Format.duration(best_s)), mins, labels, pick, 120)
        body[#body + 1] = barChart(screen, _("PAGES READ"), pick and string.format("%s = %d PG", when, pages[pick])
            or string.format(_("BEST %d PG"), best_p), pages, labels, pick, 100)
    end
    return Layout.Column:new({ grow = true, gap = th.space.l, children = body })
end

return Period
