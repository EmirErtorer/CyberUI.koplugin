-- KOReader's collections: listing them with their books, adding and removing
-- books and making new ones.

local ReadCollection = require("readcollection")
local _ = require("gettext")

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
    for _, item in pairs(ReadCollection.coll[name] or {}) do items[#items + 1] = item end
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

return Collections
