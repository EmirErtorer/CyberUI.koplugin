-- Editing one launcher button: its name, its icon and what it opens (any
-- KOReader action or menu entry, plugins included). Each change is kept at
-- once; the launcher on home shows it as soon as you go back.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Frame = require("cyberui/screens/frame")
local Icon = require("cyberui/ui/icon")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Launcher = require("cyberui/data/launcher")
local LauncherUI = require("cyberui/ui/launcher")
local Screen = require("cyberui/screens/screen")
local Targets = require("cyberui/targets")
local Theme = require("cyberui/theme")
local row = require("cyberui/ui/settingrow")
local util = require("util")
local _ = require("gettext")

local LaunchEdit = Screen:extend()

-- The button being edited, or nil if it has gone.
function LaunchEdit:entry()
    return Launcher.get(self.params.id)
end

-- The name, icon and target the button has now (a built-in's own at first).
local function current(entry)
    if entry.custom then return entry.custom end
    local icon, label = LauncherUI.describe(entry)
    return { name = label, icon = icon }
end

-- Keep a change to one field and redraw.
function LaunchEdit:set(field, value)
    local entry = self:entry()
    if not entry then return end
    local custom = {}
    for k, v in pairs(current(entry)) do custom[k] = v end
    custom[field] = value
    Launcher.setCustom(entry.id, custom)
    App.update()
end

-- Ask what kind of target to pick, then pick it.
function LaunchEdit:pickTarget()
    local function chosen(target) self:set("target", target) end
    App.choose({ title = _("What it opens"), options = {
        { label = _("KOReader action"), sub = _("The actions gestures can run"), icon = "controls",
            on_tap = function() Targets.pickAction(chosen) end },
        { label = _("KOReader menu entry"), sub = _("Anything in the top menu, plugins too"), icon = "menu",
            on_tap = function() Targets.pickMenu(chosen) end },
    } })
end

-- Build the editor.
function LaunchEdit:build()
    local th = Theme.get()
    local entry = self:entry()
    if not entry then return Frame.page({ screen = self, title = _("Button"), tab = "settings", body = Label:new({ text = _("Gone"), kind = "body" }) }) end
    local c = current(entry)
    local builtin = Launcher.isBuiltin(entry.id)
    local body = {
        row(_("Name"), c.name, Button:new({ label = _("Edit"), on_tap = function()
            App.input(_("Button name"), c.name, function(text)
                text = util.trim(text or "")
                if text ~= "" then self:set("name", text) end
            end, _("Save"), { placeholder = _("NAME") })
        end })),
        row(_("Icon"), c.icon, Layout.Row:new({ gap = th.space.s, children = {
            Icon:new({ name = c.icon, size = 26 }),
            Button:new({ label = _("Choose"), on_tap = function()
                App.push("iconpick", { current = c.icon, on_pick = function(name) self:set("icon", name) end })
            end }),
        } })),
        row(_("Opens"), Targets.describe(c.target), Button:new({ label = _("Pick"), on_tap = function() self:pickTarget() end })),
    }
    local undo = builtin and entry.custom
    if not builtin or undo then
        body[#body + 1] = Button:new({ label = builtin and _("RESTORE THE ORIGINAL") or _("DELETE THIS BUTTON"), icon = builtin and "restore" or "trash",
            variant = builtin and "secondary" or "danger", corners = "tb", on_tap = function()
                Launcher.remove(entry.id)
                App.pop()
            end })
    end
    return Frame.page({ screen = self, title = c.name, path = builtin and _("BUILT-IN // REPLACE") or _("CUSTOM // BUTTON"), tab = "settings",
        body = Layout.Column:new({ gap = th.space.s, clip = true, children = body }) })
end

return LaunchEdit
