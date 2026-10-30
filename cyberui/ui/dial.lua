-- The colour dial: a ring of hues around a matrix of saturation (across) and
-- brightness (down) cells for the chosen hue, with a targeting reticle on the
-- cell chosen and a marker on the ring. Taps pick: the ring sets the hue, a
-- cell sets saturation and brightness. The ring is drawn once per size and
-- kept as a picture; a repaint draws the picture and the small matrix.

local Blitbuffer = require("ffi/blitbuffer")
local Color = require("cyberui/theme/color")
local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Theme = require("cyberui/theme")

local Dial = Element:extend({ hue = 0, sat = 1, val = 1, size = 320 })

local SEGMENTS = 72          -- hue steps around the ring
local CELLS = 9              -- cells across and down the matrix
local MIN_VAL = 0.08         -- the darkest row of the matrix

local rings = {}             -- side -> picture of the ring
Theme.onChange(function()
    for k, bb in pairs(rings) do
        bb:free()
        rings[k] = nil
    end
end)

-- A colour as the screen should get it: night mode inverts the whole screen, so
-- the colour goes in inverted to come out as it is.
local function shown(rgb)
    if Theme.nightMode() then rgb = { 255 - rgb[1], 255 - rgb[2], 255 - rgb[3] } end
    return Color.toScreen(rgb, Theme.get().colour)
end

-- The dial is square and takes the smaller of the room given and its size.
function Dial:naturalWidth() return Theme.px(self.size) end
function Dial:naturalHeight() return Theme.px(self.size) end
function Dial:layout(w, h)
    local side = math.min(w or Theme.px(self.size), h or Theme.px(self.size), Theme.px(self.size))
    self.w, self.h = side, side
end

-- The ring's and the matrix's measures for a side: centre, outer and inner
-- radius of the ring, half the matrix and the size of a cell.
local function geometry(side)
    local r = math.floor(side / 2) - Theme.px(9)   -- room outside the ring for the degree ticks
    local width = math.max(8, math.floor(r * 0.2))
    local inner = r - width
    local half = math.floor((inner - 6) * 0.70)
    local cell = math.floor(2 * half / CELLS)
    return { cx = math.floor(side / 2), cy = math.floor(side / 2), r = r, inner = inner, width = width, cell = cell, half = cell * CELLS / 2 }
end

-- The picture of the hue ring, on the page colour.
local function ring(side, like)
    local pic = rings[side]
    if pic then return pic end
    local g = geometry(side)
    pic = Blitbuffer.new(side, side, like:getType())
    Paint.fill(pic, 0, 0, side, side, Theme.get().c.bg)
    for i = 0, SEGMENTS - 1 do
        local a0, a1 = math.rad(i * 360 / SEGMENTS), math.rad((i + 1) * 360 / SEGMENTS + 0.6)
        local function pt(radius, a) return { g.cx + radius * math.sin(a), g.cy - radius * math.cos(a) } end
        Paint.polygon(pic, { pt(g.r, a0), pt(g.r, a1), pt(g.inner, a1), pt(g.inner, a0) }, shown(Color.fromHSV((i + 0.5) * 360 / SEGMENTS, 1, 1)))
    end
    -- degree ticks round the outside, longer at the quarters and every thirty
    local th = Theme.get()
    for deg = 0, 350, 10 do
        local a = math.rad(deg)
        local len = Theme.px(deg % 90 == 0 and 8 or (deg % 30 == 0 and 6 or 3))
        local r0 = g.r + Theme.px(2)
        Paint.line(pic, g.cx + r0 * math.sin(a), g.cy - r0 * math.cos(a), g.cx + (r0 + len) * math.sin(a), g.cy - (r0 + len) * math.cos(a), 1, th.c.ink)
    end
    rings[side] = pic
    return pic
end

-- The cell the saturation and brightness fall in, as column and row (1 to CELLS).
local function cellOf(sat, val)
    local col = math.floor(sat * (CELLS - 1) + 0.5) + 1
    local row = math.floor((1 - val) / (1 - MIN_VAL) * (CELLS - 1) + 0.5) + 1
    return math.max(1, math.min(CELLS, col)), math.max(1, math.min(CELLS, row))
end

-- Draw the ring, the matrix, the hue marker and the reticle.
function Dial:draw(bb, x, y)
    local th = Theme.get()
    local side = self.w
    local g = geometry(side)
    bb:blitFrom(ring(side, bb), x, y, 0, 0, side, side)
    Paint.brackets(bb, x, y, side, side, Theme.px(18), th.size.stroke, th.c.ink)
    Paint.fill(bb, x + g.cx - g.half - 3, y + g.cy - g.half - 3, 2 * g.half + 6, 2 * g.half + 6, th.c.bg)
    local ox, oy = x + g.cx - g.half, y + g.cy - g.half
    local gap = 2
    for row = 1, CELLS do
        for col = 1, CELLS do
            local sat = (col - 1) / (CELLS - 1)
            local val = 1 - (row - 1) / (CELLS - 1) * (1 - MIN_VAL)
            Paint.fill(bb, ox + (col - 1) * g.cell, oy + (row - 1) * g.cell, g.cell - gap, g.cell - gap, shown(Color.fromHSV(self.hue, sat, val)))
        end
    end
    -- the reticle: brackets in ink over a second set in the page colour, so it shows on any cell
    local col, row = cellOf(self.sat, self.val)
    local rx, ry = ox + (col - 1) * g.cell - 3, oy + (row - 1) * g.cell - 3
    Paint.brackets(bb, rx - 1, ry - 1, g.cell + 4, g.cell + 4, math.floor(g.cell / 2), 4, th.c.bg)
    Paint.brackets(bb, rx, ry, g.cell + 2, g.cell + 2, math.floor(g.cell / 2), 2, th.c.ink)
    -- the marker on the ring at the hue
    local a = math.rad(self.hue)
    local mr = g.r - g.width / 2
    local mx, my = x + g.cx + mr * math.sin(a), y + g.cy - mr * math.cos(a)
    local m = math.floor(g.width * 0.9)
    Paint.frame(bb, math.floor(mx - m / 2) - 1, math.floor(my - m / 2) - 1, m + 2, m + 2, 4, th.c.bg)
    Paint.frame(bb, math.floor(mx - m / 2), math.floor(my - m / 2), m, m, 2, th.c.ink)
end

-- A tap: on the ring it sets the hue, on a cell the saturation and brightness.
function Dial:on_tap()
    local pos = self.tap_pos
    if not pos then return end
    local g = geometry(self.w)
    local dx, dy = pos.x - self.x - g.cx, pos.y - self.y - g.cy
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist >= g.inner - 2 and dist <= g.r + 4 then
        self.hue = (math.deg(math.atan2(dx, -dy))) % 360
    elseif math.abs(dx) <= g.half and math.abs(dy) <= g.half then
        local col = math.min(CELLS, math.floor((dx + g.half) / g.cell) + 1)
        local row = math.min(CELLS, math.floor((dy + g.half) / g.cell) + 1)
        self.sat = (col - 1) / (CELLS - 1)
        self.val = 1 - (row - 1) / (CELLS - 1) * (1 - MIN_VAL)
    else
        return
    end
    if self.on_change then self.on_change(self.hue, self.sat, self.val) end
end

-- Free the pictures (CyberUI is closed for good).
function Dial.free()
    for k, bb in pairs(rings) do
        bb:free()
        rings[k] = nil
    end
end

return Dial
