-- KOReader's lists in CyberUI's style: the table of contents, the bookmarks
-- and highlights, history, collections, and every other list a plugin makes
-- with KOReader's Menu. KOReader keeps the items, what a tap or a hold on one
-- does, and what happens to the list as items change; the list only shows the
-- page of them the screen has room for. File browsers are left to KOReader.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")

local Skin = {}

-- The Menu a widget is, or holds as its first part (the table of contents is a menu in a container).
local function menuOf(widget)
    local function is(w) return type(w) == "table" and Anatomy.is(w, "ui/widget/menu") and type(w.item_table) == "table" end
    local menu = is(widget) and widget or (is(widget[1]) and widget[1]) or nil
    if menu and Anatomy.is(menu, "ui/widget/filechooser") then return nil end
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
    -- in a table of contents, the chapters already passed are dimmed and the one you are in is marked
    local passed = chapter(item) and current and index < current
    local built = ListRow.build({
        title = title, meta = meta, icon = icon, value = mandatory ~= nil and tostring(mandatory) or nil,
        value_color = (item.mandatory_dim or item.dim or passed) and "muted" or "ink", dim = item.dim or passed,
        title_kind = (current == index or item.bold) and "title" or nil,
        path = (not icon and type(item.file) == "string") and item.file or nil,
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

-- The whole list as it is now, on page `page` of the ones the screen holds.
local function page(menu, state)
    local Button = require("cyberui/ui/button")
    local Fullpage = require("cyberui/skin/fullpage")
    local Theme = require("cyberui/theme")
    local th = Theme.get()
    local items = menu.item_table
    local row_h = Theme.px(54)
    local per = math.max(3, math.floor(Fullpage.room() / row_h))
    local pages = math.max(1, math.ceil(#items / per))
    state.page = math.max(1, math.min(state.page or math.ceil(startIndex(menu) / per), pages))
    local rows = {}
    for i = (state.page - 1) * per + 1, math.min(state.page * per, #items) do rows[#rows + 1] = row(menu, items[i], i) end
    local actions = {}
    if menu.title_bar_left_icon and menu.onLeftButtonTap then
        actions[1] = Button:new({ icon = "menu", variant = "icon", width = th.size.touch, on_tap = function() menu:onLeftButtonTap() end })
    end
    local back = (menu.onReturn and menu.paths and #menu.paths > 0) and function() menu:onReturn() end or function() menu:onClose() end
    return Fullpage.build({
        title = tostring(menu.title or ""), path = menu.subtitle and tostring(menu.subtitle) or nil, on_back = back, actions = actions,
        rows = rows, page = state.page, pages = pages, show = function(p)
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
