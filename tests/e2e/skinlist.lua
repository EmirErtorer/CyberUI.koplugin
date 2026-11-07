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

-- a list that opens and closes, as the table of contents does: the mark on a row toggles it through KOReader, the title chooses it
local tree, tree_container, expanded
H.step(S, function()
    local Menu = require("ui/widget/menu")
    local Screen = require("device").screen
    local function build()
        local items = {}
        local function add(text, depth, parent)
            local item = { text = text, indent = depth * 20, mandatory = "1" }
            if parent then
                item.state = require("ui/widget/button"):new({ icon = expanded and "control.collapse" or "control.expand", bordersize = 0,
                    callback = function()
                        expanded = not expanded
                        tree:switchItemTable(nil, build())
                    end })
            end
            items[#items + 1] = item
        end
        add("Part one", 0, true)
        if expanded then add("Chapter 1.1", 1) add("Chapter 1.2", 1) end
        add("Part two", 0, false)
        return items
    end
    tree_container = require("ui/widget/container/centercontainer"):new({ dimen = Screen:getSize(), covers_fullscreen = true })
    tree = Menu:new({ title = "Tree", item_table = build(), is_borderless = true, covers_fullscreen = true, show_parent = tree_container,
        close_callback = function() ran.tree_closed = true end })
    function tree:onMenuSelect(item, pos)
        if item.state and pos and pos.x < 0.3 then item.state.callback() else ran.tree_chose = item.text end
        return true
    end
    tree_container[1] = tree
    UIManager:show(tree_container)
end)
H.step(S, function()
    H.check(H.find("Chapter 1.1") == nil and H.findWhere(function(e) return e.label == "\u{25B8}" end) ~= nil, "a closed chapter shows an opening mark")
    H.shot("5-tree-closed")
    local mark = H.findWhere(function(e) return e.label == "\u{25B8}" end)
    H.tapAt(mark.x + mark.w / 2, mark.y + mark.h / 2)
end)
H.step(S, function()
    H.check(H.find("Chapter 1.1") ~= nil and H.find("Chapter 1.2") ~= nil, "the mark opens the chapter, through KOReader's own button")
    H.check(H.findWhere(function(e) return e.label == "\u{25BE}" end) ~= nil, "and now points the other way")
    H.shot("6-tree-open")
    H.tap("Part one")
end)
H.step(S, function()
    H.check(ran.tree_chose == "Part one", "a tap on the title chooses the item, not toggles it")
    local mark = H.findWhere(function(e) return e.label == "\u{25BE}" end)
    H.tapAt(mark.x + mark.w / 2, mark.y + mark.h / 2)
end)
H.step(S, function()
    H.check(H.find("Chapter 1.1") == nil, "the mark closes it again")
    UIManager:close(tree_container)
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
