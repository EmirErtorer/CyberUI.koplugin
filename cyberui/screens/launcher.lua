-- Editing the home launcher: every button in order, with moves, hide or show,
-- and edit; new buttons of the reader's own are added at the bottom.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local EditRow = require("cyberui/ui/editrow")
local Frame = require("cyberui/screens/frame")
local Icon = require("cyberui/ui/icon")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Launcher = require("cyberui/data/launcher")
local LauncherUI = require("cyberui/ui/launcher")
local Screen = require("cyberui/screens/screen")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local LauncherScreen = Screen:extend()

-- One button of the launcher: its glyph and name, then its moves.
local function entryRow(entry, i, count)
    local icon, label, sub = LauncherUI.describe(entry)
    local fixed = entry.id == Launcher.FIXED
    local muted = entry.hidden and "muted" or "ink"
    local buttons = {
        EditRow.button("up", function() Launcher.move(entry.id, -1); App.update() end, i > 1),
        EditRow.button("down", function() Launcher.move(entry.id, 1); App.update() end, i < count),
    }
    if not fixed then
        buttons[#buttons + 1] = EditRow.button(entry.hidden and "plus" or "eye", function()
            Launcher.setHidden(entry.id, not entry.hidden)
            App.update()
        end)
        buttons[#buttons + 1] = EditRow.button("edit", function() App.push("launchedit", { id = entry.id }) end)
    end
    return EditRow.line({
        Icon:new({ name = icon, size = 24, color = muted }),
        Layout.Column:new({ grow = true, children = {
            Label:new({ text = label, kind = "heading", color = muted }),
            Label:new({ text = entry.hidden and _("HIDDEN") or sub, kind = "mono_small", color = "muted" }),
        } }),
    }, buttons)
end

-- Build the editor.
function LauncherScreen:build()
    local th = Theme.get()
    local entries = Launcher.entries()
    local body = {}
    for i, entry in ipairs(entries) do body[#body + 1] = entryRow(entry, i, #entries) end
    body[#body + 1] = Button:new({ label = _("+ ADD BUTTON"), variant = "primary", corners = "tb", on_tap = function()
        if not Launcher.canAdd() then return App.toast(_("The launcher is full")) end
        App.push("launchedit", { id = Launcher.add() })
    end })
    return Frame.page({ screen = self, title = _("Launcher"), path = _("ADD // MOVE // HIDE // EDIT"), tab = "settings",
        body = Layout.Column:new({ gap = th.space.s, clip = true, children = body }) })
end

return LauncherScreen
