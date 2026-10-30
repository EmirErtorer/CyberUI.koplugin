-- The library explorer: the folders and books of the library (or a
-- collection, or search results) as a paged grid or list, with reading-state
-- filters. Folders open in place, with a breadcrumb bar to go back up; tap a
-- book to read it, hold anything for its actions; "+ New" makes folders and
-- the menu holds sorting, the view, the trash and KOReader's file browser.
-- With `pick` it only shows folders, to choose where something moves.

local Actions = require("cyberui/actions")
local App = require("cyberui/app")
local BookTile = require("cyberui/ui/booktile")
local Books = require("cyberui/data/books")
local Button = require("cyberui/ui/button")
local Cover = require("cyberui/ui/cover")
local Collections = require("cyberui/data/collections")
local Data = require("cyberui/data/library")
local Files = require("cyberui/data/files")
local Frame = require("cyberui/screens/frame")
local Grid = require("cyberui/ui/grid")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local ListRow = require("cyberui/ui/listrow")
local Panel = require("cyberui/ui/panel")
local Screen = require("cyberui/screens/screen")
local Settings = require("cyberui/settings")
local Theme = require("cyberui/theme")
local Trash = require("cyberui/data/trash")
local _ = require("gettext")

local Library = Screen:extend()

-- Names shown for the filters and sort orders.
local FILTER_NAMES = { all = _("All"), reading = _("Reading"), unread = _("Unread"), done = _("Done") }
local SORT_NAMES = { recent = _("Recent"), title = _("Title"), author = _("Author"), added = _("Added") }

-- The library's top folder.
local function home()
    return Data.home()
end

-- Start on the first page with every book shown; folders keep a trail of
-- the ones opened, so Back goes up before it leaves.
function Library:init(params)
    self.page = 1
    self.filter = "all"
    if not (params.collection or params.query) then
        self.trail = { ((params.dir or home()):gsub("(.)/+$", "%1")) }
    end
end

