-- The one list of looks CyberUI knows. A new colour scheme or style is a data
-- file in cyberui/themes plus its id here; a new font set is an entry in
-- cyberui/themes/fonts.lua. Nothing else needs to change.

local Settings = require("cyberui/settings")

local Registry = {}

Registry.STYLES = { "cyberdeck" }
Registry.SCHEMES = { "mono", "graphite", "neon", "synthwave", "bloodline", "terminal", "amber", "custom" }

local loaded = {}

-- Load a theme data file once.
local function load(id)
    if loaded[id] == nil then
        local ok, data = pcall(require, "cyberui/themes/" .. id)
        loaded[id] = ok and data or false
    end
    return loaded[id] or nil
end

-- Every font set, in menu order.
function Registry.fontSets()
    return load("fonts") or {}
end

-- A font installed on the device as a set: its file for every role but mono.
-- Ids look like "device:<path>".
local function deviceSet(id)
    local path = id:match("^device:(.+)$")
    if not path or not require("libs/libkoreader-lfs").attributes(path, "mode") then return nil end
    return { id = id, device = true, name = Registry.fontName(path), note = path,
        display = path, title = path, body = path, mono = "ShareTechMono-Regular.ttf", scale = 1 }
end

-- A readable name from a font file's name: "NotoSans-Bold.ttf" -> "NotoSans Bold".
function Registry.fontName(path)
    return (path:match("([^/]+)%.%w+$") or path):gsub("[-_]+", " ")
end

-- The font set with this id (a device font when it starts with "device:"),
-- or the first one.
function Registry.fontSet(id)
    local dev = id and deviceSet(id)
    if dev then return dev end
    local sets = Registry.fontSets()
    for _i, s in ipairs(sets) do
        if s.id == id then return s end
    end
    return sets[1]
end

-- The style with this id, or the first one.
function Registry.style(id)
    return load(id) or load(Registry.STYLES[1])
end

-- The colour scheme with this id, or the first one. Custom is built from the
-- reader's saved colours each time, so edits show at once.
function Registry.scheme(id)
    if id == "custom" then
        local Custom = load("custom")
        return Custom.build(Settings.get("custom_accent"), Settings.get("custom_accent2"))
    end
    return load(id) or load(Registry.SCHEMES[1])
end

-- Ids and names of the schemes to offer, in menu order: on a screen without
-- colour only the grey ones (colours would just turn into greys there).
function Registry.schemeList()
    local colour = require("device").screen:isColorEnabled()
    local list = {}
    for _i, id in ipairs(Registry.SCHEMES) do
        local s = Registry.scheme(id)
        if s and (colour or s.grey) then list[#list + 1] = { id = id, name = s.name } end
    end
    return list
end

return Registry
