-- The saved highlights, notes and bookmarks of a book: three buttons on its details page show the counts and open their lists,
-- each a CyberUI page of cards; a tap on a card opens the book at that place; a book with none says so.
local H = ...
local Library = require("cyberui/data/library")
local Actions = require("cyberui/actions")
local S = 1.4
local book, other, opened_at

H.step(2, function()
    local epubs = {}
    for _i, p in ipairs(Library.all()) do if p:match("%.epub$") then epubs[#epubs + 1] = p end end
    table.sort(epubs)
    book, other = epubs[1], epubs[2]
    local DocSettings = require("docsettings")
    local ds = DocSettings:open(book)
    ds:saveSetting("percent_finished", 0.3)
    ds:saveSetting("summary", { status = "reading" })
    ds:saveSetting("annotations", {
        { text = "The first marked passage, long enough to need a couple of lines on the card so that the layout is seen.", drawer = "lighten", chapter = "Chapter One",
            pageno = 12, datetime = "2026-11-01 21:14:05", page = 12, pos0 = "p0" },
        { text = "A second marked passage with a note on it.", note = "Remember this for the essay.", drawer = "lighten", chapter = "Chapter Two", pageno = 40,
            datetime = "2026-11-03 08:02:11", page = 40 },
        { text = "A third.", note = "Check the date.", drawer = "underscore", chapter = "Chapter Two", pageno = 44, datetime = "2026-11-03 08:20:00", page = 44 },
        { text = "Page 51 Chapter Three", chapter = "Chapter Three", pageno = 51, datetime = "2026-11-05 19:00:00", page = 51 },
    })
    ds:flush()
    require("cyberui/data/books").forget(book)
    Actions.openAt = function(path, a) opened_at = { path = path, page = a.page } end
    H.app().push("dossier", { path = book })
end)
H.step(S, function()
    H.shot("1-dossier-strip")
    H.check(H.find("03") ~= nil and H.find("02") ~= nil and H.find("01") ~= nil, "the strip shows 3 highlights, 2 notes and 1 bookmark")
    H.tap("HIGHLIGHTS")
end)
H.step(S, function()
    H.check(H.app().current().id == "annotations" and H.find("HIGHLIGHTS") ~= nil, "the highlights button opens the highlights list")
    H.shot("2-highlights")
    H.tap("A third.")
end)
H.step(S, function()
    H.check(opened_at ~= nil and opened_at.page == 44, "a tap on a card opens the book at that place")
    H.app().back()
end)
H.step(S, function() H.tap("NOTES") end)
H.step(S, function()
    H.check(H.find("Remember this for the essay.") ~= nil, "the notes list shows the notes")
    H.shot("3-notes")
    H.app().back()
end)
H.step(S, function() H.tap("BOOKMARKS") end)
H.step(S, function()
    H.check(H.find("// 2026-11-05") == nil, "(meta lines are one label)")
    H.shot("4-bookmarks")
    H.app().back()
    H.app().back()
    H.app().push("dossier", { path = other })
end)
H.step(S, function()
    H.tap("NOTES")
end)
H.step(S, function()
    H.check(H.find("No notes in this book yet. Add a note to a highlight while reading.") ~= nil, "a book with none says so")
    H.shot("5-empty")
end)
