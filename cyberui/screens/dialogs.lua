-- The switches for KOReader's windows in CyberUI's style: one for all of them and
-- one for each kind, so a problem with one kind can be switched off alone.
-- Each takes effect on the next window of that kind.

local App = require("cyberui/app")
local Controls = require("cyberui/ui/controls")
local Frame = require("cyberui/screens/frame")
local Groups = require("cyberui/skin/groups")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Screen = require("cyberui/screens/screen")
local Settings = require("cyberui/settings")
local Theme = require("cyberui/theme")
local row = require("cyberui/ui/settingrow")
local _ = require("cyberui/gettext")

local Dialogs = Screen:extend()

-- Save a switch and draw the page again.
local function save(key, on)
    Settings.save(key, on)
    App.update()
end

-- Build the page.
function Dialogs:build()
    local th = Theme.get()
    local all = Settings.get("styled_widgets", true)
    local body = {
        row(_("All KOReader dialogs"), _("The main switch: off, every window is KOReader's own, whatever the kinds below say"),
            Controls.Toggle:new({ on = all, on_change = function(on) save("styled_widgets", on) end })),
    }
    for _i, group in ipairs(Groups.LIST) do
        local key = Groups.key(group)
        body[#body + 1] = row(group.name, group.sub,
            Controls.Toggle:new({ on = Settings.get(key, true), on_change = function(on) save(key, on) end }))
    end
    if not all then
        body[#body + 1] = Label:new({ text = _("THE MAIN SWITCH IS OFF"), kind = "label", color = "accent" })
    end
    return Frame.page({ screen = self, title = _("KOReader dialogs"), path = _("SWITCH EACH KIND"), tab = "settings",
        body = Layout.Column:new({ gap = th.space.s, clip = true, children = body }) })
end

return Dialogs
