-- The calendar tab: a month of reading days shaded by minutes, stepped back
-- and forward, and when in the week and day the reader reads.

local App = require("cyberui/app")
local Charts = require("cyberui/ui/charts")
local Format = require("cyberui/format")
local Insights = require("cyberui/data/insights")
local Controls = require("cyberui/ui/controls")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Settings = require("cyberui/settings")
local Skyline = require("cyberui/ui/skyline")
local Theme = require("cyberui/theme")
local navrow = require("cyberui/ui/navrow")
local _ = require("gettext")

local Calendar = {}

local INITIALS = { _("M"), _("T"), _("W"), _("T"), _("F"), _("S"), _("S") }

-- A row of the weekday initials above the month's columns.
local function weekdays()
    local kids = {}
    for i, s in ipairs(INITIALS) do kids[i] = Label:new({ text = s, kind = "micro", color = "muted", align = "center", grow = true }) end
    return Layout.Row:new({ children = kids })
end

-- Build the tab; `screen.cal_back` is how many months back from now.
function Calendar.build(screen)
    local th = Theme.get()
    local goal = Settings.get("daily_goal", 30)
    local now = os.date("*t")
    local first = os.time({ year = now.year, month = now.month - screen.cal_back, day = 1, hour = 12 })
    local t = os.date("*t", first)
    local days = tonumber(os.date("%d", os.time({ year = t.year, month = t.month + 1, day = 0, hour = 12 })))
    local levels, buildings = {}, {}
    for d = 1, days do buildings[d] = { pages = 0, minutes = 0, current = screen.cal_back == 0 and d == now.day } end
    local month_prefix = os.date("%Y-%m-", first)
    local month_seconds = 0
    for _i, d in ipairs(Insights.days()) do
        if d.date:sub(1, #month_prefix) == month_prefix then
            local day = tonumber(d.date:sub(9, 10))
            levels[day] = Charts.level(d.seconds, goal)
            buildings[day].pages, buildings[day].minutes = d.pages, d.seconds / 60
            month_seconds = month_seconds + d.seconds
        end
    end
    local nav = navrow({ label = os.date("%B %Y", first):upper(), can_next = screen.cal_back > 0,
        on_prev = function() screen.cal_back = screen.cal_back + 1; App.update() end,
        on_next = function() screen.cal_back = screen.cal_back - 1; App.update() end })
    local as_skyline = Settings.get("cal_view", "grid") == "skyline"
    local labels = { [1] = "1", [8] = "8", [15] = "15", [22] = "22", [days] = tostring(days) }
    local month = as_skyline and Skyline:new({ buildings = buildings, labels = labels, height = 190 })
        or Charts.Month:new({ first = (tonumber(os.date("%w", first)) + 6) % 7 + 1, days = days, levels = levels,
        today = screen.cal_back == 0 and now.day or nil })

    -- when the reader reads: a row per weekday, a column per hour
    local grid = Insights.pattern()
    local lv = {}
    if grid then
        local max = 1
        for w = 1, 7 do for h = 0, 23 do max = math.max(max, grid[w][h]) end end
        for h = 0, 23 do
            for w = 1, 7 do
                local f = grid[w][h] / max
                lv[#lv + 1] = grid[w][h] <= 0 and 0 or (f < 0.15 and 1 or (f < 0.4 and 2 or (f < 0.7 and 3 or 4)))
            end
        end
    end
    local pattern = Layout.Column:new({ gap = th.space.s, children = {
        Label:new({ text = _("WHEN YOU READ // MON-SUN BY HOUR"), kind = "label" }),
        Charts.Heatmap:new({ levels = lv, weeks = 24, rows = 7 }),
        Layout.Row:new({ children = {
            Label:new({ text = "00", kind = "micro", color = "muted", grow = true }),
            Label:new({ text = "12", kind = "micro", color = "muted", grow = true, align = "center" }),
            Label:new({ text = "23", kind = "micro", color = "muted", align = "right" }),
        } }),
    } })
    local view = Controls.Segmented({ options = { { _("GRID"), "grid" }, { _("SKYLINE"), "skyline" } }, value = as_skyline and "skyline" or "grid",
        kind = "label", on_change = function(v) Settings.save("cal_view", v); App.update() end })
    local note = as_skyline and _("HEIGHT = PAGES // LIT WINDOWS = 5 MIN EACH") or string.format(_("%s READ THIS MONTH"), Format.duration(month_seconds))
    local kids = { nav, view }
    if not as_skyline then kids[#kids + 1] = weekdays() end
    kids[#kids + 1] = month
    kids[#kids + 1] = Label:new({ text = note, kind = "mono_small", color = "muted" })
    kids[#kids + 1] = pattern
    return Layout.Column:new({ grow = true, gap = th.space.m, children = kids })
end

return Calendar
