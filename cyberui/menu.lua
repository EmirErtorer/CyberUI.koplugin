-- KOReader's drop-down menu in CyberUI's style: a panel that drops from the
-- top edge over the screen, sized to its items between 30% and 50% of the
-- screen height (paged beyond that); a tap below it closes it. It shows the
-- same tabs and items as KOReader's own (every setting and every plugin's
-- entries, read live from its menu tree, never copied), with the same
-- behaviour: checkmarks, greyed out items, submenus, long-press help, and
-- menus that stay open or close. Item actions get a stand-in for KOReader's
-- menu so their own dialogs can refresh or close it later.

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
local Theme = require("cyberui/theme")
local _ = require("gettext")

local Menu = {}
Menu.__index = Menu

-- The panel's height as a share of the screen.
local MIN_H, MAX_H = 0.3, 0.5

-- KOReader's tab icons as CyberUI icons and names; tabs other plugins add
-- with their own icons show as EXTRA.
local TABS = {
    ["appbar.filebrowser"] = { "files", _("FILES") },
    ["appbar.settings"] = { "settings", _("SETTINGS") },
    ["appbar.tools"] = { "tools", _("TOOLS") },
    ["appbar.search"] = { "search", _("SEARCH") },
    ["appbar.menu"] = { "menu", _("MAIN") },
    ["appbar.navigation"] = { "book", _("NAVIGATION") },
    ["appbar.typeset"] = { "edit", _("TYPESET") },
    ["appbar.pageview"] = { "eye", _("VIEW") },
}
local EXTRA = { "grid", _("EXTRA") }

local showing   -- the open menu

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
function Menu.available()
    local m = fmMenu()
    return m ~= nil and m.tab_item_table ~= nil and #m.tab_item_table > 0
end

-- The open menu, or nil (it may have been closed by a tap below it).
function Menu.current()
    if showing and App.overlay() == showing.panel then return showing end
    return nil
end

