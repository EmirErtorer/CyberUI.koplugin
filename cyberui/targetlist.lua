-- What the launcher editor offers a button to open, as lists a reader can
-- browse: the plugins' menu entries, the actions plugins add, KOReader's own
-- actions by kind, and the whole top menu as a last resort. A row is
-- { icon, label, sub, rows = fn (opens a list) } or { icon, label, sub, target }.

local Dispatcher = require("dispatcher")
local Menu = require("cyberui/menu")
local PluginLoader = require("pluginloader")
local _ = require("gettext")

local TargetList = {}

-- The kinds of KOReader action that make sense on home, with Dispatcher's
-- own section ids.
local SECTIONS = {
    { "general", _("General"), "controls" }, { "device", _("Device"), "power" },
    { "screen", _("Screen and lights"), "light" }, { "filemanager", _("File browser"), "files" },
}

-- A copy of a list of names, one more added when `more` is given.
local function extended(list, more)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    if more then out[#out + 1] = more end
    return out
end

-- An item's text now.
local function textOf(item)
    local t = item.text_func and item.text_func() or item.text
    return t and tostring(t) or ""
end

-- An item's submenu now, or nil.
local function submenu(item)
    local ok, sub = pcall(function() return item.sub_item_table_func and item.sub_item_table_func() or item.sub_item_table end)
    return ok and sub or nil
end

-- Dispatcher keeps its list of actions to itself; its own functions hold it.
local function actionTable()
    local i = 1
    while true do
        local name, value = debug.getupvalue(Dispatcher.registerAction, i)
        if not name then return nil end
        if name == "settingsList" then return value end
        i = i + 1
    end
end

-- The ids of the actions KOReader itself has, read from the list in its own
-- source (anything else in Dispatcher's table was added by a plugin); nil when
-- the source cannot be read.
local core_ids
local function coreActions()
    if core_ids == nil then
        core_ids = false
        local f = io.open("frontend/dispatcher.lua", "r")
        local text = f and f:read("*a")
        if f then f:close() end
        local body = text and text:match("local dispatcher_menu_order = (%b{})")
        if body then
            core_ids = {}
            for id in body:gmatch('"([%w_]+)"') do core_ids[id] = true end
        end
    end
    return core_ids or nil
end

-- The actions anyone can run with nothing more to say, as { id, title, plugin,
-- section } sorted by title.
local function plainActions()
    local list, core, out = actionTable(), coreActions(), {}
    for id, a in pairs(list or {}) do
        if type(a) == "table" and a.category == "none" and a.title and a.condition ~= false then
            out[#out + 1] = { id = id, title = tostring(a.title), plugin = core ~= nil and not core[id], a = a }
        end
    end
    table.sort(out, function(x, y) return x.title:lower() < y.title:lower() end)
    return out
end

-- A leaf row that picks an action.
local function actionRow(entry)
    return { icon = "controls", label = entry.title, sub = _("ACTION"),
        target = { kind = "action", id = entry.id, value = true, title = entry.title } }
end

-- The rows of the actions plugins added, or of one section of KOReader's.
local function actionRows(want)
    local rows = {}
    for _i, e in ipairs(plainActions()) do
        if want(e) then rows[#rows + 1] = actionRow(e) end
    end
    return rows
end

-- Where an entry with this text sits in the top menu: { tab, trail }, found
-- by looking through every tab (three levels down), or nil.
local function locate(text)
    local m = Menu.open({ quiet = true })
    local found
    local function search(items, key, trail, depth)
        for _i, item in ipairs(items) do
            if type(item) == "table" then
                if textOf(item) == text then found = { tab = key, trail = trail }; return true end
                local sub = depth < 3 and submenu(item)
                if sub then
                    local deeper = extended(trail, textOf(item))
                    if search(sub, key, deeper, depth + 1) then return true end
                end
            end
        end
    end
    for i, tab in ipairs(m.tabs) do
        if not tab.deck and search(tab, Menu.tabKey(tab, i), {}, 1) then break end
    end
    m.quiet = false
    m:close()
    return found
end

-- The rows for the items of a menu below a place in the tree.
local function menuRows(items, tab, trail)
    local rows = {}
    for _i, item in ipairs(items) do
        local text = textOf(item)
        if type(item) == "table" and text ~= "" and not (item.hidden_func and item.hidden_func()) then
            local sub = submenu(item)
            if sub and #sub > 0 then
                local deeper = extended(trail, text)
                rows[#rows + 1] = { icon = "folder", label = text, sub = _("MENU"), rows = function() return menuRows(sub, tab, deeper) end }
            elseif item.callback or item.callback_func then
                rows[#rows + 1] = { icon = "menu", label = text, sub = _("MENU ENTRY"),
                    target = { kind = "menu", tab = tab, trail = trail, text = text, title = text } }
            end
        end
    end
    return rows
end

-- The menu entries one plugin adds to KOReader's menu, as rows.
local function pluginRows(instance)
    local rows = {}
    local added = {}
    pcall(instance.addToMainMenu, instance, added)
    local keys = {}
    for k in pairs(added) do keys[#keys + 1] = k end
    table.sort(keys)
    for _i, k in ipairs(keys) do
        local item = added[k]
        local text = type(item) == "table" and textOf(item) or ""
        if text ~= "" then
            local where = locate(text)
            if where then
                local sub = submenu(item)
                if sub and #sub > 0 then
                    local trail = extended(where.trail, text)
                    rows[#rows + 1] = { icon = "folder", label = text, sub = _("MENU"), rows = function() return menuRows(sub, where.tab, trail) end }
                else
                    rows[#rows + 1] = { icon = "menu", label = text, sub = _("MENU ENTRY"),
                        target = { kind = "menu", tab = where.tab, trail = where.trail, text = text, title = text } }
                end
            end
        end
    end
    return rows
end

-- A plugin's name as the reader knows it.
local function pluginName(name)
    local enabled = PluginLoader.enabled_plugins or {}
    for _i, p in ipairs(enabled) do
        if p.name == name then return p.fullname or p.name end
    end
    return name
end

-- The plugins that put entries in the menu, one row each.
local function pluginList()
    local names = {}
    for name, instance in pairs(PluginLoader.loaded_plugins or {}) do
        if type(instance) == "table" and type(instance.addToMainMenu) == "function" then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return pluginName(a):lower() < pluginName(b):lower() end)
    local rows = {}
    for _i, name in ipairs(names) do
        rows[#rows + 1] = { icon = "tools", label = pluginName(name), sub = _("PLUGIN"),
            rows = function() return pluginRows(PluginLoader.loaded_plugins[name]) end }
    end
    return rows
end

-- The top list. done(target) is what the reader picked; `whole_menu` opens
-- the old drop-down tree for anything not found above.
function TargetList.root(whole_menu)
    local rows = {
        { icon = "tools", label = _("Plugins"), sub = _("THEIR MENU ENTRIES"), rows = pluginList },
        { icon = "plus", label = _("Plugin actions"), sub = _("WHAT PLUGINS ADD TO GESTURES"), rows = function()
            return actionRows(function(e) return e.plugin end)
        end },
    }
    for _i, s in ipairs(SECTIONS) do
        rows[#rows + 1] = { icon = s[3], label = s[2], sub = _("KOREADER ACTIONS"), rows = function()
            return actionRows(function(e) return e.a[s[1]] == true and not e.plugin end)
        end }
    end
    rows[#rows + 1] = { icon = "menu", label = _("Whole KOReader menu"), sub = _("EVERY TAB AND SUBMENU"), whole = whole_menu }
    return rows
end

return TargetList
