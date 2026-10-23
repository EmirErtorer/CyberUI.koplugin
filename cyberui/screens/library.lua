-- The book browser: a folder of the library, a collection or search results,
-- shown as a paged grid or list with reading-state filters and sorting.
-- Tap a book to read it, hold it for its dossier, tap a folder to go in.

local Actions = require("cyberui/actions")
local App = require("cyberui/app")
local BookTile = require("cyberui/ui/booktile")
local Books = require("cyberui/data/books")
local Button = require("cyberui/ui/button")
local Collections = require("cyberui/data/collections")
local Data = require("cyberui/data/library")
local Frame = require("cyberui/screens/frame")
local Grid = require("cyberui/ui/grid")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local ListRow = require("cyberui/ui/listrow")
local Screen = require("cyberui/screens/screen")
local Settings = require("cyberui/settings")
local Theme = require("cyberui/theme")
local ffiUtil = require("ffi/util")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local util = require("util")
local _ = require("gettext")

local Library = Screen:extend()

-- Names shown for the filters and sort orders.
local FILTER_NAMES = { all = _("All"), reading = _("Reading"), unread = _("Unread"), done = _("Done") }
local SORT_NAMES = { recent = _("Recent"), title = _("Title"), author = _("Author"), added = _("Added") }

-- Start on the first page with every book shown.
function Library:init()
    self.page = 1
    self.filter = "all"
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
    local dir = ffiUtil.realpath(p.dir or Data.home()) or p.dir or Data.home()
    local l = Data.list(dir)
    local parent, name = util.splitFilePathName(dir)
    local at_home = dir == (ffiUtil.realpath(Data.home()) or Data.home())
    return l.folders, l.books, at_home and _("Library") or name, filemanagerutil.abbreviate(at_home and dir or parent)
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

-- Pick the sort order.
function Library:chooseSort()
    local current = Settings.get("library_sort", "recent")
    local options = {}
    for _i, s in ipairs(Data.SORTS) do
        options[#options + 1] = { label = SORT_NAMES[s], checked = s == current, on_tap = function()
            Settings.save("library_sort", s); self.page = 1; App.render("ui")
        end }
    end
    App.choose({ title = _("Sort by"), options = options })
end

-- One grid cell or list row for a folder or a book.
function Library:cell(item, w, h, as_list)
    if item.folder then
        local open = function() App.push("library", { dir = item.folder.path }) end
        if as_list then
            return ListRow.build({ icon = "folder", title = item.folder.name, meta = _("FOLDER"), height = h, on_tap = open })
        end
        return BookTile.folder(item.folder, w, h, #Data.list(item.folder.path).books, open)
    end
    local p = item.path
    local open, hold = function() Actions.open(p) end, function() Actions.details(p) end
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

-- Build the browser.
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

    local as_list = Settings.get("library_view", "grid") == "list"
    local body_kids = {}
    local top = self:topRow()
    if top then body_kids[#body_kids + 1] = top end
    body_kids[#body_kids + 1] = self:filterRow(counts)
    if #items == 0 then
        body_kids[#body_kids + 1] = Label:new({ grow = true, text = self.params.query and _("NO MATCHES") or _("NO FILES HERE"),
            kind = "title", color = "muted", align = "center" })
    else
        body_kids[#body_kids + 1] = Grid:new({
            grow = true, items = items, page = self.page,
            cols = as_list and 1 or nil, min_cell_w = Theme.px(120), cell_h = as_list and Theme.px(56) or nil, ratio = 1.72,
            row_gap = as_list and 0 or th.space.l,
            make = function(item, w, h) return self:cell(item, w, h, as_list) end,
            on_layout = function(_cap, pages, page) self.pages, self.page = pages, page end,
        })
    end
    body_kids[#body_kids + 1] = Frame.pager(self, _("SECTOR"), function(p) self:setPage(p) end)

    local actions = {
        Button:new({ label = _("Sort: ") .. SORT_NAMES[Settings.get("library_sort", "recent")], kind = "mono_small",
            on_tap = function() self:chooseSort() end }),
    }
    if not self.params.query then
        table.insert(actions, 1, Button:new({ icon = "search", variant = "icon", width = th.size.touch,
            on_tap = function() App.push("search") end }))
    end
    return Frame.page({
        screen = self, title = title, path = path, actions = actions,
        tab = self.params.collection and "collections" or "library",
        body = Layout.Column:new({ gap = th.space.m, children = body_kids }),
    })
end

return Library
