-- CyberUI's own settings, kept in settings/cyberui.lua next to KOReader's.
-- One shared store so every module reads and writes the same file.

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

local Settings = {}

local store

-- Open the settings file on first use.
local function open()
    if not store then
        store = LuaSettings:open(DataStorage:getSettingsDir() .. "/cyberui.lua")
    end
    return store
end

-- Read a setting, or `default` when it was never saved.
function Settings.get(key, default)
    local v = open():readSetting(key)
    if v == nil then return default end
    return v
end

-- Save a setting in memory; flush() writes it to disk.
function Settings.set(key, value)
    open():saveSetting(key, value)
end

-- Save a setting and write it to disk at once.
function Settings.save(key, value)
    Settings.set(key, value)
    Settings.flush()
end

-- Write pending changes to disk.
function Settings.flush()
    if store then store:flush() end
end

return Settings
