-- The highlight menu as a toolbar: icon tiles for what you do with the selection and for the lookups, plain buttons for the rest,
-- the selected words on top. KOReader's callbacks run; a slot the skin does not know is still drawn.
local H = ...
local UIManager = require("ui/uimanager")
local S = 1.5
local ui, dialog

H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(5, function()
    ui = require("apps/reader/readerui").instance
    -- a plugin adds an action of its own
    ui.highlight:addToHighlightDialog("99_plugin_thing", function()
        return { text = "Plugin thing", callback = function() ui.highlight.ran = true; ui.highlight:onClose() end }
    end)
    ui.highlight.selected_text = { text = "A passage the reader has just selected, long enough to be cut short in the preview of the menu so the card stays small.",
        sboxes = { { x = 100, y = 400, w = 200, h = 30 } } }
    ui.highlight:onShowHighlightMenu()
    dialog = ui.highlight.highlight_dialog
end)
H.step(S, function()
    H.check(dialog._cyber_popup ~= nil, "the menu is drawn by CyberUI")
    H.check(H.find("// SELECTION") ~= nil, "it says what it is about")
    H.check(H.findWhere(function(e) return type(e.text) == "string" and e.text:find("^\u{201C}A passage") end) ~= nil, "it shows the selected words")
    local icons = {}
    H.findWhere(function(e) if e.name and e.size then icons[#icons + 1] = e.name end return false end)
    H.check(#icons >= 8, "the actions are tiles with icons: " .. #icons)
    H.check(H.find("Plugin thing", nil, true) ~= nil, "an action from a plugin is drawn too, plainly")
    local select = H.find("Select", nil, true)
    H.check(select ~= nil and type(select.on_tap) == "function", "a usable tile answers a tap with KOReader's callback")
    H.check(H.find("Highlight", nil, true) == nil and H.findWhere(function(e) return e.text == "Highlight" end) ~= nil, "a tile KOReader switched off is shown but takes no taps")
    H.shot("1-highlight-menu")
    H.tap("Plugin thing")
end)
H.step(S, function()
    H.check(ui.highlight.ran and not UIManager:isWidgetShown(dialog) and dialog._cyber_popup == nil, "a tap runs KOReader's callback, which closes the menu")
end)
