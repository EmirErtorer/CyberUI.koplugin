-- Where the plugin's own files live (fonts, icons), found from this file's
-- location so it works wherever KOReader keeps its plugins. Always absolute:
-- KOReader reads a relative font path as one inside its own fonts folder.

local lfs = require("libs/libkoreader-lfs")

local Paths = {}

local source = debug.getinfo(1, "S").source:gsub("^@", "")
local root = source:match("^(.*)/cyberui/paths%.lua$") or "."
if root:sub(1, 1) ~= "/" then
    root = lfs.currentdir() .. "/" .. root:gsub("^%./", "")
end
Paths.root = root

-- Absolute path of a file inside the plugin folder.
function Paths.file(rel)
    return Paths.root .. "/" .. rel
end

return Paths
