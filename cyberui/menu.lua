-- KOReader's drop-down menu in CyberUI's style: a panel that drops from the
-- top edge, sized to its items between 30% and 50% of the screen height
-- (paged beyond that); a tap below it closes it. It works over CyberUI home
-- and inside books, and shows the same tabs and items as KOReader's own
-- (every setting and every plugin's entries, read live from its menu tree,
-- never copied), with the same behaviour: checkmarks, greyed out items,
-- submenus, long-press help, and menus that stay open or close.
--
-- Tabs other plugins draw themselves (ZenOS's Controls and Launcher) are
-- built off-screen with a stand-in menu to learn their buttons and actions,
-- then shown as CyberUI buttons that run those same actions. Over home,
-- when ZenOS is not running, CyberUI's own Deck tab comes first (with ZenOS it
-- comes right after ZenOS's Controls and Launcher). The tab has two pages, in
-- the order the reader chose: the operator ID card (face, handle, rank,
-- eddies) and the controls (frontlight, Wi-Fi, night mode, rotation, restart
-- and exit, with the device at a glance). Swipe sideways or tap a page name.

local Device = require("device")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Deco = require("cyberui/ui/deco")
local DeviceInfo = require("cyberui/data/device")
local Format = require("cyberui/format")
local Frame = require("cyberui/screens/frame")
local Grid = require("cyberui/ui/grid")
local Header = require("cyberui/ui/header")
local Icon = require("cyberui/ui/icon")
local IdCard = require("cyberui/ui/idcard")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Settings = require("cyberui/settings")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

local Screen = Device.screen

local Menu = {}
Menu.__index = Menu

-- The panel's height as a share of the screen.
local MIN_H, MAX_H = 0.3, 0.5
local DECK_H = 0.7   -- the Deck tab holds the ID card, which needs more than a list does
local PICK_H = 0.9   -- a picker lists long things (every KOReader action), so it takes more room

-- KOReader's (and ZenOS's) tab icons as CyberUI icons and names; tabs other
-- plugins add with their own icons show as EXTRA.
local TABS = {
    ["appbar.filebrowser"] = { "files", _("FILES") },
    ["appbar.settings"] = { "settings", _("SETTINGS") },
    ["appbar.tools"] = { "tools", _("TOOLS") },
    ["appbar.search"] = { "search", _("SEARCH") },
    ["appbar.menu"] = { "menu", _("MAIN") },
    ["appbar.navigation"] = { "book", _("NAVIGATION") },
    ["appbar.typeset"] = { "edit", _("TYPESET") },
    ["appbar.pageview"] = { "eye", _("VIEW") },
    ["appbar.textsize"] = { "edit", _("TYPESET") },
    ["appbar.contrast"] = { "eye", _("VIEW") },
    quicksettings = { "controls", _("CONTROLS") },
    app_launcher = { "grid", _("LAUNCHER") },
    cyberui_deck = { "deck", _("DECK") },
}
local EXTRA = { "plus", _("EXTRA") }

-- A tab's icon and name, by its id first, then its icon.
local function tabLook(tab)
    if tab.id == "zen_library_home" then return { "home", _("HOME") } end
    if tab.id == "zen_ui" then
        local zen = require("cyberui/apps/addons").pluginsDir() .. "/zenos.koplugin/icons/zen_ui.svg"
        return { zen, _("ZENOS") }
    end
    return TABS[tab.id] or TABS[tab.icon] or EXTRA
end

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

-- The file browser's menu with the most entries (Project: Title adds an empty one).
function Menu.fileManagerMenu()
    local fm = require("apps/filemanager/filemanager").instance
    if not fm then return nil end
    local function entries(m) return m and m.registered_widgets and #m.registered_widgets or 0 end
    local best = fm.menu
    for _i, module in ipairs(fm) do
        if module.name == "filemanagermenu" and entries(module) > entries(best) then best = module end
    end
    return best
end

-- The file browser's menu, its item tree built if needed.
local function fmMenu()
    local m = Menu.fileManagerMenu()
    if m and not m.tab_item_table then m:setUpdateItemTable() end
    return m
end

