-- The reading numbers on a small statistics database made for the test:
-- days, months, streaks, records, the clearance ladder, the statistics scope
-- and one book's facts.
-- Run: cd <emulator>/koreader && ./luajit <repo>/tests/stats.lua <repo>

local REPO = arg[1] or "."
local Kit = dofile(REPO .. "/tests/kit.lua").boot(REPO)
local books_dir = require("datastorage"):getDataDir() .. "/Books"
G_reader_settings:saveSetting("home_dir", books_dir)

-- two books of the library, so the scope has folders to tell apart
local Library = require("cyberui/data/library")
local Books = require("cyberui/data/books")
local all = Library.all()
local a, b = all[1], all[#all]
local Settings = require("cyberui/settings")

-- a statistics database in a folder of its own
local dir = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-stats-test"
os.execute("rm -rf '" .. dir .. "' && mkdir -p '" .. dir .. "'")
local DataStorage = require("datastorage")
DataStorage.getSettingsDir = function() return dir end
local function esc(s) return (s:gsub("'", "''")) end
local sql = {
    "CREATE TABLE book (id integer PRIMARY KEY autoincrement, title text, authors text, notes integer, last_open integer,"
        .. " highlights integer, pages integer, series text, language text, md5 text, total_read_time integer, total_read_pages integer);",
    "CREATE TABLE page_stat_data (id_book integer, page integer NOT NULL DEFAULT 0, start_time integer NOT NULL DEFAULT 0,"
        .. " duration integer NOT NULL DEFAULT 0, total_pages integer NOT NULL DEFAULT 0, UNIQUE (id_book, page, start_time));",
    string.format("INSERT INTO book (id, title, authors, pages, md5) VALUES (1, '%s', 'x', 200, 'md5a');", esc(Books.info(a).title)),
    string.format("INSERT INTO book (id, title, authors, pages, md5) VALUES (2, '%s', 'y', 100, 'md5b');", esc(Books.info(b).title)),
}
-- book 1: four days in a row ending today, pages 1-3 each day (the same pages again each day);
-- book 2: one long day a month ago
local now = os.time()
local function at(days_ago, hour)
    local t = os.date("*t", now - days_ago * 86400)
    t.hour, t.min, t.sec = hour, 0, 0
    return os.time(t)
end
for d = 0, 3 do
    for page = 1, 3 do
        sql[#sql + 1] = string.format("INSERT INTO page_stat_data VALUES (1, %d, %d, 600, 200);", page, at(d, 9) + page * 10)
    end
end
for page = 1, 5 do
    sql[#sql + 1] = string.format("INSERT INTO page_stat_data VALUES (2, %d, %d, 1200, 100);", page, at(35, 21) + page * 10)
end
local f = io.popen("sqlite3 '" .. dir .. "/statistics.sqlite3'", "w")
f:write(table.concat(sql, "\n"))
f:close()

local Insights = require("cyberui/data/insights")
local Stats = require("cyberui/data/stats")
local Scope = require("cyberui/data/statsscope")

local days = Insights.days()
Kit.ok(#days == 5, "five days with reading (got " .. #days .. ")")
Kit.ok(days[#days].seconds == 1800 and days[#days].pages == 3, "a day sums its time and counts each page once")
local all_time = Insights.allTime()
Kit.ok(all_time.seconds == 4 * 1800 + 6000, "the all-time total adds every day")
local s = Insights.streaks()
Kit.ok(s.day_best == 4 and s.day_now == 4, "a streak of four days, still alive")
Kit.ok(s.week_best >= 1 and s.week_now >= 1, "and a streak of weeks")
local rec = Insights.records()
Kit.ok(rec.time.seconds == 6000, "the longest day is the long one")
local c = Insights.clearance(11.5)
Kit.ok(c.last == 10 and c.next == 25 and c.level == 3, "11.5 hours is level 3, next 25")
Kit.ok(Insights.clearance(0).last == nil and Insights.clearance(0).next == 1, "no hours is level 0, next 1")
local year = tonumber(os.date("%Y"))
local months = Insights.months(year)
local sum = 0
for _, m in ipairs(months) do sum = sum + m.seconds end
Kit.ok(#months == 12 and sum > 0, "a year splits into twelve months")
local grid = Insights.pattern()
Kit.ok(grid and grid[1][9] ~= nil, "the weekday by hour grid is there")
local sessions = Stats.sessions(10)
Kit.ok(sessions and sessions[1].pages == 3, "a session counts its pages once")
local book = Insights.book(a)
Kit.ok(book and book.pages == 3 and book.days == 4 and book.total_pages == 200, "one book's facts: pages, days and its length")
Kit.ok(book and book.per_page == 7200 / 3, "and its seconds per page")

-- scope: only the folder of book b
local parent = require("cyberui/data/files").parent(b)
Scope.set({ parent })
local in_scope = Scope.contains(b)
local only = Insights.allTime()
Kit.ok(in_scope and Scope.contains(a) == (a:sub(1, #parent + 1) == parent .. "/"), "the scope knows which books it holds")
Kit.ok(only.seconds == 6000 or only.seconds == all_time.seconds, "a scope counts only the books of its folders (" .. only.seconds .. ")")
Scope.set({})
Kit.ok(Insights.allTime().seconds == all_time.seconds, "and no scope counts them all again")

Kit.finish("stats")
