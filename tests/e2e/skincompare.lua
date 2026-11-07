-- Every KOReader widget CyberUI styles, shown once and photographed: run it with CYBERUI_SKINMODE=old (KOReader's own look,
-- the styled look switched off) and again with CYBERUI_SKINMODE=new to put the two side by side.
local H = ...
local UIManager = require("ui/uimanager")
local S = 1.6
local mode = os.getenv("CYBERUI_SKINMODE") or "new"
require("cyberui/settings").set("styled_menu", mode == "new")
G_reader_settings:saveSetting("virtual_keyboard_enabled", true)

local n = 0
local current
-- One scene: make(show) shows a widget and returns it; it is photographed, then closed.
local function scene(name, make, extra)
    n = n + 1
    local label = string.format("%02d-%s", n, name)
    H.step(S, function() current = make() end)
    H.step(S, function()
        if extra then extra(current) end
        H.shot(label)
        if current then UIManager:close(current) end
        current = nil
    end)
end
local function show(w) UIManager:show(w); return w end

scene("message", function()
    return show(require("ui/widget/infomessage"):new({ text = "Highlight saved to your notes.", timeout = 20 }))
end)
scene("question", function()
    return show(require("ui/widget/confirmbox"):new({ text = "Delete this highlight? This can't be undone.", ok_text = "Delete it" }))
end)
scene("question-three", function()
    return show(require("ui/widget/multiconfirmbox"):new({ text = "Which copy do you want to keep?", choice1_text = "This device", choice2_text = "The cloud" }))
end)
scene("button-dialog", function()
    local rows = { { { text = "Open", callback = function() end }, { text = "Sort by title", checked_func = function() return true end, callback = function() end } },
        { { text = "Locked", enabled = false, callback = function() end }, { text = "Details", callback = function() end } },
        { { text = "Delete", callback = function() end } } }
    return show(require("ui/widget/buttondialog"):new({ title = "Book options", buttons = rows }))
end)
scene("notification", function()
    return show(require("ui/widget/notification"):new({ text = "Brightness 40%", timeout = 20 }))
end)
local dlg
scene("input", function()
    dlg = require("ui/widget/inputdialog"):new({ title = "Rename bookmark", description = "Give it a name you will find again.", input = "Chapter 3", input_hint = "name",
        buttons = { { { text = "Cancel", callback = function() UIManager:close(dlg) end }, { text = "Save", is_enter_default = true, callback = function() UIManager:close(dlg) end } } } })
    show(dlg)
    dlg:onShowKeyboard()
    return dlg
end)
scene("input-russian", function()
    G_reader_settings:saveSetting("keyboard_layout", "ru")
    dlg = require("ui/widget/inputdialog"):new({ title = "Search", input = "", input_hint = "word",
        buttons = { { { text = "Cancel", callback = function() UIManager:close(dlg) end }, { text = "Search", is_enter_default = true, callback = function() UIManager:close(dlg) end } } } })
    show(dlg)
    dlg:onShowKeyboard()
    return dlg
end, function() G_reader_settings:saveSetting("keyboard_layout", "en") end)
scene("note", function()
    dlg = require("ui/widget/inputdialog"):new({ title = "Note", allow_newline = true, fullscreen = true,
        input = "First line of a note.\nA second line that is long enough to wrap around the edge of the field because notes are long, and then some more words follow it.",
        buttons = { { { text = "Close", callback = function() UIManager:close(dlg) end }, { text = "Save note", callback = function() UIManager:close(dlg) end } } } })
    show(dlg)
    dlg:onShowKeyboard()
    return dlg
end)
scene("list", function()
    local Menu = require("ui/widget/menu")
    local Screen = require("device").screen
    local items = {}
    for i = 1, 30 do items[i] = { text = "Chapter " .. i .. ": a title that goes on a while", mandatory = tostring(i * 7), callback = function() end } end
    items.current = 4
    local container = require("ui/widget/container/centercontainer"):new({ dimen = Screen:getSize(), covers_fullscreen = true })
    container[1] = Menu:new({ title = "Contents", item_table = items, is_borderless = true, is_popout = false, covers_fullscreen = true,
        show_parent = container, close_callback = function() UIManager:close(container) end })
    return show(container)
end)

-- in a book
H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(5, function() end)
scene("contents", function()
    local ui = require("apps/reader/readerui").instance
    ui.toc:onShowToc()
    for _i, e in ipairs(UIManager._window_stack) do if e.widget.name ~= "cyberui_popup" and (e.widget.item_table or (e.widget[1] and e.widget[1].item_table)) then current = e.widget end end
    return current
end)
scene("dictionary", function()
    local ui = require("apps/reader/readerui").instance
    local long = {}
    for i = 1, 40 do long[#long + 1] = "Sense " .. i .. ": a fortunate discovery made by accident while looking for something quite different." end
    ui.dictionary:showDict("serendipity", { { dict = "Oxford Test Dictionary", word = "serendipity", definition = table.concat(long, "\n") },
        { dict = "Second Test Dictionary", word = "serendipity", definition = "The occurrence of events by chance in a happy way." } }, nil)
    for _i, e in ipairs(UIManager._window_stack) do if e.widget.definition then return e.widget end end
end)
scene("highlight-menu", function()
    local ui = require("apps/reader/readerui").instance
    ui.highlight.selected_text = { text = "hello world", sboxes = { { x = 100, y = 400, w = 200, h = 30 } } }
    ui.highlight:onShowHighlightMenu()
    return ui.highlight.highlight_dialog
end)
