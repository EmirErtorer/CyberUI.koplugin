-- Longer-term reading numbers from the statistics database: totals per day,
-- month and year, streaks, records, when in the week the reader reads, the
-- milestones passed and the facts of one book. Like Stats, every result is
-- cached until a book is read and respects the statistics scope.

local Statsdb = require("cyberui/data/statsdb")

local Insights = {}

local rows = Statsdb.rows

-- Total hours at which a milestone ("clearance level") is reached.
Insights.MILESTONES = { 1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000 }

-- Noon of a "YYYY-MM-DD" date, as a time.
local function noon(date)
    local y, m, d = date:match("^(%d+)-(%d+)-(%d+)$")
    return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

-- Seconds and pages read on every day with reading, oldest first:
-- { date = "YYYY-MM-DD", time = noon, seconds, pages }.
function Insights.days()
    return Statsdb.cached("allDays", function()
        return Statsdb.query(function(conn)
            local out = {}
            for _i, r in ipairs(rows(conn, string.format(
                "SELECT date(start_time,'unixepoch','localtime'), sum(duration), count(DISTINCT id_book || ':' || page) "
                .. "FROM page_stat_data WHERE 1 = 1%s GROUP BY 1 ORDER BY 1", Statsdb.scoped(conn)))) do
                out[#out + 1] = { date = r[1], time = noon(r[1]), seconds = tonumber(r[2]) or 0, pages = tonumber(r[3]) or 0 }
            end
            return out
        end)
    end) or {}
end

-- Totals over the days in [from, to] (times): { seconds, pages, days }.
function Insights.range(from, to)
    local t = { seconds = 0, pages = 0, days = 0 }
    for _i, d in ipairs(Insights.days()) do
        if d.time >= from and d.time <= to then
            t.seconds, t.pages, t.days = t.seconds + d.seconds, t.pages + d.pages, t.days + 1
        end
    end
    return t
end

-- Seconds and pages for each month of a year: a list of 12 { seconds, pages }.
function Insights.months(year)
    local out = {}
    for m = 1, 12 do out[m] = { seconds = 0, pages = 0 } end
    for _i, d in ipairs(Insights.days()) do
        local y, m = d.date:match("^(%d+)-(%d+)")
        if tonumber(y) == year then
            local slot = out[tonumber(m)]
            slot.seconds, slot.pages = slot.seconds + d.seconds, slot.pages + d.pages
        end
    end
    return out
end

-- The first year with reading, or the current one.
function Insights.firstYear()
    local d = Insights.days()[1]
    return d and tonumber(d.date:sub(1, 4)) or tonumber(os.date("%Y"))
end

-- Everything ever read: { seconds, pages, days, first }.
function Insights.allTime()
    local t = { seconds = 0, pages = 0, days = 0 }
    for _i, d in ipairs(Insights.days()) do
        t.seconds, t.pages, t.days = t.seconds + d.seconds, t.pages + d.pages, t.days + 1
        t.first = t.first or d.time
    end
    return t
end

-- Monday 2001-01-01: weeks are counted from it.
local WEEK_ANCHOR = os.time({ year = 2001, month = 1, day = 1, hour = 12 })

-- The week a day falls in, as a number (Monday first).
local function weekOf(time)
    return math.floor((time - WEEK_ANCHOR) / 604800)
end

-- Streaks of days and of weeks with reading: { day_best, day_now, week_best, week_now }.
function Insights.streaks()
    return Statsdb.cached("streaks", function()
        local days = Insights.days()
        local best_d, run_d, last_day = 0, 0, nil
        local best_w, run_w, last_week = 0, 0, nil
        for _i, d in ipairs(days) do
            if d.seconds > 0 then
                local day_no = math.floor(d.time / 86400 + 0.5)
                run_d = (last_day and day_no - last_day == 1) and run_d + 1 or 1
                last_day = day_no
                best_d = math.max(best_d, run_d)
                local wk = weekOf(d.time)
                if wk ~= last_week then
                    run_w = (last_week and wk - last_week == 1) and run_w + 1 or 1
                    last_week = wk
                    best_w = math.max(best_w, run_w)
                end
            end
        end
        -- a streak is still alive when its last day is today or yesterday (its last week this one or the one before)
        local today = math.floor(Statsdb.midnight(0) / 86400 + 0.5)
        local this_week = weekOf(Statsdb.midnight(0) + 43200)
        return {
            day_best = best_d, day_now = (last_day and today - last_day <= 1) and run_d or 0,
            week_best = best_w, week_now = (last_week and this_week - last_week <= 1) and run_w or 0,
        }
    end) or { day_best = 0, day_now = 0, week_best = 0, week_now = 0 }
end

-- The best days: { time = { date, seconds }, pages = { date, pages } }.
function Insights.records()
    local best_t, best_p = { seconds = 0 }, { pages = 0 }
    for _i, d in ipairs(Insights.days()) do
        if d.seconds > best_t.seconds then best_t = d end
        if d.pages > best_p.pages then best_p = d end
    end
    return { time = best_t, pages = best_p }
end

-- The milestone last passed and the next one, for a number of hours:
-- { last (hours or nil), next (hours or nil), level (how many passed) }.
function Insights.clearance(hours)
    local last, nxt, level = nil, nil, 0
    for i, h in ipairs(Insights.MILESTONES) do
        if hours >= h then last, level = h, i elseif not nxt then nxt = h end
    end
    return { last = last, next = nxt, level = level }
end

-- Reading in each hour of each weekday: { seconds = grid, pages = grid }, each
-- grid[weekday 1..7 (Monday first)][hour 0..23]. A page view counts in the hour
-- it began in.
function Insights.pattern()
    return Statsdb.cached("pattern", function()
        return Statsdb.query(function(conn)
            local seconds, pages = {}, {}
            for w = 1, 7 do
                seconds[w], pages[w] = {}, {}
                for h = 0, 23 do seconds[w][h], pages[w][h] = 0, 0 end
            end
            for _i, r in ipairs(rows(conn, string.format(
                "SELECT strftime('%%w', start_time,'unixepoch','localtime'), strftime('%%H', start_time,'unixepoch','localtime'), "
                .. "sum(duration), count(DISTINCT id_book || ':' || page) FROM page_stat_data WHERE 1 = 1%s GROUP BY 1, 2",
                Statsdb.scoped(conn)))) do
                local w = (tonumber(r[1]) + 6) % 7 + 1   -- sunday 0 becomes the last
                seconds[w][tonumber(r[2])] = tonumber(r[3]) or 0
                pages[w][tonumber(r[2])] = tonumber(r[4]) or 0
            end
            return { seconds = seconds, pages = pages }
        end)
    end)
end

-- Quote a value for SQL.
local function quote(s)
    return "'" .. tostring(s):gsub("'", "''") .. "'"
end

-- The reading facts of one book: { seconds, pages, days, first, last,
-- per_page (seconds), total_pages }; nil when it was never read.
function Insights.book(path)
    return Statsdb.cached("book|" .. path, function()
        local Books = require("cyberui/data/books")
        local ok, ds = pcall(function() return require("docsettings"):open(path) end)
        local md5 = ok and ds and ds:readSetting("partial_md5_checksum") or nil
        local title = Books.info(path).title
        return Statsdb.query(function(conn)
            local ids = rows(conn, string.format("SELECT id, pages FROM book WHERE (md5 = %s AND md5 != '') OR title = %s",
                quote(md5 or ""), quote(title)))
            if #ids == 0 then return nil end
            local list, total = {}, 0
            for _i, r in ipairs(ids) do list[#list + 1] = string.format("%d", tonumber(r[1])); total = math.max(total, tonumber(r[2]) or 0) end
            local r = rows(conn, string.format(
                "SELECT sum(duration), count(DISTINCT page), count(DISTINCT date(start_time,'unixepoch','localtime')), min(start_time), max(start_time) "
                .. "FROM page_stat_data WHERE id_book IN (%s)", table.concat(list, ",")))[1]
            local pages = tonumber(r and r[2]) or 0
            if pages == 0 then return nil end
            local seconds = tonumber(r[1]) or 0
            return { seconds = seconds, pages = pages, days = tonumber(r[3]) or 0, first = tonumber(r[4]), last = tonumber(r[5]),
                per_page = seconds / pages, total_pages = total }
        end)
    end)
end

return Insights
