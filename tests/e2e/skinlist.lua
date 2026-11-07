-- KOReader's lists (Menu) in CyberUI's style: a plain list over home, and the table of contents in a book. Items, taps,
-- holds, paging and closing stay KOReader's.
local H = ...
local UIManager = require("ui/uimanager")
local S = 1.5
local ran = {}

local menu, container
H.step(S, function()
    local Menu = require("ui/widget/menu")
    local Screen = require("device").screen
    local items = {}
    for i = 1, 45 do
        items[i] = { text = "Chapter " .. i .. ": a title that goes on a while", mandatory = tostring(i * 7),
            callback = function() ran.chosen = i end, indent = (i % 3 == 0) and 30 or 0 }
    end
    items[2].dim = true
    items[3].sub_item_table = { { text = "Inside", callback = function() ran.inside = true end } }
    items.current = 5
    container = require("ui/widget/container/centercontainer"):new({ dimen = Screen:getSize(), covers_fullscreen = true })
    menu = Menu:new({ title = "Contents", item_table = items, is_borderless = true, is_popout = false, covers_fullscreen = true,
        show_parent = container, close_callback = function() ran.closed = true end,
        onMenuHold = function(_, item) ran.held = item.text end })
    container[1] = menu
    UIManager:show(container)
end)
H.step(S, function()
    H.check(container._cyber_popup ~= nil, "the list is drawn by CyberUI")
    H.check(H.find("Contents") ~= nil and H.find("Chapter 5: a title that goes on a while") ~= nil, "it shows its title and items")
    H.shot("1-list")
    H.tap("Chapter 5: a title that goes on a while")
end)
H.step(S, function()
    H.check(ran.chosen == 5, "a tap runs KOReader's item callback")
    H.hold("Chapter 6: a title that goes on a while")
end)
H.step(S, function()
    H.check(ran.held == "Chapter 6: a title that goes on a while", "a hold runs KOReader's hold handler")
    H.tap(">")
end)
H.step(S, function()
    H.check(H.find("Chapter 5: a title that goes on a while") == nil, "the pager turns the page")
    H.shot("2-list-page2")
    H.tap("<")
end)
H.step(S, function()
    local el = H.findWhere(function(e) return type(e.text) == "string" and e.text:find("^Chapter 3") end)
    if el then H.tapAt(el.x + el.w / 2, el.y + el.h / 2) else H.check(false, "found chapter 3") end
end)
H.step(S, function()
    H.check(H.find("Inside") ~= nil, "an item with a sub-list opens it, through KOReader")
    H.shot("3-sublist")
    H.tap("Inside")
end)
H.step(S, function()
    H.check(ran.inside, "and its item runs")
    UIManager:close(container)
end)
H.step(S, function()
    H.check(container._cyber_popup == nil, "closing KOReader's list closes the popup")
end)

-- the table of contents in a book
H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(5, function()
    local ui = require("apps/reader/readerui").instance
    ui.toc:onShowToc()
end)
H.step(S, function()
    H.shot("4-toc")
    local toc
    for _i, e in ipairs(UIManager._window_stack) do if e.widget._cyber_popup and e.widget.name ~= "cyberui_popup" then toc = e.widget end end
    H.check(toc ~= nil, "the table of contents is drawn by CyberUI")
    if toc then UIManager:close(toc) end
end)