-- Drop the menu down on the tab KOReader's menu last showed.
function Menu.open()
    local tabs = fmMenu().tab_item_table
    local m = setmetatable({ tabs = tabs, stack = {}, trail = {}, page = 1 }, Menu)
    m.tab = math.max(1, math.min(G_reader_settings:readSetting("filemanagermenu_tab_index") or 1, #tabs))
    m.items = tabs[m.tab]
    -- what item actions call on "the menu"
    m.shim = {
        item_table = m.items,
        updateItems = function() if Menu.current() == m then m:show() end end,
        closeMenu = function() m:close() end,
        backToUpperMenu = function() m:up() end,
        onClose = function() m:close() end,
    }
    showing = m
    m:show()
    return m
end

-- Draw (or redraw) the panel.
function Menu:show()
    App.dialog(function(close, w) return self:build(close, w) end)
end

-- Close the menu if it is still open.
function Menu:close()
    if Menu.current() == self then App.closeDialog() end
    if showing == self then showing = nil end
end

-- Show another of KOReader's tabs.
function Menu:switchTab(i)
    local tab = self.tabs[i]
    if tab.callback then tab.callback() end
    if #tab == 0 then return end
    self.tab, self.items, self.stack, self.trail, self.page = i, tab, {}, {}, 1
    self.shim.item_table = tab
    if tab.remember ~= false then G_reader_settings:saveSetting("filemanagermenu_tab_index", i) end
    self:show()
end

-- Go into a submenu.
function Menu:down(items, title)
    self.stack[#self.stack + 1] = { items = self.items, page = self.page }
    self.trail[#self.trail + 1] = title
    self.items, self.page = items, 1
    self.shim.item_table = items
    self:show()
end

-- Back to the menu above; false at the top.
function Menu:up()
    local top = table.remove(self.stack)
    if not top then return false end
    table.remove(self.trail)
    self.items, self.page = top.items, top.page
    self.shim.item_table = top.items
    self:show()
    return true
end

-- Ask for text with CyberUI's keyboard for an item that wants input.
local function askInput(input)
    App.input(input.title or "", input.input_func and input.input_func() or input.input or "", function(text)
        if input.allow_blank_input or (text and text ~= "") then input.callback(text) end
    end, input.ok_text or _("OK"), { placeholder = input.hint_func and input.hint_func() or input.hint })
end

-- A tap on an item, as KOReader's menu handles it.
function Menu:select(item)
    if item.tap_input or item.tap_input_func then
        self:close()
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

-- A long press on an item: its own action, else its help (then back to the menu).
function Menu:hold(item)
    if item.hold_input or item.hold_input_func then
        self:close()
        return askInput(item.hold_input or item.hold_input_func())
    end
    local hold = item.hold_callback_func and item.hold_callback_func() or item.hold_callback
    if hold then
        if item.hold_keep_menu_open == false then self:close() end
        return hold(self.shim, item)
    end
    local help = item.help_text_func and item.help_text_func(self.shim) or item.help_text
    local back = function() if showing == self then self:show() end end
    App.confirm({ title = textOf(item), text = help or textOf(item), ok = _("OK"), on_ok = back, on_cancel = back })
end

-- One item: a checkbox when it has one, its text, and a chevron for submenus.
function Menu:row(item, w, h)
    local th = Theme.get()
    local on = enabled(item)
    local kids = {}
    if item.checked_func or item.checked ~= nil then
        local checked = item.checked_func and item.checked_func() or item.checked
        kids[#kids + 1] = Panel:new({ shape = item.radio and "brackets" or "frame", width = Theme.px(22), height = Theme.px(22),
            child = checked and Icon:new({ name = "check", size = 16, color = on and "ink" or "muted" }) or Layout.Spacer:new({}) })
    end
    kids[#kids + 1] = Label:new({ text = textOf(item), kind = "body", color = on and "ink" or "muted", grow = true })
    if item.sub_item_table or item.sub_item_table_func then
        kids[#kids + 1] = Icon:new({ name = "forward", size = 18, color = on and "ink" or "muted" })
    end
    return Layout.Column:new({ width = w, height = h, children = {
        Panel:new({ shape = "none", grow = true, pad = { 0, th.space.s },
            on_tap = on and function() self:select(item) end or nil,
            on_hold = function() self:hold(item) end,
            child = Layout.Row:new({ gap = th.space.m, children = kids }) }),
        Deco.Divider:new({ height = item.separator and Theme.px(3) or nil }),
    } })
end

-- The items to list (hidden ones left out).
function Menu:visible()
    local out = {}
    for _i, item in ipairs(self.items) do
        if not item.hidden_func or not item.hidden_func() then out[#out + 1] = item end
    end
    return out
end

-- Build the panel: header with the path, KOReader's tabs, one page of items.
function Menu:build(_close, screen_w)
    local th = Theme.get()
    local Screen = require("device").screen
    local screen_h = Screen:getHeight()
    local row_h, header_h, tabs_h = Theme.px(46), Theme.px(56), Theme.px(42)
    local gap, pad = th.space.s, th.space.m
    local items = self:visible()
    -- as tall as the items need, between the limits; a pager when they do not fit
    local fixed = header_h + tabs_h + 2 * gap + 2 * pad + Theme.px(3)
    local want = fixed + #items * row_h
    local h = math.floor(math.max(screen_h * MIN_H, math.min(screen_h * MAX_H, want)))
    local paged = want > h

    local tab_buttons = {}
    for i, tab in ipairs(self.tabs) do
        local look = TABS[tab.icon] or EXTRA
        tab_buttons[i] = Button:new({ icon = look[1], variant = i == self.tab and "icon_on" or "icon", grow = true,
            height = tabs_h, on_tap = function() self:switchTab(i) end })
    end
    local name = (TABS[self.tabs[self.tab].icon] or EXTRA)[2]
    local path = "KOREADER // " .. name
    for _i, t in ipairs(self.trail) do path = path .. " > " .. t:upper() end
    local title = #self.trail > 0 and self.trail[#self.trail] or name

    local kids = {
        Header.build({ title = title, path = path, on_back = #self.trail > 0 and function() self:up() end or nil,
            actions = { Button:new({ icon = "close", variant = "icon", width = th.size.touch, on_tap = function() self:close() end }) } }),
        Layout.Row:new({ gap = gap, children = tab_buttons }),
        Grid:new({ grow = true, items = items, page = self.page, cols = 1, cell_h = row_h, row_gap = 0,
            make = function(item, w, ch) return self:row(item, w, ch) end,
            on_layout = function(_c, pages, page) self.pages, self.page = pages, page end }),
    }
    if paged then
        kids[#kids + 1] = Frame.pager(self, _("PAGE"), function(p)
            self.page = math.max(1, math.min(p, self.pages or 1))
            self:show()
        end)
    end
    local panel = Layout.Column:new({ width = screen_w, height = h, children = {
        Panel:new({ shape = "none", fill = "bg", grow = true, pad = { pad, th.space.xl, pad, th.space.xl },
            child = Layout.Column:new({ gap = gap, children = kids }) }),
        Deco.Divider:new({ color = "accent", height = Theme.px(3) }),
    } })
    panel.dock = "top"
    panel.on_back = function() return self:up() end
    self.panel = panel
    return panel
end

return Menu
