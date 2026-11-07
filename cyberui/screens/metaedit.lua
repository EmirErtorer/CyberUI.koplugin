-- Edit a book's details: one row each for title, authors, series, series
-- number, genres and language. Tap a row to type a new value (several authors
-- or genres go between semicolons); hold it, or save it empty, to bring back
-- what the book itself says.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Books = require("cyberui/data/books")
local Frame = require("cyberui/screens/frame")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Metadata = require("cyberui/data/metadata")
local Panel = require("cyberui/ui/panel")
local Screen = require("cyberui/screens/screen")
local Theme = require("cyberui/theme")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local util = require("util")
local _ = require("cyberui/gettext")

local MetaEdit = Screen:extend()

-- Save a detail and say how it went.
local function save(path, key, value)
    if Metadata.set(path, key, value) then
        App.toast(value and _("Saved") or _("Back to the book's own"))
    else
        App.toast(_("Couldn't save these details"))
    end
    App.update()
end

-- Type a new value for one detail.
local function edit(path, f)
    App.input(f.name, Metadata.value(path, f.key), function(text)
        local value, why = Metadata.parse(f.key, text)
        if why == "number" then return App.toast(_("Type a number")) end
        save(path, f.key, value)
    end, _("Save"), { placeholder = f.multi and _("separate several with ;") or nil })
end

-- Bring back the book's own value of a detail (only when it was changed).
local function restore(path, f)
    if not Metadata.changed(path, f.key) then return App.toast(_("Already the book's own")) end
    save(path, f.key, nil)
end

-- One row: the name, the value (or a dash), a mark when it was changed.
local function row(path, f)
    local th = Theme.get()
    local value = Metadata.value(path, f.key)
    local changed = Metadata.changed(path, f.key)
    return Panel:new({ shape = "frame", pad = th.space.m, on_tap = function() edit(path, f) end,
        on_hold = function() restore(path, f) end, child = Layout.Row:new({ gap = th.space.m, children = {
            Label:new({ text = f.name:upper(), kind = "mono_small", color = "muted", width = Theme.px(112) }),
            Label:new({ text = value ~= "" and value or "—", kind = "body", grow = true, lines = 2,
                color = value ~= "" and "ink" or "muted" }),
            Label:new({ text = changed and _("EDITED") or "", kind = "micro", color = "muted" }),
        } }) })
end

-- Build the screen.
function MetaEdit:build()
    local th = Theme.get()
    local path = self.params.path
    local info = Books.info(path)
    local rows = {}
    for _i, f in ipairs(Metadata.FIELDS) do rows[#rows + 1] = row(path, f) end
    local kids = {
        Label:new({ text = info.title, kind = "display", lines = 2 }),
        Layout.Column:new({ gap = th.space.s, children = rows }),
        Label:new({ text = _("Tap a detail to change it. Hold it to bring back what the book says. The book file is not changed."),
            kind = "mono_small", color = "muted", lines = 3 }),
        Layout.Row:new({ gap = th.space.s, children = {
            Button:new({ label = _("RESET ALL"), icon = "trash", grow = true, disabled = not Metadata.changed(path),
                on_tap = function()
                    Metadata.reset(path)
                    App.toast(_("Back to the book's own"))
                    App.update()
                end }),
            Button:new({ label = _("DONE"), icon = "check", variant = "primary", grow = true, on_tap = function() App.back() end }),
        } }),
    }
    return Frame.page({
        screen = self, title = _("Edit details"), path = filemanagerutil.abbreviate((util.splitFilePathName(path))), tab = "library",
        body = Layout.Column:new({ gap = th.space.l, children = kids }),
    })
end

return MetaEdit
