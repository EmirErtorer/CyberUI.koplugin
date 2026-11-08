-- KOReader's lists in CyberUI's style: the table of contents, the bookmarks
-- and highlights, history, collections, and every other list a plugin makes
-- with KOReader's Menu. KOReader keeps the items, what a tap or a hold on one
-- does, and what happens to the list as items change; the list only shows the
-- page of them the screen has room for. File browsers are left to KOReader, but the
-- window for choosing a folder gets a button for choosing the one it is in.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")

local Skin = {}

-- The Menu a widget is, or holds as its first part (the table of contents is a menu in a container).
local function menuOf(widget)
    local function is(w) return type(w) == "table" and Anatomy.is(w, "ui/widget/menu") and type(w.item_table) == "table" end
    local menu = is(widget) and widget or (is(widget[1]) and widget[1]) or nil
    -- the file browser is KOReader's (CyberUI has its own library); choosing a folder is a list like any other
    if menu and Anatomy.is(menu, "ui/widget/filechooser") and not Anatomy.is(menu, "ui/widget/pathchooser") then return nil end
    return menu
end

-- The index of the item the list should open at: the current one, else the page KOReader shows.
local function startIndex(menu)
    local t = menu.item_table
    return t.current or (menu.itemnumber and menu.itemnumber > 0 and menu.itemnumber)
        or (((menu.page or 1) - 1) * (menu.perpage or 1) + 1)
end

-- The mark of an item that opens and closes (a chapter with sub-chapters): which way it points
-- is read from KOReader's own button for it.
local function mark(item)
    local icon = type(item.state) == "table" and item.state.icon or ""
    if icon:find("collapse", 1, true) then return "\u{25BE}" end
    return icon:find("expand", 1, true) and "\u{25B8}" or "\u{25E6}"
end

-- Saved items (the bookmarks list) show their kind by an icon: KOReader gives each item a `type`.
local KIND_ICONS = { highlight = "pen", note = "notes", bookmark = "bookmark" }   -- i18n: keep

