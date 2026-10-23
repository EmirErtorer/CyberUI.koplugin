-- The book files on the device: one folder's books and subfolders, a whole
-- library index for counts and search, sorting and filtering by reading state.
-- Folder listings are cached until the folder changes on disk.

local lfs = require("libs/libkoreader-lfs")
local Books = require("cyberui/data/books")
local History = require("cyberui/data/history")
local filemanagerutil = require("apps/filemanager/filemanagerutil")

local Library = {}

local listings = {}   -- dir -> { mtime, folders, books }
local index           -- { books = {paths}, built = time } for the whole library

local MAX_DEPTH = 8

-- The library's top folder (KOReader's home folder).
function Library.home()
    return filemanagerutil.getHomeFolder()
end

-- Books and subfolders directly inside `dir`, names sorted.
function Library.list(dir)
    local mtime = lfs.attributes(dir, "modification")
    local cached = listings[dir]
    if cached and cached.mtime == mtime then return cached end
    local folders, books = {}, {}
    local ok, iter, state = pcall(lfs.dir, dir)
    if ok then
        for name in iter, state do
            if name:sub(1, 1) ~= "." and not name:match("%.sdr$") then
                local path = dir .. "/" .. name
                local mode = lfs.attributes(path, "mode")
                if mode == "directory" then
                    folders[#folders + 1] = { path = path, name = name }
                elseif mode == "file" and Books.isBook(path) then
                    books[#books + 1] = path
                end
            end
        end
    end
    table.sort(folders, function(a, b) return a.name:lower() < b.name:lower() end)
    table.sort(books, function(a, b) return a:lower() < b:lower() end)
    cached = { mtime = mtime, folders = folders, books = books }
    listings[dir] = cached
    return cached
end

-- Every book under the home folder (walked once, then cached until reset).
function Library.all()
    if index then return index.books end
    local books = {}
    local function walk(dir, depth)
        local l = Library.list(dir)
        for _i, b in ipairs(l.books) do books[#books + 1] = b end
        if depth < MAX_DEPTH then
            for _i, f in ipairs(l.folders) do walk(f.path, depth + 1) end
        end
    end
    walk(Library.home(), 0)
    index = { books = books, built = os.time() }
    return books
end

-- Number of books in the library, or nil before the index is built.
function Library.count()
    return index and #index.books or nil
end

-- Forget cached listings so the next look reads the disk again.
function Library.reset()
    listings = {}
    index = nil
end

-- Sort keys for each sort order.
local SORTS = {
    recent = function(p) return -(History.lastOpened(p) or 0), -(lfs.attributes(p, "modification") or 0) end,
    title = function(p) return Books.info(p).title:lower(), 0 end,
    author = function(p) return (Books.info(p).author or "~"):lower(), 0 end,
    added = function(p) return -(lfs.attributes(p, "modification") or 0), 0 end,
}
Library.SORTS = { "recent", "title", "author", "added" }

-- A sorted copy of `books` ("recent", "title", "author" or "added").
function Library.sort(books, order)
    local key = SORTS[order] or SORTS.recent
    local keyed = {}
    for i, p in ipairs(books) do
        local a, b = key(p)
        keyed[i] = { p = p, a = a, b = b }
    end
    table.sort(keyed, function(x, y)
        if x.a ~= y.a then return x.a < y.a end
        if x.b ~= y.b then return x.b < y.b end
        return x.p < y.p
    end)
    local out = {}
    for i, k in ipairs(keyed) do out[i] = k.p end
    return out
end

-- Reading-state filters: which statuses each one keeps.
local FILTERS = {
    all = nil,
    reading = { reading = true },
    unread = { new = true },
    done = { complete = true },
}
Library.FILTERS = { "all", "reading", "unread", "done" }

-- The books matching a filter, and how many books each filter keeps.
function Library.filter(books, filter)
    local counts = { all = #books, reading = 0, unread = 0, done = 0 }
    local keep = FILTERS[filter]
    local out = {}
    for _i, p in ipairs(books) do
        local status = Books.state(p).status
        if status == "reading" then counts.reading = counts.reading + 1
        elseif status == "new" then counts.unread = counts.unread + 1
        elseif status == "complete" then counts.done = counts.done + 1 end
        if not keep or keep[status] then out[#out + 1] = p end
    end
    return out, counts
end

-- Books whose title, author or file name contain every word of `query`.
function Library.search(query)
    local words = {}
    for w in query:lower():gmatch("%S+") do words[#words + 1] = w end
    if #words == 0 then return {} end
    local out = {}
    for _i, p in ipairs(Library.all()) do
        local info = Books.info(p)
        local hay = (info.title .. " " .. (info.authors or "") .. " " .. (info.series or "") .. " " .. p):lower()
        local all = true
        for _j, w in ipairs(words) do
            if not hay:find(w, 1, true) then all = false; break end
        end
        if all then out[#out + 1] = p end
    end
    return out
end

return Library
