-- The drop-down menu inside a book has the Deck tab too, and its Annotate
-- tile opens the annotation mode of the book being read.
local H = ...
H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(3, function() require("apps/reader/readerui").instance.menu:onShowMenu() end)
H.step(1.5, function()
    local m = require("cyberui/menu").current()
    H.check(m ~= nil and m.reader, "reader menu is open")
    H.check(m.tabs[1].deck == true, "the Deck is its first tab")
    m:switchTab(1)
    m.deck_page = 2
    m:show()
end)
H.step(1.2, function()
    H.shot("reader-deck")
    H.tapAt(220, 645)   -- the Annotate tile (the menu is a popup of its own, not in home's tree)
end)
H.step(2.5, function()
    local ui = require("apps/reader/readerui").instance
    local ia = ui and ui["ink-away"]
    H.check(ia and ia.book and ia.book._view ~= nil, "annotation mode is open on the book being read")
end)
