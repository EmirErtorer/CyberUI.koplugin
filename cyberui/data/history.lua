-- KOReader's reading history: the books opened most recently and when.

local ReadHistory = require("readhistory")
local lfs = require("libs/libkoreader-lfs")

local History = {}

-- The `n` most recently opened books that still exist: { path, time }.
function History.recent(n)
    local out = {}
    for _i, item in ipairs(ReadHistory.hist or {}) do
        if #out >= n then break end
        if item.file and lfs.attributes(item.file, "mode") == "file" then
            out[#out + 1] = { path = item.file, time = item.time }
        end
    end
    return out
end

-- The file of the book opened last, or nil.
function History.lastFile()
    local last = History.current()
    return last and last.path
end

-- The book being read now: the last one opened, or nil.
function History.current()
    local r = History.recent(1)
    return r[1]
end

-- A string that changes whenever the history does (a book opened, one
-- removed, the history read again).
function History.stamp()
    local hist = ReadHistory.hist or {}
    local top = hist[1]
    return tostring(hist) .. "#" .. #hist .. "#" .. tostring(top and top.file) .. "#" .. tostring(top and top.time)
end

local opened, opened_stamp   -- file -> time it was last opened, for the history as of opened_stamp

-- When each book in the history was last opened: file -> seconds. (Made
-- once per change of the history: sorting a big folder asks for every book.)
function History.openedMap()
    local stamp = History.stamp()
    if opened_stamp ~= stamp then
        opened, opened_stamp = {}, stamp
        for _i, item in ipairs(ReadHistory.hist or {}) do
            if item.file and not opened[item.file] then opened[item.file] = item.time end
        end
    end
    return opened
end

-- When `path` was last opened (seconds), or nil.
function History.lastOpened(path)
    return History.openedMap()[path]
end

return History
