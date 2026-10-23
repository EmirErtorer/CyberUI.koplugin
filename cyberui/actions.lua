-- What can be done with books and folders from any screen: open them, see a
-- book's details, change its status, put it in collections, rename, move,
-- make folders and send things to the trash, plus the hold sheets that offer
-- these actions.

local App = require("cyberui/app")
local Books = require("cyberui/data/books")
local Collections = require("cyberui/data/collections")
local Files = require("cyberui/data/files")
local Library = require("cyberui/data/library")
local Trash = require("cyberui/data/trash")
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
    for _i, c in ipairs(Collections.list()) do
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
    App.push("library", { dir = Files.parent(path) })
end

-- Show a failed action's reason.
local function failed(err)
    App.confirm({ title = _("That did not work"), text = err, ok = _("OK") })
end

-- Rename a book or folder, keeping a book's extension unless it is typed.
function Actions.rename(path, after)
    local name = Files.name(path)
    App.input(_("Rename"), name, function(new_name)
        if util.trim(new_name or "") == name then return end
        local to, err = Files.rename(path, new_name)
        if not to then return failed(err) end
        App.toast(_("Renamed"))
        if after then after(to) else App.update() end
    end, _("Rename"))
end

-- Pick a folder and move a book or folder into it.
function Actions.move(path, after)
    App.push("library", { dir = Files.parent(path), pick = {
        title = _("Move to"),
        moving = path,
        on_pick = function(dir)
            App.pop()
            local to, err = Files.moveInto(path, dir)
            if not to then return failed(err) end
            App.toast(string.format(_("Moved to %s"), Files.name(dir)))
            if after then after(to) else App.update() end
        end,
    } })
end

-- Make a new folder in `dir`, then call after(path).
function Actions.newFolder(dir, after)
    App.input(_("New folder"), "", function(name)
        local path, err = Files.mkdir(dir, name)
        if not path then return failed(err) end
        App.toast(_("Folder created"))
        if after then after(path) else App.update() end
    end, _("Create"), { placeholder = _("folder name") })
end

-- Send a book or folder to the trash after asking.
function Actions.delete(path, after)
    local is_dir = Files.isDir(path)
    local days = string.format(_("It waits in the trash for %d days."), Trash.KEEP_DAYS)
    App.confirm({
        title = string.format(_("Delete \u{201C}%s\u{201D}?"), Files.name(path)),
        text = is_dir and (_("The folder and everything in it go.") .. " " .. days) or days,
        ok = _("Delete"),
        on_ok = function()
            local ok, err = Trash.put(path)
            if not ok then return failed(err) end
            App.toast(_("Moved to the trash"))
            if after then after() else App.update() end
        end,
    })
end

-- Make a folder the top of the library.
function Actions.makeHome(dir)
    G_reader_settings:saveSetting("home_dir", dir)
    Library.reset()
    App.toast(_("Library home set"))
    App.update()
end

-- The hold sheet of a book.
function Actions.bookSheet(path)
    local info, st = Books.info(path), Books.state(path)
    local done = st.status == "complete"
    App.sheet({ title = info.title, sub = filemanagerutil.abbreviate(Files.parent(path)), actions = {
        { icon = "forward", label = _("Open"), on_tap = function() Actions.open(path) end },
        { icon = "eye", label = _("Details"), on_tap = function() Actions.details(path) end },
        { icon = "check", label = done and _("Mark reading") or _("Mark done"),
            on_tap = function() Actions.setStatus(path, done and "reading" or "complete") end },
        { icon = "collections", label = _("Collections"), on_tap = function() Actions.collect(path) end },
        { icon = "edit", label = _("Rename"), on_tap = function() Actions.rename(path) end },
        { icon = "move", label = _("Move to"), on_tap = function() Actions.move(path) end },
        { icon = "trash", label = _("Delete"), danger = true, on_tap = function() Actions.delete(path) end },
    } })
end

-- The hold sheet of a folder; `open` goes into it.
function Actions.folderSheet(path, open)
    App.sheet({ title = Files.name(path), sub = filemanagerutil.abbreviate(Files.parent(path)), actions = {
        { icon = "folder", label = _("Open"), on_tap = open },
        { icon = "home", label = _("Make library home"), on_tap = function() Actions.makeHome(path) end },
        { icon = "edit", label = _("Rename"), on_tap = function() Actions.rename(path) end },
        { icon = "move", label = _("Move to"), on_tap = function() Actions.move(path) end },
        { icon = "trash", label = _("Delete"), danger = true, on_tap = function() Actions.delete(path) end },
    } })
end

return Actions
