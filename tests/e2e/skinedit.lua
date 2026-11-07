-- KOReader's dialog for a saved highlight, sorted by what it does: tools as tiles, four labelled edge arrows, delete in the
-- warning colour; KOReader's callbacks stay attached.
local H = ...
local UIManager = require("ui/uimanager")
local S = 1.6
local ui, dialog

H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(5, function()
    ui = require("apps/reader/readerui").instance
    local xp = ui.document.getXPointer and ui.document:getXPointer() or 1
    ui.annotation.annotations = { { drawer = "lighten", color = "yellow", text = "A highlight that was saved earlier, long enough to wrap in the preview.", page = 1, pageno = 1,
        pos0 = xp, pos1 = xp, datetime = "2026-11-01 10:00:00", chapter = "One" } }
    ui.highlight:showHighlightDialog(1)
    for _i, e in ipairs(UIManager._window_stack) do if e.widget.buttontable then dialog = e.widget end end
end)
H.step(S, function()
    H.check(dialog ~= nil and dialog._cyber_popup ~= nil, "the dialog is drawn by CyberUI")
    H.check(H.find("// HIGHLIGHT") ~= nil and H.find("// ADJUST") ~= nil, "it says what it is and has an adjust section")
    H.check(H.findWhere(function(e) return e.label == "\u{F48E}" or e.text == "\u{F48E}" or e.text == "\u{25C1}\u{2592}\u{2592}" end) == nil, "KOReader's drawn symbols are gone")
    H.check(H.find("Style") ~= nil and H.find("Note") ~= nil and H.find("Details") ~= nil, "style, note and details are named tiles")
    local seen, edges = {}, 0
    H.findWhere(function(e)
        if not seen[e] and e.kind == "micro" and (e.text == "START" or e.text == "END") then edges = edges + 1 end
        seen[e] = true
        return false
    end)
    H.check(edges == 4, "four labelled edge tiles: " .. edges)
    local delete = H.findWhere(function(e) return e.shape and e.line == "accent" end)
    H.check(delete ~= nil and type(delete.on_tap) == "function", "delete is outlined in the warning colour and answers a tap")
    H.shot("1-edit-highlight")
    local note = H.find("Note", nil, true)
    H.check(note ~= nil and type(note.on_tap) == "function", "a tile carries KOReader's callback")
    UIManager:close(dialog)
end)
