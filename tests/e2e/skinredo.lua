-- The widgets whose styled look goes beyond re-drawing KOReader's buttons, photographed for comparison: run with
-- CYBERUI_SKINMODE=stock (KOReader's own look) or styled, and keep the images of each state of the code to put side by side.
local H = ...
local UIManager = require("ui/uimanager")
local S = 1.8
local mode = os.getenv("CYBERUI_SKINMODE") or "styled"
require("cyberui/settings").set("styled_widgets", mode ~= "stock")
local n, current, ui = 0, nil, nil

-- One scene: make() shows a widget and returns it; photographed, then closed.
local function scene(name, make)
    n = n + 1
    local label = string.format("%02d-%s", n, name)
    H.step(S, function() current = make() end)
    H.step(S, function()
        H.shot(label)
        if current then UIManager:close(current) end
        current = nil
    end)
end

H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(5, function()
    ui = require("apps/reader/readerui").instance
    local xp = ui.document.getXPointer and ui.document:getXPointer() or 1
    ui.annotation.annotations = {
        { drawer = "lighten", color = "yellow", text = "A highlight that was saved earlier, long enough to wrap on the list.", page = 1, pageno = 1, pos0 = xp, pos1 = xp,
            datetime = "2026-11-01 10:00:00", chapter = "BIRINCI BÖLÜM" },
        { drawer = "underscore", color = "red", text = "A highlight with a note on it.", note = "Remember this for the essay.", page = 2, pageno = 2, pos0 = xp, pos1 = xp,
            datetime = "2026-11-02 11:00:00", chapter = "BIRINCI BÖLÜM" },
        { text = "Page 3 BIRINCI BÖLÜM", page = 3, pageno = 3, pos0 = xp, datetime = "2026-11-03 12:00:00", chapter = "BIRINCI BÖLÜM" },
    }
end)
scene("edit-highlight", function()
    ui.highlight:showHighlightDialog(1)
    for _i, e in ipairs(UIManager._window_stack) do if e.widget.buttontable then current = e.widget end end
    return current
end)
scene("dictionary", function()
    local long = {}
    for i = 1, 40 do long[#long + 1] = "Sense " .. i .. ": a fortunate discovery made by accident while looking for something quite different." end
    ui.dictionary:showDict("serendipity", { { dict = "Oxford Test Dictionary", word = "serendipity", definition = table.concat(long, "\n") },
        { dict = "Second Test Dictionary", word = "serendipity", definition = "The occurrence of events by chance in a happy way." } }, nil)
    for _i, e in ipairs(UIManager._window_stack) do if e.widget.definition then return e.widget end end
end)
scene("contents", function()
    ui.toc:onShowToc()
    for _i, e in ipairs(UIManager._window_stack) do
        if e.widget.name ~= "cyberui_popup" and (e.widget.item_table or (e.widget[1] and e.widget[1].item_table)) then current = e.widget end
    end
    return current
end)
scene("bookmarks", function()
    ui.bookmark:onShowBookmark()
    for _i, e in ipairs(UIManager._window_stack) do
        if e.widget.name ~= "cyberui_popup" and (e.widget.item_table or (e.widget[1] and e.widget[1].item_table)) then current = e.widget end
    end
    return current
end)
scene("question", function()
    local box = require("ui/widget/confirmbox"):new({ text = "Delete this highlight? This can't be undone.", ok_text = "Delete it", icon = "notice-warning" })
    UIManager:show(box)
    return box
end)
scene("button-dialog", function()
    local dlg = require("ui/widget/buttondialog"):new({ title = "The Book.epub", buttons = {
        { { id = "open", text = "Open", callback = function() end }, { id = "info", text = "Book information", callback = function() end } },
        { { id = "collections", text = "Add to a collection", callback = function() end }, { id = "cover", text = "Set custom cover", callback = function() end } },
        { { id = "move", text = "Move", callback = function() end }, { id = "rename", text = "Rename", callback = function() end } },
        { { id = "delete", text = "Delete", callback = function() end }, { id = "reset", text = "Reset settings", callback = function() end } },
    } })
    UIManager:show(dlg)
    return dlg
end)
