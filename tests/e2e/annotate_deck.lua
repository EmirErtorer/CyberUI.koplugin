-- The Deck's Controls page has an Annotate tile (Ink Away installed); with
-- the last book read it opens that book in annotation mode.
local H = ...
H.step(1, function()
    local book = require("cyberui/data/library").all()[1]
    H.app().openBook(book)
end)
H.step(3, function()
    local ui = require("apps/reader/readerui").instance
    ui:handleEvent(require("ui/event"):new("CyberUIHome"))
end)
H.step(3, function()
    H.check(H.cyberTop(), "home with the book put away")
    H.app().koreaderMenu()
end)
H.step(4, function()
    local m = require("cyberui/menu").current()
    m:switchTab(1)
    m.deck_page = 2
    m:show()
end)
H.step(1.2, function()
    H.check(H.find("Annotate") ~= nil, "Annotate tile on the Controls page")
    H.check(H.find("Restart") ~= nil, "Restart still there")
    H.shot("deck")
    H.tap("Annotate")
end)
H.step(3, function()
    H.check(not H.cyberTop(), "the book is back")
    local ui = require("apps/reader/readerui").instance
    local ia = ui and ui["ink-away"]
    H.check(ia and ia.book and ia.book._view ~= nil, "annotation mode is open")
    H.shot("annotating")
end)
