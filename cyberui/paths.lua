-- Where the plugin's own files live (fonts, icons), found from this file's
-- location so it works wherever KOReader keeps its plugins.

local Paths = {}

local source = debug.getinfo(1, "S").source:gsub("^@", "")
Paths.root = source:match("^(.*)/cyberui/paths%.lua$") or "."

-- Absolute path of a file inside the plugin folder.
function Paths.file(rel)
    return Paths.root .. "/" .. rel
end

return Paths
