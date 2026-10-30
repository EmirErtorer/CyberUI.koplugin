-- The library explorer: the folders and books of the library (or a
-- collection, or search results) as a paged grid or list, with reading-state
-- filters. Folders open in place, with a breadcrumb bar to go back up; tap a
-- book to read it, hold anything for its actions; "+ New" makes folders and
-- the menu (screens/libmenu.lua) holds sorting, grouping, filters, saved
-- views and selecting. Grouped by author, series and so on, each group is a
-- virtual folder. With `pick` it only shows folders, to choose where
-- something moves.

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
local Groups = require("cyberui/data/libgroups")
local Label = require("cyberui/ui/label")
local LibMenu = require("cyberui/screens/libmenu")
local Layout = require("cyberui/ui/layout")
local ListRow = require("cyberui/ui/listrow")
local Panel = require("cyberui/ui/panel")
local Screen = require("cyberui/screens/screen")
local Settings = require("cyberui/settings")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

local Library = Screen:extend()

-- Names shown for the filters.
local FILTER_NAMES = { all = _("All"), reading = _("Reading"), unread = _("Unread"), done = _("Done") }

local VIRTUAL = "@group:"   -- trail entries that are groups, not folders

-- The library's top folder.
local function home()
    return Data.home()
end

-- Start on the first page with every book shown; folders keep a trail of
-- the ones opened, so Back goes up before it leaves.
function Library:init()
    self.selected = {}
    self:reroot()
end

-- Are books shown in groups (author, series...) instead of folders?
function Library:grouped()
    local p = self.params
    return not (p.dir or p.pick or p.collection or p.query) and LibMenu.group() ~= "folder"
end

-- Back to the top of the library: where it opens, or the folder it was given.
function Library:reroot()
    local params = self.params
    self.page, self.filter = 1, "all"
    if params.collection or params.query then return end
    if params.dir then
        self.trail = { ((params.dir):gsub("(.)/+$", "%1")) }
    else
        self.trail = self:grouped() and { home() } or Data.startTrail()
    end
end

-- Show the top of the library again (a grouping or view changed).
function Library:reshow()
    self:reroot()
    App.render("ui")
end

