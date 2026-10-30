-- The home launcher: one button per entry of the launcher list (the built-in
-- sections and the reader's own buttons), sharing the full height, in two
-- columns on a landscape screen.

local Addons = require("cyberui/apps/addons")
local App = require("cyberui/app")
local Bounty = require("cyberui/data/bounty")
local Button = require("cyberui/ui/button")
local Collections = require("cyberui/data/collections")
local Format = require("cyberui/format")
local InkAway = require("cyberui/apps/inkaway")
local Layout = require("cyberui/ui/layout")
local Library = require("cyberui/data/library")
local LauncherData = require("cyberui/data/launcher")
local Panel = require("cyberui/ui/panel")
local Shards = require("cyberui/data/shards")
local Targets = require("cyberui/targets")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local Launcher = {}

-- The built-in buttons: id -> function giving icon, label, sub line, action.
local BUILTIN = {
    library = function()
        local count = Library.count()
        return "library", _("LIBRARY"), count and string.format(_("%d FILES // GRID"), count) or _("FILES // GRID"),
            function() App.go("library") end
    end,
    collections = function()
        return "collections", _("COLLECTIONS"), string.format(_("%d CACHES"), #Collections.list()), function() App.go("collections") end
    end,
    history = function() return "history", _("HISTORY"), _("TELEMETRY.LOG"), function() App.go("history") end end,
    bounty = function()
        local list = Bounty.list()
        return "bounty", _("BOUNTIES"), #list > 0 and string.format(_("%s // %d WANTED"), Format.credits(Bounty.total()), #list) or _("BACKLOG CLEAR"),
            function() App.push("bounty") end
    end,
    shards = function()
        local n = Shards.count()
        return "shard", _("SHARDS"), n > 0 and string.format(_("%d RECOVERED"), n) or _("NO HIGHLIGHTS YET"), function() App.push("shards") end
    end,
    search = function() return "search", _("SEARCH"), _("GREP THE ARCHIVE"), function() App.push("search") end end,
    inkaway = function() return InkAway.icon, _("INK AWAY"), Addons.statusLine(InkAway), function() Addons.launch(InkAway) end end,
    settings = function()
        local v = require("cyberui/update/updater").available()
        return "settings", _("SYSTEM"), v and string.format(_("UPDATE v%s READY"), v) or _("THEME // SETTINGS"),
            function() App.go("settings") end
    end,
}

-- The icon, label, sub line and action of an entry: the reader's own when
-- it has them, else the built-in one.
function Launcher.describe(entry)
    local c = entry.custom
    if c then
        return c.icon, (c.name or ""):upper(), c.target and Targets.describe(c.target) or _("NOTHING YET"),
            function() if c.target then Targets.run(c.target) else App.toast(_("Pick what this button opens")) end end
    end
    return BUILTIN[entry.id]()
end

-- The panel of buttons.
function Launcher.build()
    local th = Theme.get()
    local buttons = {}
    for _i, entry in ipairs(LauncherData.visible()) do
        local icon, label, sub, action = Launcher.describe(entry)
        buttons[#buttons + 1] = Button:new({ icon = icon, label = label, sub = sub, align = "left", variant = "soft",
            corners = "r", grow = true, on_tap = action })
    end
    -- one column; on a wide, short (landscape) screen two, so each keeps
    -- room for both of its lines
    local screen = require("device").screen
    local cols = screen:getWidth() > screen:getHeight() and 2 or 1
    local rows = {}
    for i = 1, #buttons, cols do
        rows[#rows + 1] = cols == 1 and buttons[i]
            or Layout.Row:new({ grow = true, gap = th.space.xs, valign = "stretch", children = { buttons[i], buttons[i + 1] or Layout.Spacer:new({ grow = true }) } })
    end
    return Panel:new({ shape = "rail", side = "r", line = "accent", width = Theme.px(cols == 1 and 212 or 400),
        pad = { 0, th.space.l, 0, 0 }, child = Layout.Column:new({ gap = th.space.xs, children = rows }) })
end

return Launcher
