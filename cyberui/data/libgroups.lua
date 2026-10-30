-- Ways to see the library beyond its folders: books grouped by author,
-- series, status, format or when they were added (each group acts as a
-- virtual folder), and the extra filters (format, collection, with notes).

local Books = require("cyberui/data/books")
local Collections = require("cyberui/data/collections")
local Library = require("cyberui/data/library")
local lfs = require("libs/libkoreader-lfs")
local _ = require("cyberui/gettext")

local Groups = {}

-- The groupings: id and name. "folder" is the real folders, "all" no grouping.
Groups.KINDS = {
    { "folder", _("Folders") }, { "all", _("All books") }, { "author", _("Author") }, { "series", _("Series") },
    { "status", _("Status") }, { "format", _("Format") }, { "added", _("Added") },
}

local STATUS_NAMES = { new = _("Unread"), reading = _("Reading"), abandoned = _("On hold"), complete = _("Done") }

-- A book's file extension in capitals.
local function format(path)
    return (path:match("%.([^.]+)$") or "?"):upper()
end
Groups.format = format

-- The key and shown name of the group a book is in for a grouping.
local function keyOf(kind, path)
    if kind == "author" then
        local a = Books.info(path).author
        return a or "~", a or _("Unknown author")
    elseif kind == "series" then
        local s = Books.info(path).series
        return s or "~", s or _("No series")
    elseif kind == "status" then
        local s = Books.state(path).status
        return s, STATUS_NAMES[s] or s
    elseif kind == "format" then
        local f = format(path)
        return f, f
    end
    local y = os.date("%Y-%m", lfs.attributes(path, "modification") or 0)   -- added
    return y, os.date("%B %Y", lfs.attributes(path, "modification") or 0)
end

-- The groups of the whole library for a grouping: { key, name, count, first }
-- sorted by name (most recent first for "added").
function Groups.list(kind)
    local by_key, out = {}, {}
    for _i, p in ipairs(Library.all()) do
        local key, name = keyOf(kind, p)
        local g = by_key[key]
        if not g then
            g = { key = key, name = name, count = 0, first = p }
            by_key[key] = g
            out[#out + 1] = g
        end
        g.count = g.count + 1
    end
    table.sort(out, function(a, b)
        if kind == "added" then return a.key > b.key end
        return a.key:lower() < b.key:lower()
    end)
    return out
end

-- The books of one group.
function Groups.books(kind, key)
    local out = {}
    for _i, p in ipairs(Library.all()) do
        if (keyOf(kind, p)) == key then out[#out + 1] = p end
    end
    return out
end

-- The formats found in the library, sorted.
function Groups.formats()
    local seen, out = {}, {}
    for _i, p in ipairs(Library.all()) do
        local f = format(p)
        if not seen[f] then seen[f] = true; out[#out + 1] = f end
    end
    table.sort(out)
    return out
end

-- Does the reader's extra filtering have anything set?
function Groups.filtering(f)
    return f ~= nil and (f.format ~= nil or f.collection ~= nil or f.annotated == true)
end

-- The books that pass the extra filters f = { format, collection, annotated }.
function Groups.filter(books, f)
    if not Groups.filtering(f) then return books end
    local out = {}
    for _i, p in ipairs(books) do
        if (not f.format or format(p) == f.format)
            and (not f.collection or Collections.has(p, f.collection))
            and (not f.annotated or Books.state(p).annotated) then
            out[#out + 1] = p
        end
    end
    return out
end

return Groups
