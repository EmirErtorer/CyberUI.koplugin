-- Line icons from the plugin's icons folder, drawn in any theme colour. Each
-- icon is rasterised once per size into a coverage mask and reused. An icon
-- may have an accent layer (<name>.accent.svg: status lights and the like)
-- drawn on top in a second colour. Icons the device already has can be used
-- too: "reader:<file>" is one in KOReader's data icons folder, "ko:<file>" one
-- of KOReader's stock set.

local Blitbuffer = require("ffi/blitbuffer")
local DataStorage = require("datastorage")
local RenderImage = require("ui/renderimage")
local Color = require("cyberui/theme/color")
local Paths = require("cyberui/paths")
local lfs = require("libs/libkoreader-lfs")
local _ = require("cyberui/gettext")

local Icons = {}

local masks = {}   -- "name|size" -> BB8 coverage mask, or false when it failed

-- The folder for icons the reader adds (they survive CyberUI updates).
function Icons.userDir()
    return DataStorage:getSettingsDir() .. "/cyberui-icons"
end

-- Where the device's own icons live, by the prefix an id carries (KOReader's
-- stock paths are relative to its folder).
local DEVICE_DIRS = {
    reader = function() return DataStorage:getDataDir() .. "/icons" end,
    ko = function() return "resources/icons/mdlight" end,
}

-- KOReader's state icons (rotations, Wi-Fi strengths...) are variants, not
-- icons to put on a button.
local KO_SKIP = { "^rotation%.", "^direction%.", "^dogear", "^cre%.render", "^wifi%.open%.", "^wifi%.secure%.",
    "^position%.marker", "%.alpha$", "%.rtl$", "^icon%-not%-found", "^texture%-box" }

-- The icon's source and file name when it is a device icon ("ko:menu.svg").
local function deviceIcon(name)
    local kind, file = name:match("^(%a+):([^/]+)$")
    if kind and DEVICE_DIRS[kind] then return kind, file end
end

-- Is this one of the plugin's or the reader's own icons (a bare name)?
local function isBare(name)
    return not name:find("/", 1, true) and not deviceIcon(name)
end

-- The file of an icon: a path as it is, a device icon in its folder (the
-- plugin's tools icon when it has gone), else the reader's own icon of that
-- name, else the plugin's.
local function fileOf(name)
    if name:find("/", 1, true) then return name end
    local kind, file = deviceIcon(name)
    if kind then
        local path = DEVICE_DIRS[kind]() .. "/" .. file
        if lfs.attributes(path, "mode") == "file" then return path end
        return Paths.file("icons/tools.svg")
    end
    local own = Icons.userDir() .. "/" .. name .. ".svg"
    if lfs.attributes(own, "mode") == "file" then return own end
    return Paths.file("icons/" .. name .. ".svg")
end

-- Rasterise an icon file into a mask: 255 where its lines are, 0 elsewhere;
-- false when there is no such file. A name with a slash is a file path
-- (another plugin's own icon).
local function build(name, size)
    local file = fileOf(name)
    if lfs.attributes(file, "mode") ~= "file" then return false end
    local raw, straight = RenderImage:renderSVGImageFile(file, size, size)
    if not raw then return false end
    local w, h = raw:getWidth(), raw:getHeight()
    local mask = Blitbuffer.new(w, h, Blitbuffer.TYPE_BB8)
    mask:fill(Blitbuffer.COLOR_WHITE)
    if straight then mask:alphablitFrom(raw, 0, 0, 0, 0, w, h)
    else mask:pmulalphablitFrom(raw, 0, 0, 0, 0, w, h) end
    raw:free()
    -- flip the pixels themselves: bb:invert() only sets a flag that the fast
    -- C blitter ignores, which left icons blank in night mode
    mask:invertRect(0, 0, w, h)
    return mask
end

-- The cached mask of an icon file at a size.
local function mask(name, size)
    local key = name .. "|" .. size
    local m = masks[key]
    if m == nil then
        m = build(name, size)
        masks[key] = m
    end
    return m
end

-- Blit a mask in a colour.
local function blit(bb, m, x, y, color)
    local w, h = m:getWidth(), m:getHeight()
    if Color.isRGB(color) then
        bb:colorblitFromRGB32(m, x, y, 0, 0, w, h, color)
    else
        bb:colorblitFrom(m, x, y, 0, 0, w, h, color)
    end
end

-- The sorted names of the SVG files in a folder (none when it is missing).
local function svgFiles(dir)
    local out = {}
    local ok, iter, state = pcall(lfs.dir, dir)
    if ok then
        for file in iter, state do
            if file:match("^[^.].*%.svg$") then out[#out + 1] = file end
        end
    end
    table.sort(out)
    return out
end

-- The names of the icons that can be chosen from a source: "set" (the
-- default: the plugin's and the reader's cyberui-icons, by bare name),
-- "reader" or "ko" (the device's). The accent layers are part of their icon.
function Icons.list(source)
    local out = {}
    if DEVICE_DIRS[source] then
        for _i, file in ipairs(svgFiles(DEVICE_DIRS[source]())) do
            local stem = file:match("^(.+)%.svg$")
            local skip = false
            for _j, pat in ipairs(source == "ko" and KO_SKIP or {}) do skip = skip or stem:match(pat) ~= nil end
            if not skip then out[#out + 1] = source .. ":" .. file end
        end
        return out
    end
    local seen = {}
    for _i, dir in ipairs({ Paths.file("icons"), Icons.userDir() }) do
        for _j, file in ipairs(svgFiles(dir)) do
            local name = file:match("^(.+)%.svg$")
            if not name:find(".accent", 1, true) and not seen[name] then
                seen[name] = true
                out[#out + 1] = name
            end
        end
    end
    table.sort(out)
    return out
end

-- The sources an icon can come from, { id, label, names } for each one that
-- has any icon.
function Icons.sources()
    local out = {}
    for _i, src in ipairs({ { id = "set", label = _("CYBERUI") }, { id = "reader", label = _("READER") }, { id = "ko", label = _("KOREADER") } }) do
        src.names = Icons.list(src.id)
        if #src.names > 0 then out[#out + 1] = src end
    end
    return out
end

-- The source id an icon name belongs to.
function Icons.sourceOf(name)
    return deviceIcon(name or "") or "set"
end

-- Draw icon `name` at size x size with its top-left at (x, y), its accent
-- layer (if it has one) in `accent` (`color` when not given).
function Icons.draw(bb, name, x, y, size, color, accent)
    local m = mask(name, size)
    if not m then return end
    blit(bb, m, x, y, color)
    local a = isBare(name) and mask(name .. ".accent", size)
    if a then blit(bb, a, x, y, accent or color) end
end

-- Free every mask (when CyberUI is closed for good).
function Icons.free()
    for k, m in pairs(masks) do
        if m then m:free() end
        masks[k] = nil
    end
end

return Icons
