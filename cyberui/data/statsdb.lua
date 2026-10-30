-- Access to KOReader's statistics database (read only): running a query, the
-- scope filter and a cache that lasts until a book is read. Everything that
-- reads statistics goes through here.

local DataStorage = require("datastorage")
local Scope = require("cyberui/data/statsscope")
local lfs = require("libs/libkoreader-lfs")

local Statsdb = {}

local cache = {}

-- Run fn(conn) on an open connection; nil when there is no database.
function Statsdb.query(fn)
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
function Statsdb.rows(conn, sql)
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

-- " AND <column> IN (...)" limiting a query to the scope's books, or "".
function Statsdb.scoped(conn, column)
    local ids = Scope.ids(Statsdb.rows(conn, "SELECT id, title, md5 FROM book"))
    return ids and string.format(" AND %s IN (%s)", column or "id_book", ids) or ""
end

-- Remember a value (for the current scope) until the next invalidate().
function Statsdb.cached(key, fn)
    key = Scope.key() .. "#" .. key
    if cache[key] == nil then cache[key] = fn() or false end
    return cache[key] or nil
end

-- Forget cached results (a book was read, or the scope changed).
function Statsdb.invalidate()
    cache = {}
end

-- Midnight (local time) `days` days before today.
function Statsdb.midnight(days)
    local t = os.date("*t")
    t.hour, t.min, t.sec = 0, 0, 0
    return os.time(t) - days * 86400
end

return Statsdb
