-- What the reading log counts: minutes read or pages read. The reader picks
-- one in the log and it applies to the bars, the calendar and the hour grid.

local Charts = require("cyberui/ui/charts")
local Settings = require("cyberui/settings")
local _ = require("cyberui/gettext")

local Metric = {}

-- Are pages the thing counted?
function Metric.pages()
    return Settings.get("log_metric", "minutes") == "pages"
end

-- Switch between minutes and pages.
function Metric.toggle()
    Settings.save("log_metric", Metric.pages() and "minutes" or "pages")
end

-- The short unit: "MIN" or "PG".
function Metric.unit()
    return Metric.pages() and _("PG") or _("MIN")
end

-- The chart title for what is counted, over `span` ("week", "weeks", or nothing for the bare title).
function Metric.title(span)
    if span == "week" then return Metric.pages() and _("PAGES READ // LAST 7 DAYS") or _("MINUTES READ // LAST 7 DAYS") end
    if span == "weeks" then return Metric.pages() and _("PAGES READ // 12 WEEKS") or _("MINUTES READ // 12 WEEKS") end
    return Metric.pages() and _("PAGES READ") or _("MINUTES READ")
end

-- The number to chart for a day, month or hour record { seconds, pages }.
function Metric.value(rec)
    return Metric.pages() and rec.pages or rec.seconds / 60
end

-- A number as "25 MIN" or "12 PG".
function Metric.text(value)
    return string.format("%d %s", math.floor(value + 0.5), Metric.unit())
end

-- The shade 0..4 for a value: against the daily goal for minutes, against
-- the largest value shown (`max`) for pages.
function Metric.level(value, goal, max)
    if value <= 0 then return 0 end
    if not Metric.pages() then return Charts.level(value * 60, goal) end
    local f = value / math.max(1, max)
    return f < 0.15 and 1 or (f < 0.4 and 2 or (f < 0.7 and 3 or 4))
end

-- The daily goal line for a chart, or nil when pages are counted (the goal is
-- in minutes).
function Metric.goal(goal)
    return not Metric.pages() and goal or nil
end

return Metric
