-- The one list of looks CyberUI knows. A new colour scheme or style is a data
-- file in this folder plus its id here; nothing else needs to change.

local Settings = require("cyberui/settings")

local Registry = {}

Registry.STYLES = { "cyberdeck" }
Registry.SCHEMES = { "mono", "neon", "terminal", "amber", "custom" }

local loaded = {}

-- Load a theme data file once.
local function load(id)
    if loaded[id] == nil then
        local ok, data = pcall(require, "cyberui/themes/" .. id)
        loaded[id] = ok and data or false
    end
    return loaded[id] or nil
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

-- Ids and names of every scheme, in menu order.
function Registry.schemeList()
    local list = {}
    for _, id in ipairs(Registry.SCHEMES) do
        local s = Registry.scheme(id)
        if s then list[#list + 1] = { id = id, name = s.name } end
    end
    return list
end

return Registry
