-- KOReader's collections: listing them with their books, adding and removing
-- books and making new ones.

local ReadCollection = require("readcollection")
local Settings = require("cyberui/settings")
local _ = require("cyberui/gettext")

local Collections = {}

-- The name shown for a collection (the built-in one is "Favorites").
function Collections.title(name)
    if name == ReadCollection.default_collection_name then return _("Favorites") end
    return name
end

-- The books of one collection in its order (sorted collections have no order,
-- so their books go by file name).
function Collections.books(name)
    local items = {}
    for _i, item in pairs(ReadCollection.coll[name] or {}) do items[#items + 1] = item end
    table.sort(items, function(a, b)
        local oa, ob = a.order or math.huge, b.order or math.huge
        if oa ~= ob then return oa < ob end
        return a.file < b.file
    end)
    local books = {}
    for i, item in ipairs(items) do books[i] = item.file end
    return books
end

-- Every collection: { name, title, books (in collection order) }, favorites first.
function Collections.list()
    local out = {}
    for name in pairs(ReadCollection.coll or {}) do
        out[#out + 1] = { name = name, title = Collections.title(name), books = Collections.books(name) }
    end
    local fav = ReadCollection.default_collection_name
    table.sort(out, function(a, b)
        if (a.name == fav) ~= (b.name == fav) then return a.name == fav end
        return a.title:lower() < b.title:lower()
    end)
    return out
end

-- Names of the collections that hold `path`.
function Collections.holding(path)
    local out = {}
    for name in pairs(ReadCollection:getCollectionsWithFile(path) or {}) do out[#out + 1] = name end
    table.sort(out)
    return out
end

-- Is `path` in collection `name`?
function Collections.has(path, name)
    return ReadCollection:isFileInCollection(path, name)
end

-- Put a book in a collection or take it out.
function Collections.toggle(path, name)
    if ReadCollection:isFileInCollection(path, name) then
        ReadCollection:removeItem(path, name)
    else
        ReadCollection:addItem(path, name)
        ReadCollection:write({ [name] = true })
    end
end

-- Make a new, empty collection.
function Collections.create(name)
    if not ReadCollection.coll[name] then
        ReadCollection:addCollection(name)
        ReadCollection:write({ [name] = true })
    end
end

-- The library's saved filter and saved views name collections: they follow a
-- renamed one.
local function followRename(old, new)
    local extra = Settings.get("library_extra")
    if extra and extra.collection == old then extra.collection = new; Settings.set("library_extra", extra) end
    for _i, view in ipairs(Settings.get("library_views", {})) do
        if view.extra and view.extra.collection == old then view.extra.collection = new end
    end
    Settings.set("library_views", Settings.get("library_views", {}))
    Settings.flush()
end

-- Rename a collection. Returns true, or false and why ("empty", "same",
-- "exists", "favorites", "missing") when it was not renamed.
function Collections.rename(old, new)
    new = (new or ""):match("^%s*(.-)%s*$")
    if old == ReadCollection.default_collection_name then return false, "favorites" end
    if not ReadCollection.coll[old] then return false, "missing" end
    if new == "" then return false, "empty" end
    if new == old then return false, "same" end
    if ReadCollection.coll[new] then return false, "exists" end
    ReadCollection:renameCollection(old, new)
    ReadCollection:write({ [new] = true })   -- the old name is dropped from the file by write
    followRename(old, new)
    return true
end

-- Delete a collection (its books stay in the library). Favorites cannot go.
function Collections.remove(name)
    if name == ReadCollection.default_collection_name or not ReadCollection.coll[name] then return false end
    ReadCollection:removeCollection(name)
    ReadCollection:write()
    return true
end

return Collections
