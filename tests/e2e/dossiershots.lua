-- The book's details page for the three kinds of book: never opened (to be read), in progress, and a gig on the board.
-- A long description is given to each so the room it gets can be seen. Photographs only (run before and after a layout change).
local H = ...
local Books = require("cyberui/data/books")
local Library = require("cyberui/data/library")
local Settings = require("cyberui/settings")
local Gigs = require("cyberui/data/gigs")
local lfs = require("libs/libkoreader-lfs")
local DESCRIPTION = "A fortunate discovery made by accident while looking for something quite different. The story follows a young archivist "
    .. "who finds a letter hidden inside a library book and sets out across three countries to learn who wrote it and why it was never sent. "
    .. "Along the way she meets a retired cartographer, a family of bell makers and a translator who has spent forty years on one poem. "
    .. "Praised for its patience and its warmth, it is a novel about reading as a way of being found by other people, and about how "
    .. "little it takes for a stranger's words to change the shape of a life. Winner of two national prizes."
local orig = Books.info
local given = {}
Books.info = function(path)
    local info = orig(path)
    if given[path] then
        info = setmetatable({ description = DESCRIPTION, series = "The Wise Cycle", series_index = 2, authors = "An Author\nA Translator", author = "An Author",
            genres = { "Fantasy", "Adventure" }, language = "en" }, { __index = info })
    end
    return info
end
local unread, reading, gig
H.step(2, function()
    local all = Library.all()
    local epubs = {}
    for _i, p in ipairs(all) do if p:match("%.epub$") then epubs[#epubs + 1] = p end end
    table.sort(epubs)
    unread, reading, gig = epubs[1], epubs[2], epubs[3]
    for _i, p in ipairs({ unread, reading, gig }) do given[p] = true end
    lfs.touch(gig, os.time() - 60 * 86400, os.time() - 60 * 86400)
    Settings.set("gigs", { quotes = {}, seen = {}, ledger = {}, board = { t = os.time(), slots = { gig } } })
    Gigs.reload()
    -- the second book is half read
    local DocSettings = require("docsettings")
    local ds = DocSettings:open(reading)
    ds:saveSetting("percent_finished", 0.42)
    ds:saveSetting("summary", { status = "reading" })
    ds:flush()
    Books.forget(reading)
    H.app().push("dossier", { path = unread })
end)
H.step(1.5, function() H.shot("1-unread") end)
H.step(0.5, function() H.app().back(); H.app().push("dossier", { path = reading }) end)
H.step(1.5, function() H.shot("2-reading") end)
H.step(0.5, function() H.app().back(); H.app().push("dossier", { path = gig }) end)
H.step(1.5, function() H.shot("3-gig") end)
H.step(0.5, function() H.tap("MORE") end)
H.step(1.2, function() H.shot("4-more-sheet") end)
