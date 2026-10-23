-- Ink Away, offered on the home screen to everyone: opened when it is
-- installed, otherwise described and installable from its GitHub releases.

local _ = require("gettext")

return {
    id = "inkaway",
    name = "Ink Away",
    folder = "ink-away.koplugin",
    repo = "EmirErtorer/ink-away.koplugin",
    -- the zip each release carries
    zip = function(tag) return "ink-away.koplugin-" .. tag .. ".zip" end,
    -- the event Ink Away opens on
    open_event = "InkAwayOpen",
    icon = "pen",
    tagline = _("DRAW // NOTES // INK"),
    description = _("Draw, take notes and write on your books with a finger or a stylus: drawings with layers, notebooks with lined, grid and planner pages, and ink on any book that follows the text. Export a transparent PNG or a PDF."),
}