-- Is ZenOS running? KOReader keeps each loaded plugin under its name, so an
-- installed but switched off ZenOS is not there.
function Menu.zenosRunning()
    local fm = require("apps/filemanager/filemanager").instance
    return fm ~= nil and fm.zenos ~= nil
end

-- Can the styled menu be shown over home now?
function Menu.available()
    local m = fmMenu()
    return m ~= nil and m.tab_item_table ~= nil and #m.tab_item_table > 0
end

-- The open menu, or nil (it may have been closed by a tap outside it).
function Menu.current()
    if showing and showing:isOpen() then return showing end
    return nil
end

-- The stable name of a tab: its id, else its icon, else its place.
local function tabKey(tab, i)
    return tab.id or tab.icon or tostring(i)
end

Menu.tabKey = tabKey

-- Drop the menu down. opts: { km = KOReader's menu object, reader = true
-- inside a book, pick = function(target, item) to choose an entry instead of
-- running it, pickable = function(item) to say which entries may be chosen,
-- title = the name shown for the list, quiet = true to draw nothing until `m.quiet` is cleared and `m:show()` runs }.
function Menu.open(opts)
    opts = opts or {}
    local km = opts.km or fmMenu()
    if not km.tab_item_table then km:setUpdateItemTable() end
    -- CyberUI's Deck comes first, or with ZenOS right after its Controls and
    -- Launcher (installed but switched off counts as not running)
    local want_deck = not opts.reader and not opts.pick
    local deck_at
    if want_deck then
        deck_at = 1
        if Menu.zenosRunning() then
            for i, t in ipairs(km.tab_item_table) do
                if t.id == "quicksettings" or t.id == "app_launcher" then deck_at = i + 1 end
            end
        end
    end
    local tabs = {}
    for i, t in ipairs(km.tab_item_table) do
        if i == deck_at then tabs[#tabs + 1] = { id = "cyberui_deck", deck = true } end
        tabs[#tabs + 1] = t
    end
    if deck_at and deck_at > #km.tab_item_table then tabs[#tabs + 1] = { id = "cyberui_deck", deck = true } end
    local m = setmetatable({ km = km, reader = opts.reader, pick = opts.pick, pickable = opts.pickable, title = opts.title, tabs = tabs, deck_at = deck_at, deck_page = 1, stack = {}, trail = {}, page = 1 }, Menu)
    m.tab_key = opts.reader and "readermenu_tab_index" or "filemanagermenu_tab_index"
    local last = opts.pick and 1 or opts.reader and km.last_tab_index or G_reader_settings:readSetting(m.tab_key)
    last = last or 1
    if deck_at and last >= deck_at then last = last + 1 end   -- KOReader's numbering skips the Deck
    m.tab = math.max(1, math.min(last, #tabs))
    m.items = tabs[m.tab]
    -- what item actions call on "the menu"
    m.shim = {
        item_table = m.items,
        item_width = Screen:getWidth(),
        updateItems = function() if Menu.current() == m then m:show() end end,
        closeMenu = function() m:close() end,
        backToUpperMenu = function() m:up() end,
        onClose = function() m:close() end,
    }
    showing = m
    m.quiet = opts.quiet
    m:show()
    return m
end

-- Is this menu still showing?
function Menu:isOpen()
    if self.reader then return self.popup_open == true end
    return self.panel ~= nil and App.overlay() == self.panel
end

-- Draw (or redraw) the panel: over home in CyberUI's window, over a book in
-- a popup of its own.
function Menu:show()
    if self.quiet then return end
    if not self.reader then
        App.dialog(function(close, w) return self:build(close, w) end)
        return
    end
    local panel = self:build(nil, Screen:getWidth())
    if self.popup and self.popup_open then
        self.popup:redraw(panel)
    else
        local Popup = require("cyberui/popup")
        self.popup = Popup:new({ element = panel, on_outside = function() self:close() end,
            on_back = function() return self:up() end })
        self.popup_open = true
        self.popup:open()
    end
end

-- Close the menu if it is still open.
function Menu:close()
    if self.reader then
        if self.popup and self.popup_open then
            self.popup_open = false
            self.popup:close()
        end
    elseif Menu.current() == self then
        App.closeDialog()
    end
    if showing == self then showing = nil end
end

-- Show another tab.
function Menu:switchTab(i)
    local tab = self.tabs[i]
    if tab.id == "zen_library_home" or (tab.callback and #tab == 0 and not tab.panel) then
        -- a tab that is an action (ZenOS's home, its settings page)
        self:close()
        if tab.callback then tab.callback() end
        return
    end
    if tab.callback then tab.callback() end
    self.tab, self.items, self.stack, self.trail, self.page, self.deck_page = i, tab, {}, {}, 1, 1
    self.shim.item_table = tab
    if tab.remember ~= false and not tab.deck and not self.pick then
        -- KOReader's own numbering, without the Deck
        local own = (self.deck_at and i > self.deck_at) and i - 1 or i
        if self.reader then self.km.last_tab_index = own else G_reader_settings:saveSetting(self.tab_key, own) end
    end
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

-- Ask for text for an item that wants input: CyberUI's keyboard over home,
-- KOReader's inside a book.
function Menu:askInput(input)
    local value = input.input_func and input.input_func() or input.input or ""
    if not self.reader then
        App.input(input.title or "", value, function(text)
            if input.allow_blank_input or (text and text ~= "") then input.callback(text) end
        end, input.ok_text or _("OK"), { placeholder = input.hint_func and input.hint_func() or input.hint })
        return
    end
    local InputContainer = require("ui/widget/container/inputcontainer")
    InputContainer:new({}):onInput(input)
end

-- Show a short text (an item's help).
function Menu:info(title, text)
    if not self.reader then
        local back = function() if showing == self then self:show() end end
        App.confirm({ title = title, text = text, ok = _("OK"), on_ok = back, on_cancel = back })
        return
    end
    local InfoMessage = require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new({ text = text }))
end

-- Where an item is in the tree, as { tab, trail, text } (what a launcher
-- button keeps to open it again).
function Menu:target(item)
    local trail = {}
    for i, t in ipairs(self.trail) do trail[i] = t end
    return { tab = tabKey(self.tabs[self.tab], self.tab), trail = trail, text = textOf(item) }
end

-- The index of the tab with this stable name, or nil.
function Menu:tabIndex(key)
    for i, t in ipairs(self.tabs) do
        if tabKey(t, i) == key then return i end
    end
    return nil
end

-- The shown item with this text, or nil.
function Menu:find(text)
    for _i, item in ipairs(self:visible()) do
        if textOf(item) == text then return item end
    end
    return nil
end

-- Choose the item for a picker instead of running it (unless the picker
-- says that kind of entry cannot be used).
function Menu:choose(item)
    if self.pickable and not self.pickable(item) then return App.toast(_("THAT ONE CANNOT BE USED")) end
    self:close()
    self.pick(self:target(item), item)
end

-- A tap on an item, as KOReader's menu handles it.
function Menu:select(item)
    if self.pick and not submenu(item) then return self:choose(item) end
    if item.tap_input or item.tap_input_func then
        self:close()
        return self:askInput(item.tap_input or item.tap_input_func())
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
function Menu:hold(item)
    if self.pick then return self:choose(item) end
    if item.hold_input or item.hold_input_func then
        self:close()
        return self:askInput(item.hold_input or item.hold_input_func())
    end
    local hold = item.hold_callback_func and item.hold_callback_func() or item.hold_callback
    if hold then
        if item.hold_keep_menu_open == false then self:close() end
        return hold(self.shim, item)
    end
    local help = item.help_text_func and item.help_text_func(self.shim) or item.help_text
    self:info(textOf(item), help or textOf(item))
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
    kids[#kids + 1] = Label:new({ text = textOf(item), kind = "label", color = on and "ink" or "muted", grow = true })
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

---------------------------------------------------------------- panel tabs

-- The first text found in a widget tree (a button's label), or nil.
local function textIn(w, depth)
    depth = depth or 0
    if type(w) ~= "table" or depth > 12 then return nil end
    if type(w.text) == "string" and w.text ~= "" then return w.text end
    for _i, child in ipairs(w) do
        local t = textIn(child, depth + 1)
        if t then return t end
    end
    for _i, k in ipairs({ "widget", "label_widget", "label" }) do
        local t = type(w[k]) == "table" and textIn(w[k], depth + 1)
        if t then return t end
    end
    return nil
end

-- A CyberUI icon for a ZenOS control, by words in its id or label.
local CONTROL_ICONS = {
    { "wifi", "network" }, { "night", "moon" }, { "rotat", "rotate" }, { "light", "light" },
    { "bright", "light" }, { "screenshot", "eye" }, { "restart", "restart" }, { "exit", "exit" },
    { "sleep", "power" }, { "power", "power" }, { "search", "search" }, { "usb", "move" },
    { "bluetooth", "network" }, { "file", "files" }, { "stat", "stats" }, { "zen", "settings" },
}
local function controlIcon(id, label)
    local key = ((id or "") .. " " .. (label or "")):lower()
    for _i, m in ipairs(CONTROL_ICONS) do
        if key:find(m[1], 1, true) then return m[2] end
    end
    return nil
end

-- The buttons of a tab another plugin draws itself: its panel is built
-- off-screen with the stand-in menu, which it leaves its buttons on.
function Menu:panelButtons(tab)
    local shim = self.shim
    shim._zen_panel_refs = nil
    local ok, panel = pcall(tab.panel, shim)
    if ok and type(panel) == "table" and panel.free then pcall(panel.free, panel) end
    local refs = shim._zen_panel_refs
    local api = rawget(_G, "__ZEN_UI_QUICK_SETTINGS")
    local labels = {}
    if api and api.getItems then
        for _i, it in ipairs(api.getItems() or {}) do labels[it.id] = it.label end
    end
    local out = {}
    for i, ref in ipairs(refs and refs.buttons or {}) do
        local label = (ref.id and labels[ref.id]) or textIn(ref.widget) or string.format(_("Button %d"), i)
        out[#out + 1] = {
            label = label, icon = controlIcon(ref.id, label), callback = ref.callback, hold = ref.hold_callback,
            active = ref.id and api and api.isActive and api.isActive(ref.id) or false,
        }
    end
    return out
end

---------------------------------------------------------------- deck

-- The frontlight (and warmth) stepper rows, when the device has them.
local function lightRows()
    local rows = {}
    if not Device:hasFrontlight() then return rows end
    local pd = Device:getPowerDevice()
    local function stepper(label, get, set, min, max)
        local step = math.max(1, math.floor((max - min) / 20))
        local cur = get() or min
        return Layout.Row:new({ gap = Theme.get().space.s, children = {
            Icon:new({ name = "light", size = 20 }),
            Label:new({ text = label, kind = "label", grow = true }),
            Button:new({ label = "-", variant = "chip", width = Theme.px(44), on_tap = function()
                set(math.max(min, cur - step)); if showing then showing:show() end end }),
            Label:new({ text = string.format("%d", cur), kind = "mono", width = Theme.px(44), align = "center" }),
            Button:new({ label = "+", variant = "chip", width = Theme.px(44), on_tap = function()
                set(math.min(max, cur + step)); if showing then showing:show() end end }),
        } })
    end
    rows[#rows + 1] = stepper(_("LUMEN"), function() return pd:frontlightIntensity() end,
        function(v) pd:setIntensity(v) end, pd.fl_min or 0, pd.fl_max or 24)
    if Device:hasNaturalLight() then
        rows[#rows + 1] = stepper(_("TINT"), function() return pd:frontlightWarmth() end,
            function(v) pd:setWarmth(v) end, 0, 100)  -- setWarmth takes KOReader's 0-100 scale, not the native one
    end
    return rows
end

-- Send an event to the file browser's modules (night mode, rotation).
local function fmEvent(name, ...)
    local fm = require("apps/filemanager/filemanager").instance
    if fm then fm:handleEvent(Event:new(name, ...)) else UIManager:broadcastEvent(Event:new(name, ...)) end
end

-- The two pages of the Deck tab, first page first, as the reader ordered them.
local function deckOrder()
    if Settings.get("deck_first", "card") == "controls" then return { "controls", "card" } end
    return { "card", "controls" }
end

-- Which page of the Deck tab shows: "card" or "controls".
function Menu:deckPage()
    return deckOrder()[self.deck_page]
end

-- Show the other page of the Deck tab (delta 1 or -1); false at the ends.
function Menu:turnDeck(delta)
    local to = self.deck_page + delta
    if to < 1 or to > 2 then return false end
    self.deck_page = to
    self:show()
    return true
end

-- The page names under the Deck's contents, the shown one filled.
function Menu:deckChips()
    local names = { card = _("OPERATOR ID"), controls = _("CONTROLS") }
    local row = Layout.Row:new({ gap = Theme.get().space.s, children = {} })
    for i, id in ipairs(deckOrder()) do
        row.children[#row.children + 1] = Button:new({ label = names[id], variant = i == self.deck_page and "chip_on" or "chip", grow = true,
            height = Theme.px(38), on_tap = function() self.deck_page = i; self:show() end })
    end
    return row
end

-- CyberUI's own controls as tiles.
function Menu:deckButtons()
    local NetworkMgr = require("ui/network/manager")
    local wifi = DeviceInfo.wifi()
    local out = {
        { label = wifi and _("Wi-Fi on") or _("Wi-Fi off"), icon = "network", active = wifi, callback = function()
            if wifi then NetworkMgr:toggleWifiOff() else NetworkMgr:toggleWifiOn() end
            UIManager:scheduleIn(1, function() if showing == self then self:show() end end)
        end },
        { label = _("Night mode"), icon = "moon", active = Theme.nightMode(), callback = function()
            fmEvent("ToggleNightMode")
        end },
        { label = _("Rotate"), icon = "rotate", callback = function()
            self:close()
            fmEvent("IterateRotation")
        end },
    }
    if Device:canRestart() then
        out[#out + 1] = { label = _("Restart"), icon = "restart", callback = function()
            self:close()
            App.confirm({ title = _("Restart KOReader?"), ok = _("Restart"), on_ok = function()
                UIManager:broadcastEvent(Event:new("Restart")) end })
        end }
    end
    out[#out + 1] = { label = _("Exit"), icon = "exit", callback = function()
        self:close()
        App.confirm({ title = _("Exit KOReader?"), ok = _("Exit"), on_ok = function()
            UIManager:broadcastEvent(Event:new("Exit")) end })
    end }
    return out
end

-- The device at a glance, two terse lines.
local function glance()
    local Sysinfo = require("cyberui/data/sysinfo")
    local pct = DeviceInfo.battery()
    local first = { DeviceInfo.clock(), pct and ((DeviceInfo.charging() and "BAT+ " or "BAT ") .. pct .. "%") or nil,
        DeviceInfo.wifi() and _("UPLINK") or _("NO CARRIER") }
    local drives = Sysinfo.storage()
    local d = drives[1]
    local used, total = Sysinfo.memory()
    local up = Sysinfo.uptime().total
    local second = { d and string.format("DSK %d%%", math.floor(d.used / d.total * 100 + 0.5)) or nil,
        used and string.format("MEM %d%%", math.floor(used / total * 100 + 0.5)) or nil,
        up and string.format("UP %dH%02d", math.floor(up / 3600), math.floor(up % 3600 / 60)) or nil }
    local function join(t)
        local o = {}
        for i = 1, 3 do if t[i] then o[#o + 1] = t[i] end end
        return table.concat(o, " // ")
    end
    return Layout.Column:new({ children = {
        Label:new({ text = join(first), kind = "mono", color = "ink" }),
        Label:new({ text = join(second), kind = "mono_small", color = "muted" }),
    } })
end

-- Tiles in rows of three for a tab of buttons.
function Menu:tiles(buttons)
    local th = Theme.get()
    local rows = {}
    for i = 1, #buttons, 3 do
        local row = {}
        for j = i, math.min(#buttons, i + 2) do
            local b = buttons[j]
            row[#row + 1] = Button:new({ icon = b.icon, label = b.label, align = "left", grow = true, height = Theme.px(48),
                variant = b.active and "chip_on" or "chip",
                on_tap = b.callback and function()
                    b.callback()
                    if showing == self then self:show() end
                end or nil,
                on_hold = b.hold and function() b.hold() end or nil })
        end
        while #row < 3 do row[#row + 1] = Layout.Spacer:new({ grow = true }) end
        rows[#rows + 1] = Layout.Row:new({ gap = th.space.s, children = row })
    end
    return rows
end

---------------------------------------------------------------- build

-- Build the panel: header with the path, the tabs, then the tab's content.
function Menu:build(_close, screen_w)
    local th = Theme.get()
    local screen_h = Screen:getHeight()
    local row_h, header_h, tabs_h = Theme.px(46), Theme.px(56), Theme.px(42)
    local gap, pad = th.space.s, th.space.m
    local tab = self.tabs[self.tab]
    local look = tabLook(tab)
    if self.title then look = { look[1], self.title } end

    local tab_buttons = {}
    for i, t in ipairs(self.tabs) do
        tab_buttons[i] = Button:new({ icon = tabLook(t)[1], variant = i == self.tab and "chip_on" or "chip", grow = true,
            height = tabs_h, on_tap = function() self:switchTab(i) end })
    end
    local path = string.format(self.pick and _("PICK // %s") or _("KOREADER // %s"), look[2])
    for _i, t in ipairs(self.trail) do path = path .. " > " .. Format.upper(t) end
    local title = #self.trail > 0 and self.trail[#self.trail] or look[2]
    local kids = {
        Header.build({ title = title, path = path, on_back = #self.trail > 0 and function() self:up() end or nil,
            actions = { Button:new({ icon = "close", variant = "icon", width = th.size.touch, on_tap = function() self:close() end }) } }),
    }
    -- a picker with one list needs no tab strip
    local strip = not (self.pick and #self.tabs == 1)
    if strip then kids[#kids + 1] = Layout.Row:new({ gap = gap, children = tab_buttons }) end
    local fixed = header_h + (strip and tabs_h or 0) + 2 * gap + 2 * pad + Theme.px(3)
    if self.pick then
        kids[#kids + 1] = Label:new({ text = _("TAP AN ENTRY TO USE IT. HOLD A SUBMENU TO USE THE MENU ITSELF."), kind = "micro", color = "muted", lines = 2 })
        fixed = fixed + Theme.px(30)
    end
    local want
    if tab.deck or tab.panel then
        -- a tab of controls: tiles (and for the deck, the glance; light too)
        local card = tab.deck and self:deckPage() == "card"
        local buttons = (tab.deck and not card) and self:deckButtons() or (not tab.deck and self:panelButtons(tab)) or {}
        local inner = {}
        if card then
            inner[#inner + 1] = IdCard.compact({ on_photo = function() self:close(); require("cyberui/profileflow").card() end })
        else
            if tab.deck then inner[#inner + 1] = glance() end
            if tab.deck or tab.id == "quicksettings" then
                for _i, r in ipairs(lightRows()) do inner[#inner + 1] = r end
            end
            for _i, r in ipairs(self:tiles(buttons)) do inner[#inner + 1] = r end
        end
        if tab.deck then inner[#inner + 1] = self:deckChips() end
        if #buttons == 0 and not tab.deck then
            inner[#inner + 1] = Label:new({ text = _("Nothing to show here yet."), kind = "body", color = "muted" })
        end
        local content = Layout.Column:new({ gap = gap, children = inner })
        content:layout(screen_w - 2 * th.space.xl, nil)
        want = fixed + content.h + gap
        kids[#kids + 1] = content
    else
        local items = self:visible()
        want = fixed + #items * row_h
        kids[#kids + 1] = Grid:new({ grow = true, items = items, page = self.page, cols = 1, cell_h = row_h, row_gap = 0,
            make = function(item, w, ch) return self:row(item, w, ch) end,
            on_layout = function(_c, pages, page) self.pages, self.page = pages, page end })
    end
    local h = math.floor(math.max(screen_h * MIN_H, math.min(screen_h * (self.pick and PICK_H or tab.deck and DECK_H or MAX_H), want)))
    if want > h and not (tab.deck or tab.panel) then
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
    panel.on_page = function(delta)
        if tab.deck then return self:turnDeck(delta) end
        if (self.pages or 1) < 2 then return false end
        self.page = math.max(1, math.min(self.page + delta, self.pages))
        self:show()
        return true
    end
    self.panel = panel
    return panel
end

return Menu
