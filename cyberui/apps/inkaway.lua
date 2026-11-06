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

-- CyberUI icons for the glyphs of Ink Away's quick menu.
local TILE_ICONS = { pen = "pen", booknotes = "notes", clipboard = "image", notebook = "book", library = "library" }

-- Ink Away's quick menu (its pen tab in the top menu) drawn as a CyberUI sheet,
-- over home or, in a book, in a popup of its own, with the same actions and
-- gesture hints as Ink Away's own sheet. `ui` is the file browser or the reader
-- the tab belongs to. False when Ink Away is not running there, so the caller
-- can use Ink Away's own.
function InkAway.quickMenu(ui, in_book)
    local plugin = ui and ui[(InkAway.folder:gsub("%.koplugin$", ""))]
    local ok, Launcher = pcall(require, "ink/launcher")
    local ok_l, L = pcall(require, "ink/l10n")
    if not (plugin and ok and ok_l) then return false end
    local tiles = Launcher.tiles(plugin, L, function(text, ...)
        local args = { ... }
        return (text:gsub("%%(%d)", function(i) return tostring(args[tonumber(i)]) end))
    end)
    local actions = {}
    for _i, t in ipairs(tiles) do
        actions[#actions + 1] = { icon = TILE_ICONS[t.icon] or "pen", label = t.title, sub = t.note,
            on_tap = function() require("ui/uimanager"):nextTick(t.run) end }
    end
    local o = {
        title = "Ink Away",   -- i18n: keep
        sub = _("DRAW // NOTES // INK"), cols = 1, actions = actions,
    }
    if not in_book then
        require("cyberui/app").sheet(o)
        return true
    end
    local Dialog = require("cyberui/ui/dialog")
    local Popup = require("cyberui/popup")
    local popup
    local function close() if popup then popup:close(); popup = nil end end
    popup = Popup:new({ element = Dialog.sheet(o, close, require("device").screen:getWidth()),
        on_outside = close, on_back = function() close(); return true end })
    popup:open()
    return true
end

return InkAway
