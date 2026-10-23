-- KOReader's drop-down menu in CyberUI's style: the same tabs and items as
-- KOReader's own (every setting and every plugin's entries, read live from
-- its menu tree, never copied), with the same behaviour: checkmarks, greyed
-- out items, submenus, long-press help, and menus that stay open or close.
-- Item actions get a stand-in for KOReader's menu so their own dialogs can
-- refresh or close it later.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Deco = require("cyberui/ui/deco")
local Frame = require("cyberui/screens/frame")
local Grid = require("cyberui/ui/grid")
local Header = require("cyberui/ui/header")
local Icon = require("cyberui/ui/icon")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Screen = require("cyberui/screens/screen")
local StatusBar = require("cyberui/ui/statusbar")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local MenuScreen = Screen:extend()

-- KOReader's tab icons as CyberUI icons and names; tabs other plugins add
-- with their own icons show as EXTRA.
local TABS = {
    ["appbar.filebrowser"] = { "files", _("FILES") },
    ["appbar.settings"] = { "settings", _("SETTINGS") },
    ["appbar.tools"] = { "pen", _("TOOLS") },
    ["appbar.search"] = { "search", _("SEARCH") },
    ["appbar.menu"] = { "menu", _("MAIN") },
    ["appbar.navigation"] = { "book", _("NAVIGATION") },
    ["appbar.typeset"] = { "edit", _("TYPESET") },
    ["appbar.pageview"] = { "eye", _("VIEW") },
}

local EXTRA = { "grid", _("EXTRA") }

-- An item's text now.
local function textOf(item)
    local t = item.text_func and item.text_func() or item.text
    return t and tostring(t) or ""
end

-- Is an item usable now?
local function enabled(item)
    if item.enabled_func then return item.enabled_func() ~= false end
    return item.enabled ~= false
end

-- An item's submenu now, or nil.
local function submenu(item)
    return item.sub_item_table_func and item.sub_item_table_func() or item.sub_item_table
end

-- The file browser's menu, its item tree built if needed.
local function fmMenu()
    local fm = require("apps/filemanager/filemanager").instance
    local m = fm and fm.menu
    if m and not m.tab_item_table then m:setUpdateItemTable() end
    return m
end

-- Can the styled menu be shown now?
function MenuScreen.available()
    local m = fmMenu()
    return m ~= nil and m.tab_item_table ~= nil and #m.tab_item_table > 0
end

