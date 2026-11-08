-- What the reader saved in a book: highlights, notes and bookmarks, read from
-- the book's reading data. A highlight is a marked passage, a note is any
-- saved item with a note written on it (a highlight can have one), a bookmark
-- is a saved place with no marked text.

local Books = require("cyberui/data/books")
local util = require("util")

local Annotations = {}

-- The saved items of a book, oldest first: { text, note, chapter, date, page, pos0, highlight }.
function Annotations.all(path)
    if not Books.state(path).opened then return {} end
    local ok, ds = pcall(function() return require("docsettings"):open(path) end)
    local out = {}
    for _i, a in ipairs(ok and ds:readSetting("annotations") or {}) do
        out[#out + 1] = {
            text = a.text and util.trim((a.text:gsub("%s+", " "))) or "",
            note = a.note and a.note ~= "" and a.note or nil,
            chapter = a.chapter, date = a.datetime, page = a.page, pos0 = a.pos0, pageno = a.pageno,
            highlight = a.drawer ~= nil,
        }
    end
    return out
end

-- The three kinds of a book's saved items: { highlights, notes, bookmarks }.
function Annotations.kinds(path)
    local kinds = { highlights = {}, notes = {}, bookmarks = {} }
    for _i, a in ipairs(Annotations.all(path)) do
        if a.highlight then kinds.highlights[#kinds.highlights + 1] = a else kinds.bookmarks[#kinds.bookmarks + 1] = a end
        if a.note then kinds.notes[#kinds.notes + 1] = a end
    end
    return kinds
end

return Annotations
