-- What a launcher button can open: a KOReader action (the ones gestures use)
-- or an entry of KOReader's top menu. Choosing one goes through CyberUI's own
-- menu in pick mode, so both lists look and behave like the menu itself.
-- A target is { kind = "action", id, value, title } or
-- { kind = "menu", tab, trail, text, title }.

local Dispatcher = require("dispatcher")
local App = require("cyberui/app")
local Menu = require("cyberui/menu")
local _ = require("gettext")

local Targets = {}

-- Can this entry of the action list be chosen? Only plain actions: a group
-- of them, or one that asks for a number first, has nothing to run.
local function plainAction(item)
    return item.callback ~= nil and not item.sub_item_table and not item.text_func
end

-- The action an entry of the action list stands for: tapping it in KOReader's
-- chooser records it in `location`, so its callback tells us which it is.
local function actionOf(item, location)
    location.actions = nil
    item.callback({ updateItems = function() end })
    for k, v in pairs(location.actions or {}) do
        if type(k) == "string" and k ~= "settings" then return { kind = "action", id = k, value = v, title = item.text } end
    end
    return nil
end

-- Choose one of KOReader's actions; done(target) gets it.
function Targets.pickAction(done)
    local location = {}
    local items = {}
    Dispatcher:addSubMenu({}, items, location, "actions")
    table.remove(items, 1)   -- "Nothing"
    Menu.open({ km = { tab_item_table = { items } }, pickable = plainAction, pick = function(_target, item)
        local target = actionOf(item, location)
        if target then done(target) end
    end })
end

-- Choose an entry of KOReader's top menu; done(target) gets it.
function Targets.pickMenu(done)
    Menu.open({ pick = function(target)
        target.kind = "menu"
        target.title = target.text
        done(target)
    end })
end

-- Open the entry of KOReader's top menu a target points to: a submenu stays
-- open, anything else runs.
local function runMenu(target)
    local m = Menu.open({ quiet = true })
    local i = m:tabIndex(target.tab)
    if not i then m.quiet = false; m:close(); return App.toast(_("That menu is gone")) end
    m:switchTab(i)
    for _i, text in ipairs(target.trail) do
        local item = m:find(text)
        if not item then m.quiet = false; return m:show() end
        m:select(item)
    end
    local item = m:find(target.text)
    m.quiet = false
    if not item then return m:show() end
    m:select(item)
end

-- Run a target.
function Targets.run(target)
    if target.kind == "action" then
        Dispatcher:execute({ [target.id] = target.value })
    elseif target.kind == "menu" then
        runMenu(target)
    end
end

-- A short line saying what a target is, for the editor and the button.
function Targets.describe(target)
    if not target then return _("NOTHING YET") end
    if target.kind == "menu" then
        return "MENU // " .. table.concat(target.trail, " > ") .. (#target.trail > 0 and " > " or "") .. (target.text or "")
    end
    return "ACTION // " .. tostring(target.title or target.id)
end

return Targets
