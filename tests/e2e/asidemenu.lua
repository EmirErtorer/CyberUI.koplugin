-- An item that keeps the reader's drop-down open and shows a window (as a plugin's
-- settings dialog does) hides the menu until that window closes.
local H = ...
local UIManager = require("ui/uimanager")
local msg
H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(4, function() require("apps/reader/readerui").instance.menu:onShowMenu() end)
H.step(2, function()
    local m = require("cyberui/menu").current()
    H.check(m and m.popup_open, "the menu is open over the book")
    m:select({ text = "dialog", keep_menu_open = true, callback = function()
        msg = require("ui/widget/infomessage"):new({ text = "A plugin's floating dialog" })
        UIManager:show(msg)
    end })
end)
H.step(2, function()
    local m = require("cyberui/menu").current()
    local names = {}
    for _i, win in ipairs(UIManager._window_stack) do names[#names + 1] = tostring(win.widget.name or win.widget.id or "?") end
    H.check(m and m.popup_open == false and m.aside == true, "the menu steps aside while the dialog is up: " .. table.concat(names, ",") .. " open=" .. tostring(m and m.popup_open))
    H.shot("aside")
    UIManager:close(msg)
end)
H.step(2, function()
    local m = require("cyberui/menu").current()
    H.check(m and m.popup_open == true, "the menu comes back when the dialog closes")
    H.shot("back")
end)