-- The folder shown, or nil for a collection, search or group.
function Library:dir()
    local last = self.trail and self.trail[#self.trail]
    if not last or last:sub(1, #VIRTUAL) == VIRTUAL or self:grouped() then return nil end
    return last
end

-- The name a trail entry shows: a group's name, else the folder's.
function Library:crumbName(entry)
    if entry:sub(1, #VIRTUAL) == VIRTUAL then return self.group_names and self.group_names[entry] or entry:sub(#VIRTUAL + 1) end
    return Files.name(entry)
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

-- Back goes up a folder first; true when it did (a selection ends first).
function Library:onBack()
    if self.selecting then
        self:endSelect()
        return true
    end
    if self.trail and #self.trail > 1 then
        self:goTo(#self.trail - 1)
        return true
    end
    return false
end

-- What a grouped library shows: every book for "all", else the groups as
-- virtual folders and, inside one, its books.
function Library:groupSource()
    local kind = LibMenu.group()
    if kind == "all" then return {}, Data.all(), _("All books"), nil end
    self.group_names = self.group_names or {}
    local last = self.trail[#self.trail]
    if last:sub(1, #VIRTUAL) == VIRTUAL then
        return {}, Groups.books(kind, last:sub(#VIRTUAL + 1)), self.group_names[last] or "", nil
    end
    local folders = {}
    for _i, g in ipairs(Groups.list(kind)) do
        local path = VIRTUAL .. g.key
        self.group_names[path] = g.name
        folders[#folders + 1] = { name = g.name, path = path, virtual = true, count = g.count, first = g.first }
    end
    return folders, {}, LibMenu.groupName(kind), nil
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
    if self:grouped() then return self:groupSource() end
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
    local first = self:grouped() and LibMenu.groupName(LibMenu.group()) or (base == home() and _("Library") or Files.name(base))
    for i, dir in ipairs(self.trail) do
        if i > 1 then kids[#kids + 1] = Label:new({ text = "/", kind = "mono", color = "muted" }) end
        local current = i == #self.trail
        kids[#kids + 1] = Button:new({ label = i == 1 and first or self:crumbName(dir), kind = "mono_small",
            variant = current and "chip_on" or "seg", height = Theme.px(34),
            on_tap = not current and function() self:goTo(i) end or nil })
    end
    -- the end of a deep trail matters most: drop the oldest crumbs that do not fit
    local row = Layout.Row:new({ gap = th.space.xs, children = kids })
    row.clip_start = true
    return Panel:new({ shape = "chamfer", corners = "r", cut = "cut_small", pad = { th.space.xs, th.space.s }, child = row })
end

-- The filter chips, the extra filters button and the grid / list switch.
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

-- The menu (sort, group, filters, views, jump, select, trash).
function Library:menu()
    LibMenu.open(self)
end

-- The + New sheet (folders today; the tiles say what each thing is).
function Library:newSheet()
    local dir = self:dir()
    App.sheet({ title = string.format(_("New in %s"), dir == home() and _("Library") or Files.name(dir)), cols = 1, actions = {
        { icon = "folder", label = _("Folder"), sub = _("To keep books together"),
            on_tap = function() Actions.newFolder(dir, function() App.update() end) end },
    } })
end

-- Jump to the first book whose title (or author, in the author order)
-- starts with `letter`.
function Library:jump(letter)
    local by_author = Settings.get("library_sort", "recent") == "author"
    for i, item in ipairs(self.items or {}) do
        if item.path then
            local info = Books.info(item.path)
            local text = by_author and info.author or info.title
            if text and text:upper():sub(1, 1) == letter then
                self:setPage(math.ceil(i / math.max(1, self.capacity or 1)))
                return
            end
        end
    end
    App.toast(string.format(_("Nothing starts with %s here"), letter))
end

---------------------------------------------------------------- selecting

-- Start picking books for a batch action.
function Library:startSelect()
    self.selecting, self.selected = true, {}
    App.render("ui")
end

-- Stop picking.
function Library:endSelect()
    self.selecting, self.selected = false, {}
    App.render("ui")
end

-- The picked books, in the order shown.
function Library:picked()
    local out = {}
    for _i, item in ipairs(self.items or {}) do
        if item.path and self.selected[item.path] then out[#out + 1] = item.path end
    end
    return out
end

-- Pick every book shown, or none when all are picked already.
function Library:toggleAll()
    local all = true
    for _i, item in ipairs(self.items or {}) do
        if item.path and not self.selected[item.path] then all = false end
    end
    for _i, item in ipairs(self.items or {}) do
        if item.path then self.selected[item.path] = (not all) or nil end
    end
    App.update()
end

-- The bar of batch actions under the grid while picking.
function Library:selectBar()
    local th = Theme.get()
    local picked = self:picked()
    local function act(label, fn)
        return Button:new({ label = label, variant = "chip", grow = true, height = Theme.px(44), on_tap = function()
            if #picked == 0 then return App.toast(_("Pick some books first")) end
            fn(picked, function() self:endSelect() end)
        end })
    end
    return Layout.Column:new({ gap = th.space.xs, children = {
        Layout.Row:new({ gap = th.space.s, children = {
            Label:new({ text = string.format(_.n("%d PICKED", "%d PICKED", #picked), #picked), kind = "mono", grow = true }),
            Button:new({ label = _("ALL"), variant = "chip", height = Theme.px(36), on_tap = function() self:toggleAll() end }),
            Button:new({ label = _("DONE"), variant = "chip_on", height = Theme.px(36), on_tap = function() self:endSelect() end }),
        } }),
        Layout.Row:new({ gap = th.space.xs, children = {
            act(_("STATUS"), Actions.statusSheetMany), act(_("CACHE +"), Actions.collectMany),
            act(_("MOVE"), Actions.moveMany), act(_("DELETE"), Actions.deleteMany),
        } }),
    } })
end

---------------------------------------------------------------- cells

-- A tap on a book: pick it while selecting, else open it.
function Library:tapBook(p)
    if self.selecting then
        self.selected[p] = (not self.selected[p]) or nil
        App.update()
    else
        Actions.tapBook(p)
    end
end

-- One grid cell or list row for a folder or a book.
function Library:cell(item, w, h, as_list)
    if item.folder then
        local f = item.folder
        local path = f.path
        local open = function() self:go(path) end
        local hold = not (self.params.pick or f.virtual) and function() Actions.folderSheet(path, open) end or nil
        if as_list then
            return ListRow.build({ icon = "folder", title = f.name, meta = f.virtual and string.format(_.n("%d BOOK", "%d BOOKS", f.count), f.count) or _("FOLDER"),
                height = h, on_tap = open, on_hold = hold })
        end
        local inside = not f.virtual and Data.list(path).books
        local tile = BookTile.folder(f, w, h, f.virtual and f.count or #inside, open, f.virtual and f.first or inside[1])
        tile.on_hold = hold
        return tile
    end
    local p = item.path
    local open, hold = function() self:tapBook(p) end, function() Actions.bookSheet(p) end
    local on = self.selected[p]
    if as_list then
        local info = Books.info(p)
        return ListRow.build({ path = p, title = info.title, meta = info.author,
            value = self.selecting and (on and _("[X]") or _("[ ]")) or Books.badge(p),
            value_color = on and "accent" or nil, height = h, on_tap = open, on_hold = hold })
    end
    if self.selecting then
        return BookTile.build(p, w, h, { on_tap = open, on_hold = hold, badge = on and _("PICKED") or _("TAP"), badge_on = on })
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
    books = Groups.filter(books, Settings.get("library_extra", {}))
    books = Data.sort(books, Settings.get("library_sort", "recent"), Settings.get("library_desc", false))
    local shown, counts = Data.filter(books, self.filter)
    local items = {}
    if self.filter == "all" then
        for _i, f in ipairs(folders) do items[#items + 1] = { folder = f } end
    end
    for _i, p in ipairs(shown) do items[#items + 1] = { path = p } end
    self.items = items

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
            on_layout = function(cap, pages, page) self.capacity, self.pages, self.page = cap, pages, page end,
        })
    end
    body_kids[#body_kids + 1] = Frame.pager(self, _("SECTOR"), function(p) self:setPage(p) end)
    if self.selecting then body_kids[#body_kids + 1] = self:selectBar() end
    if pick then
        body_kids[#body_kids + 1] = Button:new({ label = pick.label or _("Move here"), icon = pick.icon or "move", variant = "primary", corners = "tb",
            on_tap = function() pick.on_pick(self:dir()) end })
    end
    return Frame.page({
        screen = self, title = title, path = path, actions = self:actions(),
        tab = self.params.collection and "collections" or "library",
        body = Layout.Column:new({ gap = th.space.m, children = body_kids }),
    })
end

return Library
