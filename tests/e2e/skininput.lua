-- KOReader's input dialog and keyboard in CyberUI's style, over home: typing goes through KOReader's own
-- input box and keys, the field shows it, a tap on the field moves the cursor, the buttons run KOReader's callbacks.
local H = ...
local UIManager = require("ui/uimanager")
local S = 1.2

local function index(widget)
    for i, e in ipairs(UIManager._window_stack) do if e.widget == widget then return i end end
end

local dialog, saved, kb
-- the emulator has a physical keyboard: ask for the on-screen one, as a touch device has
G_reader_settings:saveSetting("virtual_keyboard_enabled", true)
H.step(S, function()
    dialog = require("ui/widget/inputdialog"):new({
        title = "Rename bookmark", description = "Give it a name you will find again.", input = "Chapter 3", input_hint = "name",
        buttons = { { { text = "Cancel", id = "close", callback = function() UIManager:close(dialog) end },
            { text = "Save", is_enter_default = true, callback = function() saved = dialog:getInputText(); UIManager:close(dialog) end } } },
    })
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end)
H.step(S, function()
    kb = dialog._input_widget.keyboard
    H.check(dialog._cyber_popup ~= nil and kb._cyber_popup ~= nil, "the dialog and its keyboard are both drawn by CyberUI")
    H.check(index(dialog) < index(dialog._cyber_popup) and index(dialog._cyber_popup) < index(kb) and index(kb) < index(kb._cyber_popup),
        "in KOReader's order: dialog, its card, keyboard, its keys")
    H.check(H.find("// INPUT") ~= nil and H.find("Rename bookmark") ~= nil, "the card shows its tag and title")
    H.check(H.typed() == "Chapter 3", "the field shows KOReader's text")
    H.shot("1-input-dialog")
end)
H.step(S, function()
    -- the English layout starts in lower case: tap q w e
    for _i, ch in ipairs({ "q", "w", "e" }) do H.tap(ch) end
end)
H.step(S, function()
    H.check(dialog:getInputText():sub(-3) == "qwe", "keys type into KOReader's input box: " .. dialog:getInputText())
    H.check(H.typed() == dialog:getInputText(), "the field shows what was typed")
    H.shot("2-typed")
    -- shift
    H.tap("\u{21E7}")
end)
H.step(S, function()
    H.check(H.find("Q", nil, true) ~= nil, "shift shows the capital letters (KOReader's layer change)")
    H.shot("3-shift")
    H.tap("\u{21E7}")
end)
H.step(S, function()
    -- a tap on the field moves the cursor: tap near the left end of the text
    local field = dialog._cyber_field
    H.check(field ~= nil, "the field is there")
    H.tapAt(field.x + field.text_x + 2, field.y + field.h / 2)
end)
H.step(S, function()
    local inp = dialog._input_widget
    H.check(inp.charpos == 1, "a tap on the field moved the cursor to the start (charpos " .. tostring(inp.charpos) .. ")")
    H.tap("x")
end)
H.step(S, function()
    H.check(dialog:getInputText():sub(1, 1) == "x", "typing goes in at the cursor")
    H.shot("4-cursor")
    H.tap("Save")
end)
H.step(S, function()
    H.check(saved ~= nil and saved:sub(1, 1) == "x", "Save ran KOReader's callback with the text")
    H.check(index(dialog) == nil and dialog._cyber_popup == nil and kb._cyber_popup == nil, "everything closed with the dialog, keyboard too")
end)

-- another script: the Russian layout
H.step(S, function()
    G_reader_settings:saveSetting("keyboard_layout", "ru")
    dialog = require("ui/widget/inputdialog"):new({ title = "Search", input = "", input_hint = "word",
        buttons = { { { text = "Cancel", callback = function() UIManager:close(dialog) end },
            { text = "Search", is_enter_default = true, callback = function() UIManager:close(dialog) end } } } })
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end)
H.step(S, function()
    H.check(H.find("\u{43F}", nil, true) ~= nil or H.find("\u{41F}", nil, true) ~= nil, "the Russian layout's keys are drawn")
    H.shot("5-russian")
    UIManager:close(dialog)
    G_reader_settings:saveSetting("keyboard_layout", "en")
end)

-- a long text: many lines, the field wraps and the cursor follows
H.step(S, function()
    dialog = require("ui/widget/inputdialog"):new({ title = "Note", allow_newline = true, fullscreen = true,
        input = "First line of a note.\nA second line that is long enough to wrap around the edge of the field because notes are long, and then some more words follow it.",
        buttons = { { { text = "Close", callback = function() UIManager:close(dialog) end },
            { text = "Save note", callback = function() UIManager:close(dialog) end } } } })
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end)
H.step(S, function()
    H.check(dialog._cyber_popup ~= nil and #dialog._cyber_field.rows >= 3, "a long text wraps over several lines")
    H.shot("6-note")
    UIManager:close(dialog)
end)
