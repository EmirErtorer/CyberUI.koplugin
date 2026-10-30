-- The library's menu and the sheets behind it: sort and its direction, how
-- books are grouped, the extra filters, saved views, jumping to a letter and
-- selecting books. Everything is kept in the settings, so the library opens
-- the way it was left.

local App = require("cyberui/app")
local Collections = require("cyberui/data/collections")
local Data = require("cyberui/data/library")
local Groups = require("cyberui/data/libgroups")
local Settings = require("cyberui/settings")
local Trash = require("cyberui/data/trash")
local _ = require("cyberui/gettext")

local LibMenu = {}

-- Names shown for the sort orders.
LibMenu.SORT_NAMES = {
    recent = _("Recent"), title = _("Title"), author = _("Author"), series = _("Series"), added = _("Added"),
    progress = _("Progress"), pages = _("Pages"), size = _("Size"),
}

-- The grouping now in use: a chosen one, else all books when the older
-- "all books" switch was on, else the folders.
function LibMenu.group()
    return Settings.get("library_group") or (Settings.get("library_flat", false) and "all") or "folder"
end

-- The name of a grouping.
function LibMenu.groupName(id)
    for _i, g in ipairs(Groups.KINDS) do
        if g[1] == id then return g[2] end
    end
    return id
end

-- Keep a setting and show the library again from its top.
local function apply(lib, key, value)
    Settings.save(key, value)
    lib:reshow()
end

