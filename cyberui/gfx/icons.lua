-- Line icons from the plugin's icons folder, drawn in any theme colour. Each
-- icon is rasterised once per size into a coverage mask and reused.

local Blitbuffer = require("ffi/blitbuffer")
local RenderImage = require("ui/renderimage")
local Color = require("cyberui/theme/color")
local Paths = require("cyberui/paths")

local Icons = {}

local masks = {}   -- "name|size" -> BB8 coverage mask, or false when it failed

-- Rasterise an icon into a mask: 255 where its lines are, 0 elsewhere.
local function build(name, size)
    local raw, straight = RenderImage:renderSVGImageFile(Paths.file("icons/" .. name .. ".svg"), size, size)
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

-- Draw icon `name` at size x size with its top-left at (x, y).
function Icons.draw(bb, name, x, y, size, color)
    local key = name .. "|" .. size
    local mask = masks[key]
    if mask == nil then
        mask = build(name, size)
        masks[key] = mask
    end
    if not mask then return end
    local w, h = mask:getWidth(), mask:getHeight()
    if Color.isRGB(color) then
        bb:colorblitFromRGB32(mask, x, y, 0, 0, w, h, color)
    else
        bb:colorblitFrom(mask, x, y, 0, 0, w, h, color)
    end
end

-- Free every mask (when CyberUI is closed for good).
function Icons.free()
    for k, mask in pairs(masks) do
        if mask then mask:free() end
        masks[k] = nil
    end
end

return Icons