-- The folder shown, or nil for a collection or search.
function Library:dir()
    return self.trail and self.trail[#self.trail]
end

-- Open folder `dir` in place.
function Library:go(dir)
    self.trail[#self.trail + 1] = dir
    self.page, self.filter = 1, "all"
    App.render("ui")
end

-- Go back to the trail's `n`th folder (a breadcrumb tap).
function Library:goTo(n)
    for i = #self.trail, n + 1, -1 do self.trail[i] = nil end
    self.page, self.filter = 1, "all"
    App.render("ui")
end

-- Back goes up a folder first; true when it did.
function Library:onBack()
    if self.trail and #self.trail > 1 then
        self:goTo(#self.trail - 1)
        return true
    end
    return false
end

-- What this browser shows: folders, books, title and the small path line.
function Library:source()
    local p = self.params
    if p.collection then
        return {}, Collections.books(p.collection), Collections.title(p.collection), "/SYS/CACHES/"
    end
    if p.query then
        return {}, Data.search(p.query), _("Search"), "/GREP/"
    end
    -- every book of every folder in one list, when the reader chose it
    if Settings.get("library_flat", false) and not p.dir and not p.pick then
        return {}, Data.all(), _("All books"), nil
    end
    local dir = self:dir()
    local l = Data.list(dir)
    local folders = l.folders
    if p.pick then
        -- a folder being moved cannot go into itself
        folders = {}
        for _i, f in ipairs(l.folders) do if f.path ~= p.pick.moving then folders[#folders + 1] = f end end
        return folders, {}, p.pick.title, Files.name(p.pick.moving)
    end
    return folders, l.books, dir == home() and _("Library") or Files.name(dir), nil
end

-- The breadcrumb bar: each folder of the trail from the library home.
function Library:breadcrumbs()
    local th = Theme.get()
    local kids = {}
    local base = self.trail[1]
    local first = base == home() and _("Library") or Files.name(base)
    for i, dir in ipairs(self.trail) do
        if i > 1 then kids[#kids + 1] = Label:new({ text = "/", kind = "mono", color = "muted" }) end
        local current = i == #self.trail
        kids[#kids + 1] = Button:new({ label = i == 1 and first or Files.name(dir), kind = "mono_small",
            variant = current and "chip_on" or "seg", height = Theme.px(34),
            on_tap = not current and function() self:goTo(i) end or nil })
    end
    -- the end of a deep trail matters most: drop the oldest crumbs that do not fit
    local row = Layout.Row:new({ gap = th.space.xs, children = kids })
    row.clip_start = true
    return Panel:new({ shape = "chamfer", corners = "r", cut = "cut_small", pad = { th.space.xs, th.space.s }, child = row })
end

-- The filter chips and the grid / list switch.
function Library:filterRow(counts)
    local th = Theme.get()
    local kids = {}
    for _i, f in ipairs(Data.FILTERS) do
        kids[#kids + 1] = Button:new({
            label = FILTER_NAMES[f], sub = tostring(counts[f] or 0), variant = f == self.filter and "chip_on" or "chip",
            height = Theme.px(46), on_tap = function() self.filter = f; self.page = 1; App.update() end,
        })
    end
    kids[#kids + 1] = Layout.Spacer:new({ grow = true })
    local grid = Settings.get("library_view", "grid") == "grid"
    local function view(v) return function() Settings.save("library_view", v); self.page = 1; App.render("ui") end end
    kids[#kids + 1] = Button:new({ icon = "grid", variant = grid and "icon_on" or "icon", width = Theme.px(40), height = Theme.px(40), on_tap = view("grid") })
    kids[#kids + 1] = Button:new({ icon = "list", variant = grid and "icon" or "icon_on", width = Theme.px(40), height = Theme.px(40), on_tap = view("list") })
    return Layout.Row:new({ gap = th.space.s, children = kids })
end

-- The menu: sort order, the trash and KOReader's file browser.
function Library:menu()
    local current = Settings.get("library_sort", "recent")
    local actions = {}
    for _i, s in ipairs(Data.SORTS) do
        actions[#actions + 1] = { icon = s == current and "check" or "sort", label = SORT_NAMES[s], on_tap = function()
            Settings.save("library_sort", s); self.page = 1; App.render("ui")
        end }
    end
    local flat = Settings.get("library_flat", false)
    actions[#actions + 1] = { icon = flat and "check" or "files", label = _("All books"), sub = _("No folders, every book"),
        on_tap = function() Settings.save("library_flat", not flat); self.page = 1; App.render("ui") end }
    actions[#actions + 1] = { icon = "trash", label = _("Trash"), sub = string.format(_("%d waiting"), Trash.count()),
        on_tap = function() App.push("trash") end }
    local dir = self:dir()
    actions[#actions + 1] = { icon = "files", label = _("KOReader browser"), sub = _("The stock file browser"), on_tap = function()
        App.fileBrowser()
        local fm = require("apps/filemanager/filemanager").instance
        if fm and dir then fm.file_chooser:changeToPath(dir) end
    end }
    App.sheet({ title = _("Sort and more"), actions = actions })
end

-- The + New sheet (folders today; the tiles say what each thing is).
function Library:newSheet()
    local dir = self:dir()
    App.sheet({ title = string.format(_("New in %s"), dir == home() and _("Library") or Files.name(dir)), cols = 1, actions = {
        { icon = "folder", label = _("Folder"), sub = _("To keep books together"),
            on_tap = function() Actions.newFolder(dir, function() App.update() end) end },
    } })
end

-- One grid cell or list row for a folder or a book.
function Library:cell(item, w, h, as_list)
    if item.folder then
        local path = item.folder.path
        local open = function() self:go(path) end
        local hold = not self.params.pick and function() Actions.folderSheet(path, open) end or nil
        if as_list then
            return ListRow.build({ icon = "folder", title = item.folder.name, meta = _("FOLDER"), height = h,
                on_tap = open, on_hold = hold })
        end
        local inside = Data.list(path).books
        local tile = BookTile.folder(item.folder, w, h, #inside, open, inside[1])
        tile.on_hold = hold
        return tile
    end
    local p = item.path
    local open, hold = function() Actions.tapBook(p) end, function() Actions.bookSheet(p) end
    if as_list then
        local info = Books.info(p)
        return ListRow.build({ path = p, title = info.title, meta = info.author, value = (Books.badge(p)),
            height = h, on_tap = open, on_hold = hold })
    end
    return BookTile.build(p, w, h, { on_tap = open, on_hold = hold })
end

-- Extra row above the grid (search uses it for the query field).
function Library:topRow()
    return nil
end

-- The header buttons for each mode.
function Library:actions()
    local th = Theme.get()
    if self.params.pick then
        return { Button:new({ label = _("+ Folder"), variant = "chip", on_tap = function()
            Actions.newFolder(self:dir(), function() App.update() end) end }) }
    end
    local list = {}
    if not self.params.query then
        list[#list + 1] = Button:new({ icon = "search", variant = "icon", width = th.size.touch, on_tap = function() App.push("search") end })
    end
    if self:dir() then
        list[#list + 1] = Button:new({ label = _("+ New"), variant = "primary", corners = "r", on_tap = function() self:newSheet() end })
    end
    list[#list + 1] = Button:new({ icon = "menu", variant = "icon", width = th.size.touch, on_tap = function() self:menu() end })
    return list
end

-- Build the explorer.
function Library:build()
    local th = Theme.get()
    local folders, books, title, path = self:source()
    books = Data.sort(books, Settings.get("library_sort", "recent"))
    local shown, counts = Data.filter(books, self.filter)
    local items = {}
    if self.filter == "all" then
        for _i, f in ipairs(folders) do items[#items + 1] = { folder = f } end
    end
    for _i, p in ipairs(shown) do items[#items + 1] = { path = p } end

    local pick = self.params.pick
    local as_list = pick ~= nil or Settings.get("library_view", "grid") == "list"
    local body_kids = {}
    local top = self:topRow()
    if top then body_kids[#body_kids + 1] = top end
    if self.trail then body_kids[#body_kids + 1] = self:breadcrumbs() end
    if not pick then body_kids[#body_kids + 1] = self:filterRow(counts) end
    if #items == 0 then
        local empty = pick and _("No folders here. Make one with + Folder, or move it here.")
            or self.params.query and _("NO MATCHES") or _("Nothing here yet. Copy books in, or make a folder with + New.")
        body_kids[#body_kids + 1] = Label:new({ grow = true, text = empty, kind = "body", color = "muted", align = "center", lines = 3 })
    else
        body_kids[#body_kids + 1] = Grid:new({
            grow = true, items = items, page = self.page,
            cols = as_list and 1 or nil, min_cell_w = Theme.px(Cover.SIZES[Settings.get("cover_size", "m")] or 120), cell_h = as_list and Theme.px(56) or nil, ratio = 1.72,
            row_gap = as_list and 0 or th.space.l,
            make = function(item, w, h) return self:cell(item, w, h, as_list) end,
            on_layout = function(_cap, pages, page) self.pages, self.page = pages, page end,
        })
    end
    body_kids[#body_kids + 1] = Frame.pager(self, _("SECTOR"), function(p) self:setPage(p) end)
    if pick then
        body_kids[#body_kids + 1] = Button:new({ label = _("Move here"), icon = "move", variant = "primary", corners = "tb",
            on_tap = function() pick.on_pick(self:dir()) end })
    end
    return Frame.page({
        screen = self, title = title, path = path, actions = self:actions(),
        tab = self.params.collection and "collections" or "library",
        body = Layout.Column:new({ gap = th.space.m, children = body_kids }),
    })
end

return Library
