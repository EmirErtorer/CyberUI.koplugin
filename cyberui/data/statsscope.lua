-- Which books the reading statistics count: all of them, or only those in
-- chosen folders. KOReader's statistics database keeps no file paths, so the
-- books of the folders are matched to its rows by their partial md5 (kept in
-- each book's sidecar), or by title when a book has none.

local Library = require("cyberui/data/library")
local Settings = require("cyberui/settings")

local Scope = {}

local resolved   -- { key, ids }: the ids for the folders and index they were worked out for

-- The folders counted, or an empty list for all books.
function Scope.folders()
    return Settings.get("stats_scope", {})
end

-- Are only some folders counted?
function Scope.active()
    return #Scope.folders() > 0
end

-- Count only these folders (an empty list: all books).
function Scope.set(folders)
    Settings.save("stats_scope", folders)
    resolved = nil
end

-- A short name for the scope, for a cache key.
function Scope.key()
    return table.concat(Scope.folders(), "|")
end

-- Is the book in the scope (always, when every book counts)?
function Scope.contains(path)
    if not Scope.active() then return true end
    for _i, f in ipairs(Scope.folders()) do
        if path:sub(1, #f + 1) == f .. "/" then return true end
    end
    return false
end

-- The books of the scope folders, from the library index.
local function paths()
    local out = {}
    for _i, p in ipairs(Library.all()) do
        if Scope.contains(p) then out[#out + 1] = p end
    end
    return out
end

-- The md5 of a book's sidecar, or nil.
local function md5Of(path)
    local ok, ds = pcall(function() return require("docsettings"):open(path) end)
    return ok and ds and ds:readSetting("partial_md5_checksum") or nil
end

-- SQL list of the statistics book ids in the scope ("1,2,3"), or nil for all
-- books. A scope with no matching book gives "-1", which matches nothing.
function Scope.ids(rows_of_books)
    if not Scope.active() then return nil end
    local key = Scope.key() .. "#" .. tostring(Library.count())
    if resolved and resolved.key == key then return resolved.ids end
    local by_md5, by_title = {}, {}
    for _i, p in ipairs(paths()) do
        local md5 = md5Of(p)
        if md5 then by_md5[md5] = true end
        by_title[require("cyberui/data/books").info(p).title:lower()] = true
    end
    local ids = {}
    for _i, r in ipairs(rows_of_books) do
        if (r[3] and by_md5[r[3]]) or (r[2] and by_title[tostring(r[2]):lower()]) then ids[#ids + 1] = string.format("%d", tonumber(r[1])) end
    end
    resolved = { key = key, ids = #ids > 0 and table.concat(ids, ",") or "-1" }
    return resolved.ids
end

return Scope
