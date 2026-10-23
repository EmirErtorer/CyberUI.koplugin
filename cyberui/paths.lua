-- Where the plugin's own files live (fonts, icons), found from this file's
-- location so it works wherever KOReader keeps its plugins.

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

-- A font file's path as seen from KOReader's fonts folder. Font:getFace
-- puts that folder in front of every name in releases up to 2026.07 (later
-- ones also take absolute paths), so a relative path works in all of them.
function Paths.fontRelative(path)
    local ffiUtil = require("ffi/util")
    local fontdir = ffiUtil.realpath(require("fontlist").fontdir)
    local file = ffiUtil.realpath(path) or path
    if not fontdir then return file end
    local a, b = {}, {}
    for part in fontdir:gmatch("[^/]+") do a[#a + 1] = part end
    for part in file:gmatch("[^/]+") do b[#b + 1] = part end
    local same = 0
    while same < #a and same < #b and a[same + 1] == b[same + 1] do same = same + 1 end
    local out = {}
    for _i = same + 1, #a do out[#out + 1] = ".." end
    for i = same + 1, #b do out[#out + 1] = b[i] end
    return table.concat(out, "/")
end

-- A plugin file's path as seen from KOReader's fonts folder.
function Paths.fromFonts(rel)
    return Paths.fontRelative(Paths.file(rel))
end

return Paths
