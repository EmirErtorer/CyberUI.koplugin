-- Covers redrawn as character art: the scaled cover is cut into character
-- cells, each cell's brightness picks a character from the chosen set
-- (dense ones where the picture stands out from the background), and on
-- colour screens each character takes its cell's colour. Braille is drawn as
-- dots, eight per cell, for the most detail. A few pixels are sampled per
-- cell, and results are cached per cover, size, set and theme, so a repaint
-- is a single blit.

local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local RenderText = require("ui/rendertext")
local Color = require("cyberui/theme/color")
local Paint = require("cyberui/gfx/paint")
local Paths = require("cyberui/paths")
local Settings = require("cyberui/settings")
local Theme = require("cyberui/theme")
local Text = require("cyberui/gfx/text")
local _ = require("gettext")

local Ascii = {}

-- The character sets: a ramp from empty to full, or a pick(level, row, col,
-- text) function giving a code point (text: the title's code points); `font` when the set needs one
-- beyond Share Tech Mono; `dots` for braille.
Ascii.SETS = {
    { id = "classic", name = _("Classic"), ramp = " .:-=+*#%@" },
    { id = "detailed", name = _("Detailed"),
      ramp = " .'`^\",:;Il!i><~+_-?][}{1)(|\\/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$" },
    { id = "braille", name = _("Braille"), dots = true },
    { id = "blocks", name = _("Blocks"), ramp = " ░▒▓█", font = "JetBrainsMono-Regular.ttf" },
    { id = "binary", name = _("Binary"), pick = function(level, r, c)
        if level < 0.2 then return 32 end
        if level < 0.4 then return 46 end
        return (r * 7 + c * 3 + math.floor(level * 4)) % 2 == 0 and 49 or 48
    end },
    { id = "hex", name = _("Hex dump"), ramp = " .123456789ABCDEF" },
    { id = "glitch", name = _("Glitch"), ramp = " .-~/\\|<>[]{}=#$&@" },
    { id = "title", name = _("Book title"), pick = function(level, r, c, text)
        if level < 0.3 then return 32 end
        local i = (r * 13 + c) % #text + 1
        return text[i]
    end },
}

local by_id = {}
for _i, s in ipairs(Ascii.SETS) do
    if s.ramp then s.cps = Text.codepoints(s.ramp) end
    by_id[s.id] = s
end

-- The chosen set.
function Ascii.set()
    return by_id[Settings.get("ascii_set", "braille")] or Ascii.SETS[1]
end

-- Staggered thresholds for the eight braille dots of a cell (an ordered
-- dither), so mid-tones show as partial patterns instead of vanishing.
local DITHER = { 0.06, 0.56, 0.31, 0.81, 0.69, 0.19, 0.94, 0.44 }

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

-- The monospaced face for art this wide: small characters on thumbnails so
-- the picture still shows; bigger covers get more characters, so more detail.
local function face(set, w, size)
    size = size or (w < Theme.px(60) and 6 or 8)
    return Font:getFace(Paths.fromFonts("fonts/" .. (set.font or "ShareTechMono-Regular.ttf")), size)
end

-- The colour to draw a cell in: its own hue lifted off a dark background or
-- deepened on a light one, so every character shows.
local function cellColour(rgb, dark_bg)
    local top = math.max(rgb[1], rgb[2], rgb[3], 1)
    local f = (dark_bg and math.max(top, 190) or math.min(top, 130)) / top
    return Blitbuffer.ColorRGB32(math.min(255, math.floor(rgb[1] * f)), math.min(255, math.floor(rgb[2] * f)),
        math.min(255, math.floor(rgb[3] * f)), 0xFF)
end

-- Draw `img` as character art into a new w x h buffer (the picture centred).
-- opts: { set, size (base font size), title (for the title set) }.
function Ascii.render(img, w, h, opts)
    opts = opts or {}
    local th = Theme.get()
    local set = opts.set or Ascii.set()
    local iw, ih = img:getWidth(), img:getHeight()
    local f = face(set, iw, opts.size)
    local m = RenderText:getGlyph(f, 0x4D, false)   -- "M" gives the cell width
    local fh, ascent = f.ftsize:getHeightAndAscender()
    local cw = math.max(2, m.ax)
    local ch = math.max(3, math.floor(fh * (set.font and 1 or 0.86)))
    local cols, rows = math.max(1, math.floor(iw / cw)), math.max(1, math.floor(ih / ch))
    local ox = math.floor((w - cols * cw) / 2)
    local oy = math.floor((h - rows * ch) / 2)
    local sx, sy = math.floor((iw - cols * cw) / 2), math.floor((ih - rows * ch) / 2)

    -- brightness at a point of the picture, and its colour
    local function at(px, py)
        local p = img:getPixel(math.min(iw - 1, math.max(0, px)), math.min(ih - 1, math.max(0, py))):getColorRGB32()
        return (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255, p.r, p.g, p.b
    end

    -- sample every cell: 8 points for braille dots, 4 for a character
    local points = set.dots
        and { { 0.25, 0.125 }, { 0.25, 0.375 }, { 0.25, 0.625 }, { 0.25, 0.875 }, { 0.75, 0.125 }, { 0.75, 0.375 }, { 0.75, 0.625 }, { 0.75, 0.875 } }
        or { { 0.3, 0.3 }, { 0.7, 0.3 }, { 0.3, 0.7 }, { 0.7, 0.7 } }
    local cells = {}
    local lo, hi = 1, 0
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            local x0, y0 = sx + c * cw, sy + r * ch
            local sum, sr, sg, sb, sub = 0, 0, 0, 0, {}
            for k, p in ipairs(points) do
                local l, pr, pg, pb = at(x0 + math.floor(cw * p[1]), y0 + math.floor(ch * p[2]))
                sub[k] = l
                sum, sr, sg, sb = sum + l, sr + pr, sg + pg, sb + pb
                if l < lo then lo = l end
                if l > hi then hi = l end
            end
            local n = #points
            cells[#cells + 1] = { l = sum / n, sub = sub, rgb = { sr / n, sg / n, sb / n } }
        end
    end

    -- dense where the picture stands out from the background: the bright
    -- parts on a dark background, the dark parts on a light one
    local dark_bg = Color.luminance(th.rgb.bg) < 0.5
    local span = math.max(0.05, hi - lo)
    local function level(l)
        local t = (l - lo) / span
        return dark_bg and t or 1 - t
    end
    local out = Blitbuffer.new(w, h, th.colour and Blitbuffer.TYPE_BBRGB32 or Blitbuffer.TYPE_BB8)
    out:fill(th.c.bg)
    local title = Text.codepoints(opts.title and opts.title:upper():gsub("%s+", "") or "#")
    if #title == 0 then title = { 35 } end
    local dot = math.max(1, math.floor(cw / 4))
    local i = 0
    for r = 0, rows - 1 do
        local y = oy + r * ch
        for c = 0, cols - 1 do
            i = i + 1
            local cell = cells[i]
            local color = th.colour and cellColour(cell.rgb, dark_bg) or th.c.ink
            local x = ox + c * cw
            if set.dots then
                for k, p in ipairs(points) do
                    if level(cell.sub[k]) > DITHER[k] then
                        Paint.fill(out, x + math.floor(cw * p[1]) - math.floor(dot / 2), y + math.floor(ch * p[2]) - math.floor(dot / 2), dot, dot, color)
                    end
                end
            else
                local t = level(cell.l)
                local cp = set.pick and set.pick(t, r, c, title)
                    or set.cps[math.max(1, math.min(#set.cps, math.floor(t * (#set.cps - 1) + 1.5)))]
                if cp ~= 32 then
                    local g = RenderText:getGlyph(f, cp, false)
                    local gw, gh = g.bb:getWidth(), g.bb:getHeight()
                    if th.colour then
                        out:colorblitFromRGB32(g.bb, x + g.l, y + ascent - g.t, 0, 0, gw, gh, color)
                    else
                        out:colorblitFrom(g.bb, x + g.l, y + ascent - g.t, 0, 0, gw, gh, color)
                    end
                end
            end
        end
    end
    return out
end

-- The art of a scaled cover at the cover's own size, drawn once and reused.
function Ascii.get(path, img, title)
    local th = Theme.get()
    local set = Ascii.set()
    local key = path .. "|" .. tostring(img) .. "|" .. set.id .. "|" .. th.version
    tick = tick + 1
    local e = cache[key]
    if e then e.used = tick; return e.bb end
    if count >= MAX then evict() end
    local bb = Ascii.render(img, img:getWidth(), img:getHeight(), { set = set, title = title })
    cache[key] = { bb = bb, used = tick }
    count = count + 1
    return bb
end

return Ascii
