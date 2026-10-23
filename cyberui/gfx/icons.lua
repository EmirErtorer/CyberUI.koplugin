-- Line icons from the plugin's icons folder, drawn in any theme colour. Each
-- icon is rasterised once per size into a coverage mask and reused. An icon
-- may have an accent layer (<name>.accent.svg: status lights and the like)
-- drawn on top in a second colour.

local Blitbuffer = require("ffi/blitbuffer")
local RenderImage = require("ui/renderimage")
local Color = require("cyberui/theme/color")
local Paths = require("cyberui/paths")
local lfs = require("libs/libkoreader-lfs")

local Icons = {}

local masks = {}   -- "name|size" -> BB8 coverage mask, or false when it failed

-- Rasterise an icon file into a mask: 255 where its lines are, 0 elsewhere;
-- false when there is no such file.
local function build(name, size)
    local file = Paths.file("icons/" .. name .. ".svg")
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

-- Draw icon `name` at size x size with its top-left at (x, y), its accent
-- layer (if it has one) in `accent` (`color` when not given).
function Icons.draw(bb, name, x, y, size, color, accent)
    local m = mask(name, size)
    if not m then return end
    blit(bb, m, x, y, color)
    local a = mask(name .. ".accent", size)
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
