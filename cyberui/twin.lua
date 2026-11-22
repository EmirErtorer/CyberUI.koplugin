-- SolarUI and CyberUI are twin home screens. With both installed, one of them
-- is in charge (its home, its top and bottom bars, its look for KOReader's
-- windows and menus, its sleep screen) and the other stays quiet; a tap hands
-- over to the other at once, each keeping the settings the reader gave it.
-- With the other twin not installed, switched off or waiting for a restart,
-- the tap says so and offers the one step that fixes it. Also here: holding
-- the bottom-right corner in a book to come home, a binding in KOReader's
-- gestures.

local _ = require("cyberui/gettext")

local Twin = {}

-- This twin and the other, by the ids KOReader's Start with setting uses.
Twin.ME = "cyberui"
Twin.OTHER = {
    id = "solarui",
    name = "SolarUI",
    folder = "SolarUI.koplugin",
    repo = "EmirErtorer/SolarUI.koplugin",
    zip = function(tag) return "SolarUI.koplugin-" .. tag .. ".zip" end,
    open_event = "SolarUIHome",
    icon = "home",
    tagline = _("Your home, as a garden"),
    description = _("SolarUI is the twin of CyberUI: the same home, library and reading tools, grown as an Art Nouveau garden instead of a cyberdeck. Switch between the two at any time; each keeps its own settings."),
}

-- The gesture action that opens each twin's home.
local ACTIONS = { solarui = "solarui_home", cyberui = "cyberui_home" }
local KEY = "twin_ui"                       -- (in KOReader's own settings, which both twins read)
local ELDER = "cyberui"                     -- in charge when both run and neither was chosen
local CORNER = "hold_bottom_right_corner"   -- (KOReader's name for the gesture)

-- KOReader's file browser or reader, whichever is open. (The reader's code is
-- only looked at when it was loaded: no reader can be open before that, and
-- loading it at start would cost more than everything else asked here.)
local function ui()
    local fm, reader = _G.package.loaded["apps/filemanager/filemanager"], _G.package.loaded["apps/reader/readerui"]
    return (fm and fm.instance) or (reader and reader.instance)
end

-- Is the other twin running in this KOReader?
local function otherRuns()
    local u = ui()
    return u ~= nil and u[(Twin.OTHER.folder:gsub("%.koplugin$", ""))] ~= nil
end

-- The twin in charge: the one last switched to, else the one KOReader starts
-- with, else (both running and neither chosen) the elder; never one that is
-- not running.
function Twin.active()
    local G = G_reader_settings
    for _i, v in ipairs({ G:readSetting(KEY), G:readSetting("start_with") }) do
        if v == Twin.ME then return v end
        if v == Twin.OTHER.id then return otherRuns() and v or Twin.ME end
    end
    return otherRuns() and ELDER or Twin.ME
end

-- Is this twin the one in charge? Asked whenever a window or menu is about to
-- be styled, so a switch takes effect at once.
function Twin.mine()
    return Twin.active() == Twin.ME
end

-- KOReader's gesture bindings (shared by the gestures module of the file
-- browser and of the reader) and a function writing them; nil when there are
-- none yet (KOReader writes them at its first start).
local function gestures()
    local u = ui()
    local g = u and u.gestures
    if g and type(g.data) == "table" and type(g.data.gesture_reader) == "table" then
        return g.data, function() g.settings:flush() end
    end
    local s = require("luasettings"):open(require("datastorage"):getSettingsDir() .. "/gestures.lua")
    if type(s.data.gesture_reader) ~= "table" then return nil end
    return s.data, function() s:flush() end
end

-- Does holding the bottom-right corner in a book open this twin's home?
function Twin.cornerHome()
    local data = gestures()
    local held = data and data.gesture_reader[CORNER]
    return type(held) == "table" and held[ACTIONS[Twin.ME]] == true
end

-- Make holding the bottom-right corner in a book open this twin's home (in
-- place of whatever it did), or take that away again. KOReader's "ignore
-- holds on the corners" is turned off, or the hold would never arrive.
-- Returns whether it was written.
function Twin.setCornerHome(on)
    local data, write = gestures()
    if not data then return false end
    if on then
        data.gesture_reader[CORNER] = { [ACTIONS[Twin.ME]] = true }
        G_reader_settings:makeFalse("ignore_hold_corners")
    elseif Twin.cornerHome() then
        data.gesture_reader[CORNER] = nil
    end
    write()
    return true
end

-- A corner set to open either twin's home opens the home of twin `to` from now on.
local function cornerTo(to)
    local data, write = gestures()
    local held = data and data.gesture_reader[CORNER]
    if type(held) ~= "table" then return end
    for id, action in pairs(ACTIONS) do
        if id ~= to and held[action] then
            data.gesture_reader[CORNER] = { [ACTIONS[to]] = true }
            write()
            return
        end
    end
end

-- Make this twin the one in charge (it was chosen as KOReader's start screen);
-- a corner set to the other twin's home comes along.
function Twin.claim()
    G_reader_settings:saveSetting(KEY, Twin.ME)
    cornerTo(Twin.ME)
end

-- The other twin's state: "ready", "disabled", "restart" or "missing" (see apps/addons.lua).
function Twin.otherStatus()
    return require("cyberui/apps/addons").status(Twin.OTHER)
end

-- Hand over to the other twin: it opens at once in this one's place and is
-- the one in charge from now on (the start screen and the corner follow).
-- When it cannot run yet, say why and offer what fixes it instead.
function Twin.switch()
    local Addons = require("cyberui/apps/addons")
    if Addons.status(Twin.OTHER) ~= "ready" then return Addons.launch(Twin.OTHER) end
    -- asked first, so a stray tap never swaps the whole look
    require("cyberui/app").confirm({ icon = "home", title = string.format(_("Switch to %s?"), Twin.OTHER.name),
        text = string.format(_("Home, the menus and KOReader's windows will look like %s. You can switch back at any time."), Twin.OTHER.name),
        ok = _("Switch"), on_ok = Twin.handOver })
end

-- Hand over to the other twin at once (Twin.switch asks first).
function Twin.handOver()
    local Addons = require("cyberui/apps/addons")
    if Addons.status(Twin.OTHER) ~= "ready" then return Addons.launch(Twin.OTHER) end
    local G = G_reader_settings
    G:saveSetting(KEY, Twin.OTHER.id)
    if G:readSetting("start_with") == Twin.ME then G:saveSetting("start_with", Twin.OTHER.id) end
    cornerTo(Twin.OTHER.id)
    local App = require("cyberui/app")
    App.setHome(false)
    require("cyberui/park").finish()   -- a book kept open under home closes; the twin opens from the file browser
    -- the twin opens over this one, then this one closes under it, so KOReader's file browser never shows between them
    local fm = require("apps/filemanager/filemanager").instance
    if fm then fm:handleEvent(require("ui/event"):new(Twin.OTHER.open_event)) end
    require("ui/uimanager"):nextTick(function() App.close() end)
end

return Twin
