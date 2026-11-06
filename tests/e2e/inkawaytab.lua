-- Ink Away's pen tab in CyberUI's menu opens its quick menu as a CyberUI sheet,
-- over home and over a book (needs Ink Away installed next to CyberUI).
local H = ...

-- Tap the pen tab of the open CyberUI menu.
local function tapTab()
    local m = require("cyberui/menu").current()
    for i, t in ipairs(m.tabs) do
        if t.icon == "inkaway.tab" then return m:switchTab(i) end
    end
    H.check(false, "the menu has Ink Away's tab")
end

H.step(2, function() require("cyberui/menu").open({}) end)
H.step(1.5, tapTab)
H.step(1.5, function()
    H.shot("home-sheet")
    H.check(require("cyberui/app").overlay() ~= nil, "the quick menu is a CyberUI sheet over home")
end)
H.step(1, function() require("cyberui/app").closeDialog() end)
H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(4, function() require("apps/reader/readerui").instance.menu:onShowMenu() end)
H.step(2, tapTab)
H.step(2, function()
    H.shot("book-sheet")
    local found = false
    for _i, w in ipairs(require("ui/uimanager")._window_stack) do
        if w.widget and w.widget.name == "cyberui_popup" then found = true end
    end
    H.check(found, "the quick menu is a CyberUI popup over the book")
end)
