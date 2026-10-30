-- Reading statistics from KOReader's statistics database (read only): time read
-- per day, the reading streak, totals and recent sessions. Results are cached
-- until a book is closed, since only reading changes them.

local Insights = require("cyberui/data/insights")
local Statsdb = require("cyberui/data/statsdb")

local Stats = {}

local query, rows, cached, midnight = Statsdb.query, Statsdb.rows, Statsdb.cached, Statsdb.midnight

-- Reading on each of the last `n` days, oldest first: { date, time, seconds,
-- pages }. Every number in the log comes from the same per-day totals
-- (Insights.days), so the tabs always agree.
function Stats.daily(n)
    return cached("daily" .. n, function()
        local by_day = {}
        for _i, d in ipairs(Insights.days()) do by_day[d.date] = d end
        local out = {}
        for i = n - 1, 0, -1 do
            local day = os.date("%Y-%m-%d", midnight(i) + 43200)
            local d = by_day[day]
            out[#out + 1] = { date = day, time = midnight(i), seconds = d and d.seconds or 0, pages = d and d.pages or 0 }
        end
        return out
    end)
end

-- Seconds read today.
function Stats.today()
    local d = Stats.daily(1)
    return d and d[1].seconds or 0
end

-- Days in a row with some reading, counting back from today (or yesterday
-- when nothing was read yet today).
function Stats.streak()
    return Insights.streaks().day_now
end

-- Longest run of reading days ever.
function Stats.bestStreak()
    return Insights.streaks().day_best
end

-- Seconds and pages read over the last `n` days (pages counted per day, as the
-- daily numbers are).
function Stats.totals(n)
    local t = { seconds = 0, pages = 0 }
    for _i, d in ipairs(Stats.daily(n) or {}) do
        t.seconds, t.pages = t.seconds + d.seconds, t.pages + d.pages
    end
    return t
end

-- Books with any reading this calendar year.
function Stats.booksThisYear()
    return cached("year", function()
        local t = os.date("*t")
        local start = os.time({ year = t.year, month = 1, day = 1, hour = 0 })
        return query(function(conn)
            local r = rows(conn, string.format(
                "SELECT count(DISTINCT id_book) FROM page_stat_data WHERE start_time >= %d%s", start, Statsdb.scoped(conn)))[1]
            return tonumber(r and r[1]) or 0
        end)
    end) or 0
end

-- The `n` latest reading sessions (one per book per day): { title, time, seconds, pages }.
function Stats.sessions(n)
    return cached("sessions" .. n, function()
        return query(function(conn)
            local out = {}
            for _i, r in ipairs(rows(conn, string.format(
                "SELECT b.title, max(p.start_time), sum(p.duration), count(DISTINCT p.page) FROM page_stat_data p "
                .. "JOIN book b ON b.id = p.id_book WHERE 1 = 1%s GROUP BY p.id_book, date(p.start_time,'unixepoch','localtime') "
                .. "ORDER BY 2 DESC LIMIT %d", Statsdb.scoped(conn, "p.id_book"), n))) do
                out[#out + 1] = { title = r[1], time = tonumber(r[2]), seconds = tonumber(r[3]) or 0, pages = tonumber(r[4]) or 0 }
            end
            return out
        end)
    end) or {}
end

-- Forget cached results (a book was read).
function Stats.invalidate()
    Statsdb.invalidate()
end

return Stats
