-- The reader's drop-down after it stepped aside for a plugin's window, in the
-- two ways that went wrong on devices: the window closed without its close
-- reaching CyberUI (the menu never opened again in that book), and the book
-- closed for home while the menu waited (it came back over no book and ran a
-- plugin's item text that reads the closed document, which crashed KOReader).
local H = ...
local UIManager = require("ui/uimanager")
local Event = require("ui/event")
local ReaderUI = require("apps/reader/readerui")
local Menu = require("cyberui/menu")
local msg, book

-- A plugin's settings window shown from a menu item that keeps the menu open.
local function showDialog(swallow_close)
    -- (a window of the plugin's own making, which CyberUI's skins leave as it is)
    msg = require("ui/widget/container/framecontainer"):new({
        background = require("ffi/blitbuffer").COLOR_WHITE, bordersize = 2, padding = 20,
        require("ui/widget/textwidget"):new({ text = "A plugin's settings window", face = require("ui/font"):getFace("cfont", 20) }),
    })
    if swallow_close then
        -- (a child of the window takes the close event, so the window's own handler never hears it)
        local handle = msg.handleEvent
        msg.handleEvent = function(w, ev)
            if ev.handler == "onCloseWidget" then return true end
            return handle(w, ev)
        end
    end
    UIManager:show(msg)
end

-- Open the reader's menu and pick an item that shows a window and keeps the menu open.
local function asideWith(swallow_close)
    ReaderUI.instance.menu:onShowMenu()
    local m = Menu.current()
    H.check(m and m.popup_open, "the menu is open over the book")
    if not m then return end
    -- like Reading style's entries: the text is read from the open document
    local ui = ReaderUI.instance
    table.insert(m.items, 1, { text_func = function() return "font " .. tostring(ui.document.file):sub(-8) end, keep_menu_open = true,
        callback = function() showDialog(swallow_close) end })
    m:select(m.items[1])
end

H.step(1, function()
    book = require("cyberui/data/library").all()[1]
    H.app().openBook(book)
end)
-- 1. the window's close never reaches the menu
H.step(4, function() asideWith(true) end)
H.step(2, function()
    local m = Menu.current()
    H.check(m and m.aside == true, "the menu stepped aside for the window")
    UIManager:close(msg)
end)
H.step(2, function()
    ReaderUI.instance.menu:onShowMenu()
end)
H.step(2, function()
    local m = Menu.current()
    H.check(m and m.popup_open == true, "after the window closed, a swipe down opens the menu again")
    H.shot("s01-reopened")
    if m then m:close() end
end)
-- 2. home while the menu waits for the window, with the book parked under
-- home and then really closed (reader parking off)
local function homeCase(park, tag)
    H.step(1, function()
        require("cyberui/settings").save("park_reader", park)
        H.app().openBook(book)
    end)
    H.step(4, function() asideWith(false) end)
    H.step(2, function()
        local m = Menu.current()
        H.check(m and m.aside == true, tag .. ": the menu stepped aside again")
        ReaderUI.instance:handleEvent(Event:new("CyberUIHome"))
    end)
    H.step(3, function()
        if msg and UIManager:isWidgetShown(msg) then UIManager:close(msg) end
    end)
    H.step(3, function()
        H.check(park == require("cyberui/park").isParked(), tag .. ": the book left for home")
        H.check(Menu.current() == nil, tag .. ": no menu is left over home from the book")
        H.check(H.cyberTop(), tag .. ": CyberUI home is on top and KOReader is still running")
        H.shot("s02-home-" .. tag)
    end)
end
homeCase(true, "parked")
homeCase(false, "closed")
-- 3. the next book opens its menu as usual
H.step(1, function() H.app().openBook(book) end)
H.step(4, function() ReaderUI.instance.menu:onShowMenu() end)
H.step(2, function()
    local m = Menu.current()
    H.check(m and m.popup_open == true, "in the reopened book a swipe down opens the menu")
    H.shot("s03-book-menu")
    if m then m:close() end
end)