-- What a saved item says: the passage (or the note, for a note), and under it where it is.
local function savedItem(item)
    local title = (item.type == "note" and item.note) or item.text_orig or item.text or ""
    local meta = {}
    if item.chapter and item.chapter ~= "" then meta[#meta + 1] = item.chapter end
    if item.datetime then meta[#meta + 1] = item.datetime:match("^%S+") or item.datetime end
    return title, #meta > 0 and table.concat(meta, " // ") or nil
end

-- The row KOReader's folder chooser adds for the folder it is in ("long-press to choose it"): a
-- visible button does that here, so the row is not shown.
local function currentFolderRow(menu, item)
    return menu.select_directory and menu.show_current_dir_for_hold and type(item.path) == "string" and item.path:sub(-2) == "/."
end

-- Is this item of a table of contents (a chapter with a depth and a page)?
local function chapter(item)
    return item.page ~= nil and item.depth ~= nil
end

-- One item as a list row. A tap on the title chooses the item; KOReader tells a tap on the
-- opening mark from one on the title by where the tap fell (as it does for its own rows), so the
-- mark sends the left edge and the title the middle.
local function row(menu, item, index)
    local Button = require("cyberui/ui/button")
    local ListRow = require("cyberui/ui/listrow")
    local Menu = require("ui/widget/menu")
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    item.idx = index
    local mandatory = item.mandatory_func and item.mandatory_func() or item.mandatory
    local current = menu.item_table.current
    local title, meta = Menu.getMenuText(item), nil
    local icon = KIND_ICONS[item.type]
    if icon then title, meta = savedItem(item) end
    -- (a file shows the cover CyberUI draws for it, in the reader's chosen cover style; a folder an icon)
    local chosen = not icon and type(item.path) == "string" and Anatomy.is(menu, "ui/widget/filechooser")
    if chosen and not item.is_file then icon = "folder" end
    -- in a table of contents, the chapters already passed are dimmed and the one you are in is marked
    local passed = chapter(item) and current and index < current
    local built = ListRow.build({
        title = title, meta = meta, icon = icon, value = mandatory ~= nil and tostring(mandatory) or nil,
        value_color = (item.mandatory_dim or item.dim or passed) and "muted" or "ink", dim = item.dim or passed,
        title_kind = (current == index or item.bold) and "title" or nil,
        path = (not icon and (type(item.file) == "string" and item.file or (chosen and item.is_file and item.path))) or nil,
        on_tap = function() menu:onMenuSelect(item, { x = 0.5, y = 0.5 }) end,
        on_hold = function() menu:onMenuHold(item) end,
    })
    built.grow = true
    -- the chapter you are in has a bar in the accent colour down its left edge
    if chapter(item) and current == index then
        local Panel = require("cyberui/ui/panel")
        built = Panel:new({ shape = "rail", line = "accent", pad = { 0, 0, 0, Theme.px(14) }, grow = true, child = built })
    end
    local parts = {}
    local indent = tonumber(item.indent)
    if indent and indent > 0 then parts[#parts + 1] = Layout.Spacer:new({ width = math.min(Theme.px(60), indent) }) end
    if item.state then
        parts[#parts + 1] = Button:new({ label = mark(item), variant = "tab", kind = "title", width = Theme.get().size.touch,
            on_tap = function() menu:onMenuSelect(item, { x = 0, y = 0.5 }) end })
    end
    parts[#parts + 1] = built   -- (in a row always: `grow` of the row's content is about its width, never its height)
    return Layout.Row:new({ children = parts })
end

-- What the window says it is: KOReader's title of a folder chooser ("Long-press folder's name to
-- choose it") is about a way of choosing the button here makes plain, so it says what the window is for.
local function titleOf(menu)
    local title = tostring(menu.title or "")
    local gettext = require("gettext")
    local _ = require("cyberui/gettext")
    if menu.select_directory and not menu.select_file and title == gettext("Long-press folder's name to choose it") then
        return _("Choose a folder")
    end
    return title
end

-- The items to show, as { item, index in KOReader's list } pairs.
local function visible(menu)
    local out = {}
    for i, item in ipairs(menu.item_table) do
        if not currentFolderRow(menu, item) then out[#out + 1] = { item, i } end
    end
    return out
end

-- Under the list: what a list can do beyond its rows. Choosing the folder that is open is
-- the one thing a folder chooser is for, so it gets a button.
local function footer(menu)
    local Specs = require("cyberui/skin/specs")
    local _ = require("cyberui/gettext")
    if not (menu.select_directory and menu.show_current_dir_for_hold and menu.onMenuHold and menu.path) then return {} end
    return { Specs.wide({ text = _("Choose this folder"), is_enter_default = true,
        callback = function() menu:onMenuHold({ path = menu.path .. "/." }) end }, nil, "check") }
end

-- The whole list as it is now, on page `page` of the ones the screen holds.
local function page(menu, state)
    local Button = require("cyberui/ui/button")
    local Fullpage = require("cyberui/skin/fullpage")
    local Theme = require("cyberui/theme")
    local th = Theme.get()
    local items = visible(menu)
    local extra = footer(menu)
    local row_h = Theme.px(54)
    local per = math.max(3, math.floor(Fullpage.room(#extra) / row_h))
    local pages = math.max(1, math.ceil(#items / per))
    -- a folder chooser that went into another folder starts at its first page
    if state.path ~= menu.path then state.path, state.page = menu.path, nil end
    local first = 1
    for k, pair in ipairs(items) do if pair[2] >= startIndex(menu) then first = k; break end end
    state.page = math.max(1, math.min(state.page or math.ceil(first / per), pages))
    local rows = {}
    for k = (state.page - 1) * per + 1, math.min(state.page * per, #items) do rows[#rows + 1] = row(menu, items[k][1], items[k][2]) end
    local actions = {}
    if menu.title_bar_left_icon and menu.onLeftButtonTap then
        actions[1] = Button:new({ icon = menu.title_bar_left_icon == "home" and "home" or "menu", variant = "icon", width = th.size.touch,
            on_tap = function() menu:onLeftButtonTap() end, on_hold = menu.onLeftButtonHold and function() menu:onLeftButtonHold() end or nil })
    end
    local back = (menu.onReturn and menu.paths and #menu.paths > 0) and function() menu:onReturn() end or function() menu:onClose() end
    return Fullpage.build({
        title = titleOf(menu), path = menu.subtitle and tostring(menu.subtitle) or (#extra > 0 and menu.path) or nil, on_back = back, actions = actions,
        rows = rows, page = state.page, pages = pages, footer = extra, show = function(p)
            state.page = p
            if state.redraw then state.redraw() end
        end,
    })
end

Core.register({
    name = "list",
    matches = function(widget) return menuOf(widget) ~= nil end,
    present = function(widget)
        local menu = menuOf(widget)
        local state = {}
        state.redraw = function() Core.redraw(widget, page(menu, state)) end
        -- KOReader changes the items and the page: the list follows
        local update_items, switch = menu.updateItems, menu.switchItemTable
        menu.updateItems = function(self, ...)
            local r = update_items(self, ...)
            if widget._cyber_popup then state.redraw() end
            return r
        end
        -- a new list starts on its first page (or the current item's); the same list changed (a chapter opened) stays
        menu.switchItemTable = function(self, new_title, ...)
            local before = self.title
            local r = switch(self, new_title, ...)
            if new_title ~= nil and new_title ~= before then state.page = nil end
            if widget._cyber_popup then state.redraw() end
            return r
        end
        return {
            element = page(menu, state),
            place = function() return 0, 0 end,
            on_outside = function() end,
            on_back = function() menu:onClose(); return true end,
            on_swipe = function(dir)
                if dir == "west" then state.page = (state.page or 1) + 1 elseif dir == "east" then state.page = (state.page or 1) - 1 else return end
                state.redraw()
            end,
        }
    end,
})

return Skin