-- Sort order and direction.
local function sortSheet(lib)
    local current, desc = Settings.get("library_sort", "recent"), Settings.get("library_desc", false)
    local options = {}
    for _i, s in ipairs(Data.SORTS) do
        options[#options + 1] = { label = LibMenu.SORT_NAMES[s], checked = s == current, on_tap = function() apply(lib, "library_sort", s) end }
    end
    options[#options + 1] = { label = _("Reverse order"), icon = "sort", checked = desc, on_tap = function() apply(lib, "library_desc", not desc) end }
    App.choose({ title = _("Sort"), cols = 2, options = options })
end

-- How the library is grouped.
local function groupSheet(lib)
    local options = {}
    for _i, g in ipairs(Groups.KINDS) do
        options[#options + 1] = { label = g[2], checked = g[1] == LibMenu.group(), on_tap = function()
            Settings.save("library_flat", nil)
            apply(lib, "library_group", g[1])
        end }
    end
    App.choose({ title = _("Group by"), options = options })
end

-- Change one extra filter (nil clears it).
local function setExtra(lib, key, value)
    local f = {}
    for k, v in pairs(Settings.get("library_extra", {})) do f[k] = v end
    f[key] = value
    apply(lib, "library_extra", f)
end

-- The extra filters: format, collection and books with notes.
local function filterSheet(lib)
    local f = Settings.get("library_extra", {})
    local options = {
        { label = _("Format"), sub = f.format or _("Any"), icon = "files", on_tap = function()
            local formats = { { label = _("Any"), checked = f.format == nil, on_tap = function() setExtra(lib, "format", nil) end } }
            for _i, fmt in ipairs(Groups.formats()) do
                formats[#formats + 1] = { label = fmt, checked = f.format == fmt, on_tap = function() setExtra(lib, "format", fmt) end }
            end
            App.choose({ title = _("Format"), cols = 2, options = formats })
        end },
        { label = _("Collection"), sub = f.collection and Collections.title(f.collection) or _("Any"), icon = "collections", on_tap = function()
            local list = { { label = _("Any"), checked = f.collection == nil, on_tap = function() setExtra(lib, "collection", nil) end } }
            for _i, c in ipairs(Collections.list()) do
                list[#list + 1] = { label = c.title, checked = f.collection == c.name, on_tap = function() setExtra(lib, "collection", c.name) end }
            end
            App.choose({ title = _("Collection"), options = list })
        end },
        { label = _("With notes"), sub = f.annotated and _("Only books with highlights or notes") or _("Any"), icon = "notes",
            on_tap = function() setExtra(lib, "annotated", (not f.annotated) or nil) end },
    }
    if Groups.filtering(f) then
        options[#options + 1] = { label = _("Clear filters"), icon = "close", on_tap = function() apply(lib, "library_extra", {}) end }
    end
    App.choose({ title = _("Filters"), options = options })
end

-- The view as one table, to save or to compare.
local function currentView(lib)
    return { sort = Settings.get("library_sort", "recent"), desc = Settings.get("library_desc", false), group = LibMenu.group(),
        view = Settings.get("library_view", "grid"), extra = Settings.get("library_extra", {}), filter = lib.filter }
end

-- Show the library the way a saved view says.
local function useView(lib, v)
    Settings.set("library_sort", v.sort)
    Settings.set("library_desc", v.desc)
    Settings.set("library_group", v.group)
    Settings.set("library_view", v.view)
    Settings.set("library_extra", v.extra or {})
    Settings.set("library_flat", nil)
    Settings.flush()
    lib:reroot()
    lib.filter = v.filter or "all"
    App.render("ui")
end

-- Saved views: use one, save the current one, or delete one.
local function viewsSheet(lib)
    local views = Settings.get("library_views", {})
    local options = {}
    for _i, v in ipairs(views) do
        options[#options + 1] = { label = v.name, sub = string.format("%s // %s", LibMenu.groupName(v.group), LibMenu.SORT_NAMES[v.sort] or v.sort),
            on_tap = function() useView(lib, v) end }
    end
    options[#options + 1] = { label = _("Save this view"), icon = "plus", on_tap = function()
        App.input(_("Name this view"), "", function(name)
            name = (name or ""):match("^%s*(.-)%s*$")
            if name == "" then return end
            local v = currentView(lib)
            v.name = name
            local list = {}
            for _i, old in ipairs(views) do if old.name ~= name then list[#list + 1] = old end end
            list[#list + 1] = v
            Settings.save("library_views", list)
            App.toast(_("View saved"))
        end, _("Save"))
    end }
    if #views > 0 then
        options[#options + 1] = { label = _("Delete a view"), icon = "trash", on_tap = function()
            local del = {}
            for i, v in ipairs(views) do
                del[#del + 1] = { label = v.name, on_tap = function()
                    local list = {}
                    for j, w in ipairs(views) do if j ~= i then list[#list + 1] = w end end
                    Settings.save("library_views", list)
                    App.toast(_("View deleted"))
                end }
            end
            App.choose({ title = _("Delete a view"), options = del })
        end }
    end
    App.choose({ title = _("Saved views"), options = options })
end

-- Jump to the books starting with a letter (for title and author orders).
local function jumpSheet(lib)
    local options = {}
    for c = string.byte("A"), string.byte("Z") do
        local letter = string.char(c)
        options[#options + 1] = { label = letter, on_tap = function() lib:jump(letter) end }
    end
    App.choose({ title = _("Jump to"), cols = 6, options = options })
end

-- The menu.
function LibMenu.open(lib)
    local sort = Settings.get("library_sort", "recent")
    local f = Settings.get("library_extra", {})
    local actions = {
        { icon = "sort", label = _("Sort"), sub = LibMenu.SORT_NAMES[sort] .. (Settings.get("library_desc", false) and " \u{2193}" or ""),
            on_tap = function() sortSheet(lib) end },
        { icon = "grid", label = _("Group by"), sub = LibMenu.groupName(LibMenu.group()), on_tap = function() groupSheet(lib) end },
        { icon = "controls", label = _("Filters"), sub = Groups.filtering(f) and _("On") or _("Off"), on_tap = function() filterSheet(lib) end },
        { icon = "bookmark", label = _("Saved views"), sub = string.format(_.n("%d saved", "%d saved", #Settings.get("library_views", {})), #Settings.get("library_views", {})),
            on_tap = function() viewsSheet(lib) end },
        { icon = "search", label = _("Jump to letter"), sub = _("A to Z in the current order"), on_tap = function() jumpSheet(lib) end },
        { icon = "check", label = _("Select books"), sub = _("Status, collections, move or delete many"), on_tap = function() lib:startSelect() end },
        { icon = "trash", label = _("Trash"), sub = string.format(_.n("%d waiting", "%d waiting", Trash.count()), Trash.count()), on_tap = function() App.push("trash") end },
    }
    local dir = lib:dir()
    actions[#actions + 1] = { icon = "files", label = _("KOReader browser"), sub = _("The stock file browser"), on_tap = function()
        App.fileBrowser()
        local fm = require("apps/filemanager/filemanager").instance
        if fm and dir then fm.file_chooser:changeToPath(dir) end
    end }
    App.sheet({ title = _("Library"), actions = actions })
end

return LibMenu
