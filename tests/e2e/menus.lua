-- The menu entries and the gesture action: CyberUI in the file browser's
-- Tools tab, "CyberUI home" in the reader's Tools tab, and the action listed
-- for gestures; the Back key goes back a screen.
local H = ...
local S = 0.8

-- Is `key` in the given tab of a KOReader menu order table?
local function inTab(order, tab, key)
    for _i, k in ipairs(order[tab] or {}) do if k == key then return true end end
    return false
end

H.step(1, function()
    local fm = require("apps/filemanager/filemanager").instance
    fm.menu:onShowMenu()
end)
H.step(S, function()
    local fm = require("apps/filemanager/filemanager").instance
    local item = fm.menu.menu_items.cyberui
    H.check(item ~= nil and item.text == "CyberUI", "file browser menu has CyberUI")
    local tools = fm.menu.tab_item_table and fm.menu.tab_item_table[3]
    local found = false
    for _i, it in ipairs(tools or {}) do if it == item then found = true end end
    H.check(found, "it sits in the Tools tab")
    fm.menu:onCloseFileManagerMenu()
    H.check(require("dispatcher"):isActionEnabled("cyberui_home") ~= false, "gesture action registered")
end)
-- Back key from a section returns home
H.step(S, function() H.app().go("library") end)
H.step(S, function() H.event("Back") end)
H.step(S, function() H.check(H.screen() == "home", "Back key goes back to home") end)
-- the reader's menu entry
H.step(S, function()
    local book = require("cyberui/data/library").all()[1]
    H.app().openBook(book)
end)
H.step(3, function() require("apps/reader/readerui").instance.menu:onShowMenu() end)
H.step(S, function()
    local ui = require("apps/reader/readerui").instance
    local item = ui and ui.menu.menu_items.cyberui
    H.shot("m01-reader-menu")
    ui.menu:onCloseReaderMenu()
    H.check(item ~= nil and item.text == "CyberUI home", "reader menu has CyberUI home")
    if item then item.callback() end
end)
H.step(3, function() H.check(H.cyberTop() and H.screen() == "home", "the reader's entry brings CyberUI home") end)
