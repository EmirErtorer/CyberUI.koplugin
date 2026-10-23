-- Reading statistics from KOReader's statistics database (read only): time read
-- per day, the reading streak, totals and recent sessions. Results are cached
-- until a book is closed, since only reading changes them.

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")

local Stats = {}

local cache = {}

-- Run fn(conn) on an open connection; nil when there is no database.
local function query(fn)
    local path = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
    if not lfs.attributes(path, "mode") then return nil end
    local ok_lib, SQ3 = pcall(require, "lua-ljsqlite3/init")
    if not ok_lib then return nil end
    local ok_open, conn = pcall(SQ3.open, path)
    if not ok_open or not conn then return nil end
    local ok, result = pcall(fn, conn)
    conn:close()
    return ok and result or nil
end

-- Rows of a query as a list of arrays (column order as in the SELECT).
local function rows(conn, sql)
    local res, n = conn:exec(sql)
    local out = {}
    if not res or not n or n == 0 then return out end
    for i = 1, n do
        local row = {}
        for c = 1, #res do row[c] = res[c][i] end
        out[i] = row
    end
    return out
end

-- Remember a value until the next invalidate().
local function cached(key, fn)
    if cache[key] == nil then cache[key] = fn() or false end
    return cache[key] or nil
end

-- Midnight (local time) `days` days before today.
local function midnight(days)
    local t = os.date("*t")
    t.hour, t.min, t.sec = 0, 0, 0
    return os.time(t) - days * 86400
end

-- Seconds read on each of the last `n` days, oldest first: { date, seconds }.
function Stats.daily(n)
    return cached("daily" .. n, function()
        local since = midnight(n - 1)
        local by_day = {}
        query(function(conn)
            for _, r in ipairs(rows(conn, string.format(
                "SELECT date(start_time,'unixepoch','localtime'), sum(duration) FROM page_stat_data "
                .. "WHERE start_time >= %d GROUP BY 1", since))) do
                by_day[r[1]] = tonumber(r[2]) or 0
            end
        end)
        local out = {}
        for i = n - 1, 0, -1 do
            local day = os.date("%Y-%m-%d", midnight(i) + 43200)
            out[#out + 1] = { date = day, time = midnight(i), seconds = by_day[day] or 0 }
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
    local days = Stats.daily(365) or {}
    local count = 0
    local i = #days
    if i > 0 and days[i].seconds == 0 then i = i - 1 end
    while i > 0 and days[i].seconds > 0 do
        count = count + 1
        i = i - 1
    end
    return count
end

-- Longest run of reading days in the last year.
function Stats.bestStreak()
    local best, run = 0, 0
    for _, d in ipairs(Stats.daily(365) or {}) do
        if d.seconds > 0 then run = run + 1; best = math.max(best, run) else run = 0 end
    end
    return best
end

-- Seconds and pages read over the last `n` days.
function Stats.totals(n)
    return cached("totals" .. n, function()
        return query(function(conn)
            local r = rows(conn, string.format(
                "SELECT sum(duration), count(*) FROM page_stat_data WHERE start_time >= %d", midnight(n - 1)))[1]
            return { seconds = tonumber(r and r[1]) or 0, pages = tonumber(r and r[2]) or 0 }
        end)
    end) or { seconds = 0, pages = 0 }
end

-- Books with any reading this calendar year.
function Stats.booksThisYear()
    return cached("year", function()
        local t = os.date("*t")
        local start = os.time({ year = t.year, month = 1, day = 1, hour = 0 })
        return query(function(conn)
            local r = rows(conn, string.format(
                "SELECT count(DISTINCT id_book) FROM page_stat_data WHERE start_time >= %d", start))[1]
            return tonumber(r and r[1]) or 0
        end)
    end) or 0
end

-- The `n` latest reading sessions (one per book per day): { title, time, seconds, pages }.
function Stats.sessions(n)
    return cached("sessions" .. n, function()
        return query(function(conn)
            local out = {}
            for _, r in ipairs(rows(conn, string.format(
                "SELECT b.title, max(p.start_time), sum(p.duration), count(*) FROM page_stat_data p "
                .. "JOIN book b ON b.id = p.id_book GROUP BY p.id_book, date(p.start_time,'unixepoch','localtime') "
                .. "ORDER BY 2 DESC LIMIT %d", n))) do
                out[#out + 1] = { title = r[1], time = tonumber(r[2]), seconds = tonumber(r[3]) or 0, pages = tonumber(r[4]) or 0 }
            end
            return out
        end)
    end) or {}
end

-- Forget cached results (a book was read).
function Stats.invalidate()
    cache = {}
end

return Stats
