-- In a book with Ink Away running, the reader's Tools menu offers the
-- annotation mode.
local H = ...
H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(3, function()
    local ui = require("apps/reader/readerui").instance
    local items = {}
    ui.menu_items = nil
    local plugin = ui.cyberui or ui.CyberUI
    plugin:addToMainMenu(items)
    local inkaway = require("cyberui/apps/addons").loadedIn(ui, require("cyberui/apps/inkaway"))
    H.check((items.cyberui_annotate ~= nil) == inkaway, "annotate entry shown exactly when Ink Away runs (" .. tostring(inkaway) .. ")")
    H.check(items.cyberui ~= nil, "home entry still there")
    if items.cyberui_annotate then
        local got
        local old = ui.handleEvent
        ui.handleEvent = function(self, ev) if ev.handler == "onInkAwayAnnotate" then got = true end return old(self, ev) end
        items.cyberui_annotate.callback()
        ui.handleEvent = old
        H.check(got, "tapping it sends the annotate action")
    end
end)