-- Open on the tab KOReader's menu last showed.
function MenuScreen:init()
    self.tabs = fmMenu().tab_item_table
    self.tab = math.max(1, math.min(G_reader_settings:readSetting("filemanagermenu_tab_index") or 1, #self.tabs))
    self.items = self.tabs[self.tab]
    self.stack = {}   -- { items, title, page } of the menus above
    self.trail = {}
    self.page = 1
    local screen = self
    -- what item actions call on "the menu"
    self.shim = {
        item_table = self.items,
        updateItems = function() if App.current() == screen then App.update() end end,
        closeMenu = function() screen:close() end,
        backToUpperMenu = function() screen:up() end,
        onClose = function() screen:close() end,
    }
end

-- Leave the menu (if it is still showing).
function MenuScreen:close()
    if App.current() == self then App.pop() end
end

-- Show another of KOReader's tabs.
function MenuScreen:switchTab(i)
    local tab = self.tabs[i]
    if tab.callback then tab.callback() end
    if #tab == 0 then return end
    self.tab, self.items, self.stack, self.trail, self.page = i, tab, {}, {}, 1
    self.shim.item_table = tab
    if tab.remember ~= false then G_reader_settings:saveSetting("filemanagermenu_tab_index", i) end
    App.update()
end

-- Go into a submenu.
function MenuScreen:down(items, title)
    self.stack[#self.stack + 1] = { items = self.items, page = self.page }
    self.trail[#self.trail + 1] = title
    self.items, self.page = items, 1
    self.shim.item_table = items
    App.update()
end

-- Back to the menu above; false at the top.
function MenuScreen:up()
    local top = table.remove(self.stack)
    if not top then return false end
    table.remove(self.trail)
    self.items, self.page = top.items, top.page
    self.shim.item_table = top.items
    App.update()
    return true
end

-- Back goes up a menu before leaving.
function MenuScreen:onBack()
    return self:up()
end

-- Ask for text with CyberUI's keyboard for an item that wants input.
local function askInput(input)
    App.input(input.title or "", input.input_func and input.input_func() or input.input or "", function(text)
        if input.allow_blank_input or (text and text ~= "") then input.callback(text) end
    end, input.ok_text or _("OK"), { placeholder = input.hint_func and input.hint_func() or input.hint })
end

-- A tap on an item, as KOReader's menu handles it.
function MenuScreen:select(item)
    if item.tap_input or item.tap_input_func then
        if not item.keep_menu_open then self:close() end
        return askInput(item.tap_input or item.tap_input_func())
    end
    local sub = submenu(item)
    if sub then
        if #sub > 0 then self:down(sub, textOf(item)) end
        return
    end
    local callback = item.callback_func and item.callback_func() or item.callback
    if not callback then return end
    callback(self.shim)
    if item.checked ~= nil or item.checked_func then
        if not (item.check_callback_updates_menu or item.check_callback_closes_menu) then self.shim.updateItems() end
    elseif not item.keep_menu_open then
        self:close()
    end
end

-- A long press on an item: its own action, else its help.
function MenuScreen:hold(item)
    if item.hold_input or item.hold_input_func then
        if item.hold_keep_menu_open == false then self:close() end
        return askInput(item.hold_input or item.hold_input_func())
    end
    local hold = item.hold_callback_func and item.hold_callback_func() or item.hold_callback
    if hold then
        if item.hold_keep_menu_open == false then self:close() end
        return hold(self.shim, item)
    end
    local help = item.help_text_func and item.help_text_func(self.shim) or item.help_text
    App.confirm({ title = textOf(item), text = help or textOf(item), ok = _("OK") })
end

-- One item: a checkbox when it has one, its text, and a chevron for submenus.
function MenuScreen:row(item, w, h)
    local th = Theme.get()
    local on = enabled(item)
    local kids = {}
    if item.checked_func or item.checked ~= nil then
        local checked = item.checked_func and item.checked_func() or item.checked
        kids[#kids + 1] = Panel:new({ shape = item.radio and "brackets" or "frame", width = Theme.px(24), height = Theme.px(24),
            child = checked and Icon:new({ name = "check", size = 18, color = on and "ink" or "muted" }) or Layout.Spacer:new({}) })
    end
    kids[#kids + 1] = Label:new({ text = textOf(item), kind = "body", color = on and "ink" or "muted", grow = true })
    if item.sub_item_table or item.sub_item_table_func then
        kids[#kids + 1] = Icon:new({ name = "forward", size = 20, color = on and "ink" or "muted" })
    end
    return Layout.Column:new({ width = w, height = h, children = {
        Panel:new({ shape = "none", grow = true, pad = { 0, th.space.s },
            on_tap = on and function() self:select(item) end or nil,
            on_hold = function() self:hold(item) end,
            child = Layout.Row:new({ gap = th.space.m, children = kids }) }),
        Deco.Divider:new({ height = item.separator and Theme.px(3) or nil }),
    } })
end

-- Build: status bar, header with the path, KOReader's tabs, one page of items.
function MenuScreen:build()
    local th = Theme.get()
    local side = th.space.xl
    local status, clock = StatusBar.build()
    self.clock = clock
    local tab_buttons = {}
    for i, tab in ipairs(self.tabs) do
        local look = TABS[tab.icon] or EXTRA
        tab_buttons[i] = Button:new({ icon = look[1], variant = i == self.tab and "icon_on" or "icon", grow = true,
            height = Theme.px(44), on_tap = function() self:switchTab(i) end })
    end
    local name = (TABS[self.tabs[self.tab].icon] or EXTRA)[2]
    local path = "KOREADER // " .. name
    for _i, t in ipairs(self.trail) do path = path .. " > " .. t:upper() end
    local title = #self.trail > 0 and self.trail[#self.trail] or name
    local items = {}
    for _i, item in ipairs(self.items) do
        if not item.hidden_func or not item.hidden_func() then items[#items + 1] = item end
    end
    return Layout.Column:new({ pad = { th.space.s, side, th.space.m, side }, gap = th.space.m, children = {
        status,
        Header.build({ title = title, path = path, on_back = function() App.back() end,
            actions = { Button:new({ icon = "close", variant = "icon", width = th.size.touch, on_tap = function() App.pop() end }) } }),
        Layout.Row:new({ gap = th.space.s, children = tab_buttons }),
        Grid:new({ grow = true, items = items, page = self.page, cols = 1, cell_h = Theme.px(52), row_gap = 0,
            make = function(item, w, h) return self:row(item, w, h) end,
            on_layout = function(_c, pages, page) self.pages, self.page = pages, page end }),
        Frame.pager(self, _("PAGE"), function(p) self:setPage(p) end),
    } })
end

return MenuScreen
