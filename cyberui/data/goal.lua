-- The reading goal: books finished in a year against a target the reader
-- sets, and the list of what was finished (with the date KOReader saved when
-- a book was marked done). Respects the statistics scope.

local Books = require("cyberui/data/books")
local Library = require("cyberui/data/library")
local Scope = require("cyberui/data/statsscope")
local Settings = require("cyberui/settings")
local Statsdb = require("cyberui/data/statsdb")

local Goal = {}

-- Books to finish in a year.
function Goal.target()
    return Settings.get("year_goal", 12)
end

-- Set the yearly target.
function Goal.setTarget(n)
    Settings.save("year_goal", math.max(1, math.min(n, 999)))
end

-- The date ("YYYY-MM-DD") a book was finished, or nil.
local function finishedOn(path)
    local ok, ds = pcall(function() return require("docsettings"):open(path) end)
    local summary = ok and ds and ds:readSetting("summary") or nil
    return summary and summary.modified or nil
end

-- Every finished book in the scope: { path, date } (date may be nil), the
-- most recently finished first.
function Goal.finished()
    return Statsdb.cached("finished", function()
        local out = {}
        for _i, p in ipairs(Library.all()) do
            if Scope.contains(p) and Books.state(p).status == "complete" then
                out[#out + 1] = { path = p, date = finishedOn(p) }
            end
        end
        table.sort(out, function(a, b) return (a.date or "") > (b.date or "") end)
        return out
    end) or {}
end

-- The books finished in `year`, the earliest first.
function Goal.finishedIn(year)
    local out = {}
    local prefix = tostring(year) .. "-"
    for _i, b in ipairs(Goal.finished()) do
        if b.date and b.date:sub(1, #prefix) == prefix then table.insert(out, 1, b) end
    end
    return out
end

return Goal
