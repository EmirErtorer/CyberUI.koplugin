-- The operator ID card on its own screen, with the ways to change it: the
-- photo (tap the face or the PHOTO tag), the handle (tap it) and saving the
-- card as a picture.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Frame = require("cyberui/screens/frame")
local IdCard = require("cyberui/ui/idcard")
local Layout = require("cyberui/ui/layout")
local ProfileFlow = require("cyberui/profileflow")
local Screen = require("cyberui/screens/screen")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local Card = Screen:extend()

-- Save the card as a picture.
local function export()
    local file, err = ProfileFlow.export(IdCard.full({}))
    App.toast(file and string.format(_("Saved %s"), file:match("[^/]+$")) or err)
end

-- Build the screen.
function Card:build()
    local th = Theme.get()
    local actions = {
        Button:new({ icon = "image", variant = "icon", width = th.size.touch, on_tap = ProfileFlow.photo }),
        Button:new({ icon = "edit", variant = "icon", width = th.size.touch, on_tap = function() ProfileFlow.editHandle() end }),
        Button:new({ icon = "download", variant = "icon", width = th.size.touch, on_tap = export }),
    }
    return Frame.page({ screen = self, title = _("Operator"), path = "ID // CARD", tab = "settings", actions = actions,
        body = Layout.Column:new({ children = { IdCard.full({ on_photo = ProfileFlow.photo, on_handle = function() ProfileFlow.editHandle() end }) } }) })
end

return Card
