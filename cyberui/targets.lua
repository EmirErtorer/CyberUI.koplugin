-- What a launcher button can open: a KOReader action (the ones gestures use)
-- or an entry of KOReader's top menu. The lists to choose from are in
-- targetlist.lua; this file runs and describes a target.
-- A target is { kind = "action", id, value, title } or
-- { kind = "menu", tab, trail, text, title }.

local Dispatcher = require("dispatcher")
local App = require("cyberui/app")
local Menu = require("cyberui/menu")
local _ = require("gettext")

local Targets = {}

-- Choose an entry of KOReader's top menu; done(target) gets it.
function Targets.pickMenu(done)
    Menu.open({ title = _("KOREADER MENU"), pick = function(target)
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
