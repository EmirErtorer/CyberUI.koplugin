-- Editing the top bar: the tag text on the left, then the readouts shown
-- (move up, move down, remove) and the ones that can be added. The bar at
-- the top of this very screen shows each change at once.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local EditRow = require("cyberui/ui/editrow")
local Frame = require("cyberui/screens/frame")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Screen = require("cyberui/screens/screen")
local Settings = require("cyberui/settings")
local StatusBar = require("cyberui/ui/statusbar")
local Theme = require("cyberui/theme")
local util = require("util")
local _ = require("cyberui/gettext")

local TopBar = Screen:extend()

-- Save the shown ids and redraw.
local function save(ids)
    Settings.save("topbar", ids)
    App.update()
end

-- A copy of the shown ids.
local function shownCopy()
    local ids = {}
    for i, id in ipairs(StatusBar.shown()) do ids[i] = id end
    return ids
end

-- One readout: its name, what it reads now, then the buttons given.
local function itemRow(it, buttons)
    return EditRow.line({
        Label:new({ text = it.name, kind = "heading", grow = true }),
        Label:new({ text = it.read() or _("NO SIGNAL"), kind = "mono_small", color = "muted" }),
    }, buttons)
end

local iconButton = EditRow.button

-- Build the editor.
function TopBar:build()
    local th = Theme.get()
    local ids = StatusBar.shown()
    local on = {}
    local body = {
        Layout.Row:new({ gap = th.space.m, children = {
            Layout.Column:new({ grow = true, children = {
                Label:new({ text = _("Tag"), kind = "heading" }),
                Label:new({ text = StatusBar.tag(), kind = "mono", color = "muted" }),
            } }),
            Button:new({ label = _("Edit"), on_tap = function()
                App.input(_("Top bar tag"), StatusBar.tag(), function(text)
                    Settings.save("topbar_tag", util.trim(text or ""))
                    App.update()
                end, _("Save"), { placeholder = StatusBar.TAG })
            end }),
        } }),
        Label:new({ text = string.format(_("SHOWN %d/%d"), #ids, StatusBar.MAX), kind = "label" }),
    }
    for i, id in ipairs(ids) do
        local it = StatusBar.item(id)
        if it then
            on[id] = true
            body[#body + 1] = itemRow(it, {
                iconButton("up", function() local t = shownCopy(); t[i], t[i - 1] = t[i - 1], t[i]; save(t) end, i > 1),
                iconButton("down", function() local t = shownCopy(); t[i], t[i + 1] = t[i + 1], t[i]; save(t) end, i < #ids),
                iconButton("close", function() local t = shownCopy(); table.remove(t, i); save(t) end),
            })
        end
    end
    body[#body + 1] = Label:new({ text = _("AVAILABLE"), kind = "label" })
    for _i, it in ipairs(StatusBar.ITEMS) do
        if not on[it.id] then
            body[#body + 1] = itemRow(it, { iconButton("plus", function()
                if #ids >= StatusBar.MAX then return App.toast(_("The top bar is full")) end
                local t = shownCopy()
                t[#t + 1] = it.id
                save(t)
            end) })
        end
    end
    return Frame.page({ screen = self, title = _("Top bar"), path = _("ADD // MOVE // REMOVE"), tab = "settings",
        body = Layout.Column:new({ gap = th.space.s, clip = true, children = body }) })
end

return TopBar
