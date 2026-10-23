-- KOReader's reading history: the books opened most recently and when.

local ReadHistory = require("readhistory")
local lfs = require("libs/libkoreader-lfs")

local History = {}

-- The `n` most recently opened books that still exist: { path, time }.
function History.recent(n)
    local out = {}
    for _, item in ipairs(ReadHistory.hist or {}) do
        if #out >= n then break end
        if item.file and lfs.attributes(item.file, "mode") == "file" then
            out[#out + 1] = { path = item.file, time = item.time }
        end
    end
    return out
end

-- The book being read now: the last one opened, or nil.
function History.current()
    local r = History.recent(1)
    return r[1]
end

-- When `path` was last opened (seconds), or nil.
function History.lastOpened(path)
    local i = ReadHistory:getIndexByFile(path)
    return i and ReadHistory.hist[i].time or nil
end

return History
