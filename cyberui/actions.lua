-- What can be done with books and folders from any screen: open them, see a
-- book's details, change its status, put it in collections, rename, move,
-- make folders and send things to the trash, plus the hold sheets that offer
-- these actions.

local App = require("cyberui/app")
local Books = require("cyberui/data/books")
local Collections = require("cyberui/data/collections")
local Files = require("cyberui/data/files")
local History = require("cyberui/data/history")
local Library = require("cyberui/data/library")
local Settings = require("cyberui/settings")
local Trash = require("cyberui/data/trash")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local util = require("util")
local _ = require("cyberui/gettext")

local Actions = {}

-- Open the book in the reader.
function Actions.open(path)
    App.openBook(path)
end

-- Open the book at a data shard (its highlight), when it can be found.
function Actions.openAt(path, shard)
    App.openBook(path, function(ui)
        if shard.page then
            local Event = require("ui/event")
            ui:handleEvent(Event:new(ui.paging and "GotoPage" or "GotoXPointer", shard.page, shard.pos0))
        end
    end)
end

local TAP_AGAIN = 3   -- seconds a first tap waits for its second
local armed            -- { path, at }: the book a first tap is waiting on

-- A tap on a book in a list: opens it, or with "double tap to open" on, the
-- first tap arms it and the second one opens it.
function Actions.tapBook(path)
    if not Settings.get("double_tap_open", false) then return Actions.open(path) end
    local now = os.time()
    if armed and armed.path == path and now - armed.at <= TAP_AGAIN then
        armed = nil
        return Actions.open(path)
    end
    armed = { path = path, at = now }
    App.toast(_("TAP AGAIN TO OPEN"))
end

-- Take the book out of the reading history (the file stays).
function Actions.unhistory(path)
    require("readhistory"):removeItemByPath(path)
    App.toast(_("Removed from history"))
    App.update()
end

-- Show the book's dossier.
function Actions.details(path)
    App.push("dossier", { path = path })
end

-- Set the reading status ("new" for unread, "reading", "complete", "abandoned").
function Actions.setStatus(path, status)
    Actions.writeStatus(path, status)
    App.update()
end

-- Save a status in the book's details without redrawing.
function Actions.writeStatus(path, status)
    local DocSettings = require("docsettings")
    local ds = DocSettings:open(path)
    local summary = ds:readSetting("summary") or {}
    summary.status = status
    filemanagerutil.saveSummary(ds, summary)
    Books.forget(path)
end

-- The four statuses a book can be given, with their names.
Actions.STATUSES = {
    { "new", _("Unread") }, { "reading", _("Reading") }, { "abandoned", _("On hold") }, { "complete", _("Done") },
}

-- The name of a status as the status sheet shows it.
function Actions.statusName(status)
    for _i, s in ipairs(Actions.STATUSES) do
        if s[1] == status then return s[2] end
    end
    return status
end

