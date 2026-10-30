-- Companion plugins shown on the home screen (Ink Away today): whether one
-- is ready, switched off, waiting for a restart or missing, and what tapping
-- it does in each case: open it, switch it on, ask for the restart, or
-- describe it and install it from GitHub with one button.

local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local App = require("cyberui/app")
local Dialog = require("cyberui/ui/dialog")
local GitHub = require("cyberui/install/github")
local Net = require("cyberui/install/net")
local Paths = require("cyberui/paths")
local Unpack = require("cyberui/install/unpack")
local _ = require("cyberui/gettext")

local Addons = {}

-- The plugin's id in KOReader: its folder name without ".koplugin".
local function pluginId(addon)
    return addon.folder:gsub("%.koplugin$", "")
end

-- The folder CyberUI is installed in, where companions are installed too.
function Addons.pluginsDir()
    return (Paths.root:gsub("/[^/]+/?$", ""))
end

-- Where the plugin is installed, or nil: next to CyberUI or in any folder
-- KOReader looks for plugins in.
function Addons.installedPath(addon)
    local dirs = { Addons.pluginsDir(), "plugins" }
    local extra = G_reader_settings and G_reader_settings:readSetting("extra_plugin_paths")
    if type(extra) == "string" then extra = { extra } end
    for _i, d in ipairs(type(extra) == "table" and extra or {}) do dirs[#dirs + 1] = d end
    for _i, d in ipairs(dirs) do
        local path = d:gsub("/+$", "") .. "/" .. addon.folder
        if lfs.attributes(path .. "/main.lua", "mode") == "file" then return path end
    end
    return nil
end

-- "ready" (running), "disabled" (switched off), "restart" (installed, not
-- running yet) or "missing".
function Addons.status(addon)
    local ui = require("cyberui/park").ui()   -- the file browser, or the book parked under home
    if ui and ui[pluginId(addon)] then return "ready" end
    if not Addons.installedPath(addon) then return "missing" end
    local off = G_reader_settings and G_reader_settings:readSetting("plugins_disabled")
    if type(off) == "table" and off[pluginId(addon)] then return "disabled" end
    return "restart"
end

-- The small line under the plugin's home button.
function Addons.statusLine(addon)
    local s = Addons.status(addon)
    if s == "ready" then return addon.tagline end
    if s == "disabled" then return _("SWITCHED OFF // TAP") end
    if s == "restart" then return _("RESTART TO USE") end
    return _("GET IT // FREE")
end

-- Install from GitHub: newest stable release, checked and unpacked, then
-- the restart prompt. Shows each step while it runs.
function Addons.install(addon)
    local function step(text)
        App.dialog(function(_close, w)
            return Dialog.progress({ title = string.format(_("Installing %s"), addon.name), text = text }, w)
        end)
    end
    local function fail(why)
        App.closeDialog()
        App.confirm({ title = string.format(_("%s was not installed"), addon.name), text = why, ok = _("Try again"),
            on_ok = function() Addons.install(addon) end })
    end
    local function run()
        step(_("1/3 // ASKING GITHUB"))
        GitHub.latest(addon, function(release, why)
            if not release then return fail(why) end
            step(string.format(_("2/3 // DOWNLOADING %s %s (%.1f MB)"), addon.name:upper(), release.version, release.size / 1048576))
            Net.get(release.url, release.size, 300, function(zip, err)
                if not zip then return fail(err) end
                step(_("3/3 // CHECKING AND UNPACKING"))
                UIManager:nextTick(function()
                    local ok, res, uerr = pcall(Unpack.install, zip, release, addon.folder, Addons.pluginsDir())
                    os.remove(zip)
                    if not (ok and res) then return fail(tostring(ok and uerr or res)) end
                    App.closeDialog()
                    App.update()
                    UIManager:askForRestart(string.format(_("%s %s is installed. Restart KOReader to use it."), addon.name, release.version))
                end)
            end)
        end)
    end
    local ok, NetworkMgr = pcall(require, "ui/network/manager")
    if ok and NetworkMgr.runWhenOnline then NetworkMgr:runWhenOnline(run) else run() end
end

-- What a tap on the plugin's home button does.
function Addons.launch(addon)
    local s = Addons.status(addon)
    if s == "ready" then
        require("cyberui/park").finish()   -- the plugin opens from the file browser
        local fm = require("apps/filemanager/filemanager").instance
        fm:handleEvent(Event:new(addon.open_event))
    elseif s == "restart" then
        UIManager:askForRestart(string.format(_("%s is installed. Restart KOReader to use it."), addon.name))
    elseif s == "disabled" then
        App.confirm({ icon = addon.icon, title = addon.name, ok = _("Switch on"),
            text = string.format(_("%s is installed but switched off in KOReader's plugins. Switch it on?"), addon.name),
            on_ok = function()
                local off = G_reader_settings:readSetting("plugins_disabled") or {}
                off[pluginId(addon)] = nil
                G_reader_settings:saveSetting("plugins_disabled", off)
                G_reader_settings:flush()
                UIManager:askForRestart(string.format(_("%s is switched on. Restart KOReader to use it."), addon.name))
            end })
    else
        App.confirm({ icon = addon.icon, title = addon.name, detail = addon.tagline, ok = _("Install"), cancel = _("Not now"),
            text = addon.description .. "\n\n" .. string.format(_("Free, from github.com/%s. Needs Wi-Fi."), addon.repo),
            on_ok = function() Addons.install(addon) end })
    end
end

return Addons
