-- Facts about book files: title, authors, series and description from
-- CoverBrowser's cache, reading state from KOReader's book list cache. Books
-- the cache has not seen are read in the background and reported when done.

local BookList = require("ui/widget/booklist")
local DocumentRegistry = require("document/documentregistry")
local UIManager = require("ui/uimanager")
local util = require("util")

local Books = {}

-- Counts the times a book's facts were dropped, so a cache of results built
-- from them can tell it is out of date.
Books.revision = 0

local info_cache = {}     -- path -> facts
local waiting = {}        -- path -> true while queued for extraction
local on_extracted = {}   -- callbacks for when background extraction ends
local polling = false

-- CoverBrowser's book info cache, or nil when that plugin is off.
local function bim()
    local ok, m = pcall(require, "bookinfomanager")
    return ok and m or nil
end

-- Is this file something KOReader can open?
function Books.isBook(path)
    return DocumentRegistry:hasProvider(path) and true or false
end

-- A title made from the file name, for books not read yet.
local function fileTitle(path)
    local _dir, name = util.splitFilePathName(path)
    return (name:gsub("%.[^.]+$", ""):gsub("[_]+", " "))
end

-- First author from CoverBrowser's newline separated list.
local function firstAuthor(authors)
    if not authors or authors == "" then return nil end
    return authors:match("^[^\n]+")
end

-- Title, author, series, pages and description of a book.
function Books.info(path)
    local info = info_cache[path]
    if info then return info end
    local m = bim()
    local bi = m and m:getBookInfo(path, false)
    if bi and bi.has_meta then
        info = {
            path = path,
            title = (bi.title and bi.title ~= "") and bi.title or fileTitle(path),
            author = firstAuthor(bi.authors),
            authors = bi.authors,
            series = bi.series,
            series_index = bi.series_index,
            pages = bi.pages,
            description = bi.description,
            language = bi.language,
            known = true,
        }
    else
        info = { path = path, title = fileTitle(path), known = bi ~= nil }
        if not bi and m then Books.queue(path) end
    end
    info_cache[path] = info
    return info
end

-- Reading state: { status, percent, pages, opened, annotated }. Status is
-- "new", "reading", "complete" or "abandoned". "new" is a book never opened or
-- one the reader marked unread (KOReader sets reading again when it is opened).
function Books.state(path)
    local bi = BookList.getBookInfo(path)
    if not bi.been_opened or bi.status == "new" then return { status = "new", percent = 0, opened = bi.been_opened or false } end
    local status = bi.status or "reading"
    local percent = bi.percent_finished or 0
    if status == "complete" then percent = 1 end
    return { status = status, percent = percent, pages = bi.pages, opened = true, annotated = bi.has_annotations }
end

-- The small badge for a book's tile: text and whether it stands out.
function Books.badge(path)
    local st = Books.state(path)
    if st.status == "new" then return "NEW", true end
    if st.status == "complete" then return "DONE", false end
    if st.status == "abandoned" then return "HOLD", false end
    return string.format("%d%%", math.floor(st.percent * 100 + 0.5)), false
end

-- Forget what is known about a book (it was just read, moved or changed).
function Books.forget(path)
    Books.revision = Books.revision + 1
    info_cache[path] = nil
    BookList.resetBookInfoCache(path)
end

-- Check every second whether background extraction has ended.
local function poll()
    local m = bim()
    if m and m:isExtractingInBackground() then
        UIManager:scheduleIn(1, poll)
        return
    end
    polling = false
    local done = {}
    for path in pairs(waiting) do
        info_cache[path] = nil
        done[#done + 1] = path
    end
    waiting = {}
    local callbacks = on_extracted
    on_extracted = {}
    for _i, fn in ipairs(callbacks) do fn(done) end
end

-- Ask CoverBrowser to read a book's details in the background (batched to
-- the next tick so a whole screen's books go together).
function Books.queue(path)
    if waiting[path] then return end
    waiting[path] = true
    if polling then return end
    polling = true
    UIManager:nextTick(function()
        local m = bim()
        if not m then polling = false; return end
        local files = {}
        for p in pairs(waiting) do
            files[#files + 1] = { filepath = p, cover_specs = { max_cover_w = 600, max_cover_h = 900 } }
        end
        m:extractInBackground(files)
        UIManager:scheduleIn(1, poll)
    end)
end

-- Call fn(paths) once the books queued now have been read.
function Books.whenExtracted(fn)
    if next(waiting) then on_extracted[#on_extracted + 1] = fn end
end

return Books
