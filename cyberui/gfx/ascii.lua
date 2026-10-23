-- Covers redrawn as ASCII art: the scaled cover is cut into character cells,
-- each cell's brightness picks a character from a ramp (dense ones where the
-- picture has the most ink against the background), and on colour screens
-- each character takes its cell's colour. A few pixels are sampled per cell,
-- and each result is drawn once and cached per cover, size and theme, so a
-- repaint is a single blit.

local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local RenderText = require("ui/rendertext")
local Color = require("cyberui/theme/color")
local Paths = require("cyberui/paths")
local Theme = require("cyberui/theme")

local Ascii = {}

-- From empty to full: the brightness ramp, one byte per character.
local RAMP = " .:-=+*#%@"

local MAX = 36
local cache = {}   -- key -> { bb, used }
local count, tick = 0, 0

-- Drop the least recently used result.
local function evict()
    local oldest, key
    for k, e in pairs(cache) do
        if not oldest or e.used < oldest then oldest, key = e.used, k end
    end
    if key then
        cache[key].bb:free()
        cache[key] = nil
        count = count - 1
    end
end

-- The monospaced face for a cover this wide: smaller characters on small
-- covers so the picture still shows.
local function face(w)
    local size = w < Theme.px(60) and 6 or w < Theme.px(140) and 8 or 10
    return Font:getFace(Paths.fromFonts("fonts/ShareTechMono-Regular.ttf"), size)
end

-- Draw `img` (a scaled cover) as ASCII into a new buffer of the same size.
local function render(img, th)
    local w, h = img:getWidth(), img:getHeight()
    local f = face(w)
    local cell = RenderText:getGlyph(f, 0x4D, false)   -- "M" gives the cell width
    local cw = math.max(2, cell.ax)
    local ch = math.max(3, math.floor(f.ftsize:getHeightAndAscender() * 0.86))
    local ascent = select(2, f.ftsize:getHeightAndAscender())
    local cols, rows = math.max(1, math.floor(w / cw)), math.max(1, math.floor(h / ch))
    local ox, oy = math.floor((w - cols * cw) / 2), math.floor((h - rows * ch) / 2)

    -- sample four points per cell: brightness and colour
    local lum, rgb = {}, {}
    local lo, hi = 1, 0
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            local x0, y0 = ox + c * cw, oy + r * ch
            local sr, sg, sb = 0, 0, 0
            for _i, p in ipairs({ { 0.3, 0.3 }, { 0.7, 0.3 }, { 0.3, 0.7 }, { 0.7, 0.7 } }) do
                local px = img:getPixel(math.min(w - 1, x0 + math.floor(cw * p[1])), math.min(h - 1, y0 + math.floor(ch * p[2]))):getColorRGB32()
                sr, sg, sb = sr + px.r, sg + px.g, sb + px.b
            end
            local i = r * cols + c + 1
            rgb[i] = { sr / 4, sg / 4, sb / 4 }
            local l = (0.299 * sr + 0.587 * sg + 0.114 * sb) / 1020
            lum[i] = l
            if l < lo then lo = l end
            if l > hi then hi = l end
        end
    end

    -- dense characters for what stands out from the background: the bright
    -- parts on a dark background, the dark parts on a light one
    local dark_bg = Color.luminance(th.rgb.bg) < 0.5
    local span = math.max(0.05, hi - lo)
    local out = Blitbuffer.new(w, h, th.colour and Blitbuffer.TYPE_BBRGB32 or Blitbuffer.TYPE_BB8)
    out:fill(th.c.bg)
    local n = #RAMP
    for r = 0, rows - 1 do
        local baseline = oy + r * ch + ascent
        for c = 0, cols - 1 do
            local i = r * cols + c + 1
            local t = (lum[i] - lo) / span
            if not dark_bg then t = 1 - t end
            local k = math.max(1, math.min(n, math.floor(t * (n - 1) + 1.5)))
            if k > 1 then
                local g = RenderText:getGlyph(f, RAMP:byte(k), false)
                local x, y = ox + c * cw + g.l, baseline - g.t
                local gw, gh = g.bb:getWidth(), g.bb:getHeight()
                if th.colour then
                    -- keep the cell's hue but lift it off a dark background,
                    -- or deepen it on a light one, so every character shows
                    local col = rgb[i]
                    local top = math.max(col[1], col[2], col[3], 1)
                    local f2 = (dark_bg and math.max(top, 190) or math.min(top, 130)) / top
                    out:colorblitFromRGB32(g.bb, x, y, 0, 0, gw, gh, Blitbuffer.ColorRGB32(math.min(255, math.floor(col[1] * f2)),
                        math.min(255, math.floor(col[2] * f2)), math.min(255, math.floor(col[3] * f2)), 0xFF))
                else
                    out:colorblitFrom(g.bb, x, y, 0, 0, gw, gh, th.c.ink)
                end
            end
        end
    end
    return out
end

-- The ASCII version of a scaled cover, drawn once and then reused.
function Ascii.get(path, img)
    local th = Theme.get()
    local key = path .. "|" .. tostring(img) .. "|" .. th.version
    tick = tick + 1
    local e = cache[key]
    if e then e.used = tick; return e.bb end
    if count >= MAX then evict() end
    local bb = render(img, th)
    cache[key] = { bb = bb, used = tick }
    count = count + 1
    return bb
end

-- Free every result (when CyberUI is closed for good).
function Ascii.free()
    for k, e in pairs(cache) do
        e.bb:free()
        cache[k] = nil
    end
    count = 0
end

return Ascii