-- Let the reader choose any status for the book.
function Actions.statusSheet(path)
    local current = Books.state(path).status
    local options = {}
    for _i, s in ipairs(Actions.STATUSES) do
        options[#options + 1] = { label = s[2], checked = s[1] == current, on_tap = function() Actions.setStatus(path, s[1]) end }
    end
    App.choose({ title = _("Status"), options = options })
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
            App.toast(string.format(_("Added to %s"), name))
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
    local keep = Trash.KEEP_DAYS
    App.confirm({
        title = string.format(_("Delete \u{201C}%s\u{201D}?"), Files.name(path)),
        text = is_dir and string.format(_.n("The folder and everything in it go. It waits in the trash for %d day.",
            "The folder and everything in it go. It waits in the trash for %d days.", keep), keep)
            or string.format(_.n("It waits in the trash for %d day.", "It waits in the trash for %d days.", keep), keep),
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

-- Make the library open in this folder (nil: back to the home folder).
function Actions.setLibraryStart(dir)
    Settings.save("library_start_dir", dir)
    App.toast(dir and string.format(_("Library opens in %s"), Files.name(dir)) or _("Library opens in the home folder"))
    App.update()
end

-- Choose a folder in a picker that starts at the home; o: { title, label (the
-- button), icon, on_pick(dir) }.
function Actions.pickFolder(o)
    App.push("library", { dir = Library.home(), pick = {
        title = o.title, label = o.label, icon = o.icon,
        on_pick = function(dir)
            App.pop()
            o.on_pick(dir)
        end,
    } })
end

-- Choose the folder the library opens in.
function Actions.pickLibraryStart()
    Actions.pickFolder({ title = _("Library opens in"), label = _("Open library here"), icon = "library", on_pick = Actions.setLibraryStart })
end

---------------------------------------------------------------- many books at once

-- Give every book of `paths` a status; after() runs once all have it.
function Actions.setStatusMany(paths, status, after)
    for _i, p in ipairs(paths) do Actions.writeStatus(p, status) end
    App.toast(string.format(_.n("%d book marked %s", "%d books marked %s", #paths), #paths, Actions.statusName(status)))
    if after then after() end
end

-- Choose the status for every book of `paths`.
function Actions.statusSheetMany(paths, after)
    local options = {}
    for _i, s in ipairs(Actions.STATUSES) do
        options[#options + 1] = { label = s[2], on_tap = function() Actions.setStatusMany(paths, s[1], after) end }
    end
    App.choose({ title = string.format(_.n("Status of %d book", "Status of %d books", #paths), #paths), options = options })
end

-- Put every book of `paths` in a collection (one chosen, or a new one).
function Actions.collectMany(paths, after)
    local function add(name)
        for _i, p in ipairs(paths) do
            if not Collections.has(p, name) then Collections.toggle(p, name) end
        end
        App.toast(string.format(_.n("%d book added to %s", "%d books added to %s", #paths), #paths, Collections.title(name)))
        if after then after() end
    end
    local options = {}
    for _i, c in ipairs(Collections.list()) do
        options[#options + 1] = { label = c.title, on_tap = function() add(c.name) end }
    end
    options[#options + 1] = { label = _("New collection"), icon = "plus", on_tap = function()
        App.input(_("New collection"), "", function(name)
            name = util.trim(name or "")
            if name == "" then return end
            Collections.create(name)
            add(name)
        end, _("Create"))
    end }
    App.choose({ title = string.format(_.n("Add %d book to", "Add %d books to", #paths), #paths), options = options })
end

-- Move every book of `paths` into a folder chosen in the picker.
function Actions.moveMany(paths, after)
    Actions.pickFolder({ title = _("Move to"), label = _("Move here"), icon = "move", on_pick = function(dir)
        for _i, p in ipairs(paths) do
            local _to, err = Files.moveInto(p, dir)
            if err then return failed(err) end
        end
        App.toast(string.format(_.n("%d book moved to %s", "%d books moved to %s", #paths), #paths, Files.name(dir)))
        if after then after() end
    end })
end

-- Send every book of `paths` to the trash after asking once.
function Actions.deleteMany(paths, after)
    App.confirm({
        title = string.format(_.n("Delete %d book?", "Delete %d books?", #paths), #paths),
        text = string.format(_.n("They wait in the trash for %d day.", "They wait in the trash for %d days.", Trash.KEEP_DAYS), Trash.KEEP_DAYS),
        ok = _("Delete"),
        on_ok = function()
            for _i, p in ipairs(paths) do
                local ok, err = Trash.put(p)
                if not ok then return failed(err) end
            end
            App.toast(_("Moved to the trash"))
            if after then after() end
        end,
    })
end

-- The hold sheet of a book.
function Actions.bookSheet(path)
    local info, st = Books.info(path), Books.state(path)
    local actions = {
        { icon = "forward", label = _("Open"), on_tap = function() Actions.open(path) end },
        { icon = "eye", label = _("Details"), on_tap = function() Actions.details(path) end },
        { icon = "check", label = _("Status"), sub = Actions.statusName(st.status), on_tap = function() Actions.statusSheet(path) end },
        { icon = "collections", label = _("Collections"), on_tap = function() Actions.collect(path) end },
        { icon = "edit", label = _("Rename"), on_tap = function() Actions.rename(path) end },
        { icon = "move", label = _("Move to"), on_tap = function() Actions.move(path) end },
        { icon = "trash", label = _("Delete"), danger = true, on_tap = function() Actions.delete(path) end },
    }
    if History.lastOpened(path) then
        table.insert(actions, 5, { icon = "history", label = _("Forget"), sub = _("Remove from history"), on_tap = function() Actions.unhistory(path) end })
    end
    App.sheet({ title = info.title, sub = filemanagerutil.abbreviate(Files.parent(path)), actions = actions })
end

-- The hold sheet of a folder; `open` goes into it.
function Actions.folderSheet(path, open)
    App.sheet({ title = Files.name(path), sub = filemanagerutil.abbreviate(Files.parent(path)), actions = {
        { icon = "folder", label = _("Open"), on_tap = open },
        { icon = "home", label = _("Make library home"), on_tap = function() Actions.makeHome(path) end },
        { icon = "library", label = _("Open library here"), on_tap = function() Actions.setLibraryStart(path) end },
        { icon = "edit", label = _("Rename"), on_tap = function() Actions.rename(path) end },
        { icon = "move", label = _("Move to"), on_tap = function() Actions.move(path) end },
        { icon = "trash", label = _("Delete"), danger = true, on_tap = function() Actions.delete(path) end },
    } })
end

return Actions
