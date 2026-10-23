-- What can be done with a book from any screen: open it, see its details,
-- change its status, put it in collections, show its folder or delete it.

local App = require("cyberui/app")
local Books = require("cyberui/data/books")
local Collections = require("cyberui/data/collections")
local Library = require("cyberui/data/library")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local util = require("util")
local _ = require("gettext")

local Actions = {}

-- Open the book in the reader.
function Actions.open(path)
    App.openBook(path)
end

-- Show the book's dossier.
function Actions.details(path)
    App.push("dossier", { path = path })
end

-- Set the reading status ("reading", "complete", "abandoned").
function Actions.setStatus(path, status)
    local DocSettings = require("docsettings")
    local ds = DocSettings:open(path)
    local summary = ds:readSetting("summary") or {}
    summary.status = status
    filemanagerutil.saveSummary(ds, summary)
    Books.forget(path)
    App.update()
end

-- Pick the collections the book is in, or make a new one for it.
function Actions.collect(path)
    local options = {}
    for _, c in ipairs(Collections.list()) do
        options[#options + 1] = {
            label = c.title, checked = Collections.has(path, c.name),
            on_tap = function() Collections.toggle(path, c.name); App.update(); Actions.collect(path) end,
        }
    end
    options[#options + 1] = { label = _("New collection"), icon = "plus", on_tap = function()
        App.input(_("New collection"), "", function(name)
            name = util.trim(name or "")
            if name == "" then return end
            Collections.create(name)
            Collections.toggle(path, name)
            App.toast(_("Added to ") .. name)
            App.update()
        end, _("Create"))
    end }
    App.choose({ title = _("Collections"), options = options })
end

-- Show the folder the book is in.
function Actions.showFolder(path)
    local dir = util.splitFilePathName(path):gsub("/$", "")
    App.push("library", { dir = dir })
end

-- Delete the book file after asking.
function Actions.delete(path, after)
    local _dir, name = util.splitFilePathName(path)
    App.confirm({
        danger = true, title = _("Attention"), detail = name,
        text = _("This deletes the file, its highlights and its reading history. It cannot be undone."),
        ok = _("Delete"), cancel = _("Abort"),
        on_ok = function()
            local FileManager = require("apps/filemanager/filemanager")
            local fm = FileManager.instance or FileManager
            local ok = fm:deleteFile(path, true)
            if ok then
                Books.forget(path)
                Library.reset()
                App.toast(_("File deleted"))
                if after then after() end
            end
        end,
    })
end

return Actions
