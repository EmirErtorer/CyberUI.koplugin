-- KOReader's lists in CyberUI's style: the table of contents, the bookmarks
-- and highlights, history, collections, and every other list a plugin makes
-- with KOReader's Menu. KOReader keeps the items, what a tap or a hold on one
-- does, and what happens to the list as items change; the list only shows the
-- page of them the screen has room for. File browsers are left to KOReader.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")

local Screen = Device.screen

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

-- One item as a list row.
local function row(menu, item, index)
    local ListRow = require("cyberui/ui/listrow")
    local Menu = require("ui/widget/menu")
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    item.idx = index
    local mandatory = item.mandatory_func and item.mandatory_func() or item.mandatory
    local built = ListRow.build({
        title = Menu.getMenuText(item), value = mandatory ~= nil and tostring(mandatory) or nil,
        value_color = (item.mandatory_dim or item.dim) and "muted" or "ink", dim = item.dim,
        title_kind = (menu.item_table.current == index or item.bold) and "title" or nil,
        path = type(item.file) == "string" and item.file or nil,
        on_tap = function() menu:onMenuSelect(item) end,
        on_hold = function() menu:onMenuHold(item) end,
    })
    local indent = tonumber(item.indent)
    if indent and indent > 0 then
        built = Layout.Row:new({ children = { Layout.Spacer:new({ width = math.min(Theme.px(60), indent) }), built } })
        built.children[2].grow = true
    end
    return built
end

-- The whole list as it is now, on page `page` of the ones the screen holds.
local function page(menu, state)
    local Button = require("cyberui/ui/button")
    local Dialog = require("cyberui/ui/dialog")
    local Header = require("cyberui/ui/header")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Panel = require("cyberui/ui/panel")
    local StatusBar = require("cyberui/ui/statusbar")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    local th = Theme.get()
    local side = th.space.xl
    local items = menu.item_table
    local row_h = Theme.px(54)
    local room = Screen:getHeight() - 2 * th.space.s - 4 * th.size.touch - 2 * th.space.m
    local per = math.max(3, math.floor(room / row_h))
    local pages = math.max(1, math.ceil(#items / per))
    state.page = math.max(1, math.min(state.page or math.ceil(startIndex(menu) / per), pages))
    local rows = {}
    for i = (state.page - 1) * per + 1, math.min(state.page * per, #items) do rows[#rows + 1] = row(menu, items[i], i) end
    local status = StatusBar.build()
    local actions = {}
    if menu.title_bar_left_icon and menu.onLeftButtonTap then
        actions[1] = Button:new({ icon = "menu", variant = "icon", width = th.size.touch, on_tap = function() menu:onLeftButtonTap() end })
    end
    local back = (menu.onReturn and menu.paths and #menu.paths > 0) and function() menu:onReturn() end or function() menu:onClose() end
    local kids = {
        status,
        Header.build({ title = tostring(menu.title or ""), path = menu.subtitle and tostring(menu.subtitle) or nil, on_back = back, actions = actions }),
    }
    if #rows == 0 then
        kids[#kids + 1] = Label:new({ text = _("No items"), kind = "body", color = "muted", align = "center", grow = true })
    else
        kids[#kids + 1] = Layout.Column:new({ grow = true, children = rows })
    end
    if pages > 1 then
        kids[#kids + 1] = Dialog.pager(state.page, pages, function(p)
            state.page = p
            if state.redraw then state.redraw() end
        end)
    end
    return Panel:new({ shape = "none", fill = "bg", pad = { th.space.s, side, th.space.m, side }, width = Screen:getWidth(), height = Screen:getHeight(),
        child = Layout.Column:new({ gap = th.space.m, children = kids }) })
end

Core.register({
    name = "list",
    matches = function(widget) return menuOf(widget) ~= nil end,
    present = function(widget)
        local menu = menuOf(widget)
        local state = {}
        state.redraw = function() Core.redraw(widget, page(menu, state)) end
        -- KOReader changes the items and the page: the list follows
        for _i, name in ipairs({ "updateItems", "switchItemTable" }) do
            local stock = menu[name]
            menu[name] = function(self, ...)
                local r = stock(self, ...)
                if name == "switchItemTable" then state.page = nil end
                if widget._cyber_popup then state.redraw() end
                return r
            end
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
