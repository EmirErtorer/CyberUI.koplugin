-- Ink Away, offered on the home screen to everyone: opened when it is
-- installed, otherwise described and installable from its GitHub releases.

local _ = require("cyberui/gettext")

local InkAway = {
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

-- Open Ink Away's annotation mode on a book: the one being read, the one put
-- away under home or the one read last, brought back first (the mode belongs to an open book).
function InkAway.annotate()
    local Addons = require("cyberui/apps/addons")
    local ui = require("apps/reader/readerui").instance
    if ui and ui.document and not require("cyberui/park").isParked() then   -- a book is open: annotate it
        if not Addons.loadedIn(ui, InkAway) then return Addons.launch(InkAway) end
        return ui:handleEvent(require("ui/event"):new("InkAwayAnnotate"))
    end
    if Addons.status(InkAway) ~= "ready" then return Addons.launch(InkAway) end
    local path = require("cyberui/park").file()
    path = path or require("cyberui/data/history").lastFile()
    if not path then return require("cyberui/app").toast(_("Open a book first")) end
    require("cyberui/app").openBook(path, function(reader)
        require("ui/uimanager"):nextTick(function() reader:handleEvent(require("ui/event"):new("InkAwayAnnotate")) end)
    end)
end

return InkAway
