-- Shape drawing for every widget, built only from KOReader's C rectangle fills
-- so it stays fast in any rotation: plain and chamfered boxes, outlines, corner
-- brackets, stripes, barcodes and ruler ticks. Colours come from the theme.

local Color = require("cyberui/theme/color")

local Paint = {}

local floor = math.floor

-- Fill a rectangle with a theme colour (grey or RGB).
local function fill(bb, x, y, w, h, c)
    if w <= 0 or h <= 0 then return end
    if Color.isRGB(c) then bb:paintRectRGB32(x, y, w, h, c) else bb:paintRect(x, y, w, h, c) end
end
Paint.fill = fill

-- Outline a rectangle with lines `t` pixels thick.
function Paint.frame(bb, x, y, w, h, t, c)
    fill(bb, x, y, w, t, c)
    fill(bb, x, y + h - t, w, t, c)
    fill(bb, x, y + t, t, h - 2 * t, c)
    fill(bb, x + w - t, y + t, t, h - 2 * t, c)
end

-- Which corners are cut: a string of t(op-left), r (top-right), b (bottom-right)
-- and l (bottom-left), e.g. "tb" for two opposite corners.
local function corners(spec)
    spec = spec or "trbl"
    return spec:find("t", 1, true) ~= nil, spec:find("r", 1, true) ~= nil,
        spec:find("b", 1, true) ~= nil, spec:find("l", 1, true) ~= nil
end

-- Fill a box with chamfered corners `cut` pixels deep.
function Paint.chamfer(bb, x, y, w, h, cut, spec, c)
    cut = math.min(cut, floor(w / 2), floor(h / 2))
    if cut <= 0 then return fill(bb, x, y, w, h, c) end
    local tl, tr, br, bl = corners(spec)
    fill(bb, x, y + cut, w, h - 2 * cut, c)
    for i = 0, cut - 1 do
        local inset = cut - i   -- distance in from the edge on this row
        local lt = tl and inset or 0
        local rt = tr and inset or 0
        fill(bb, x + lt, y + i, w - lt - rt, 1, c)
        local lb = bl and inset or 0
        local rb = br and inset or 0
        fill(bb, x + lb, y + h - 1 - i, w - lb - rb, 1, c)
    end
end

-- Outline a box with chamfered corners, lines `t` pixels thick.
function Paint.chamferFrame(bb, x, y, w, h, cut, spec, t, c)
    cut = math.min(cut, floor(w / 2), floor(h / 2))
    if cut <= 0 then return Paint.frame(bb, x, y, w, h, t, c) end
    local tl, tr, br, bl = corners(spec)
    local diag = floor(t * 1.42 + 0.5)   -- a diagonal stroke looks as thick as a straight one
    -- straight edges, shortened where a corner is cut
    fill(bb, x + (tl and cut or 0), y, w - (tl and cut or 0) - (tr and cut or 0), t, c)
    fill(bb, x + (bl and cut or 0), y + h - t, w - (bl and cut or 0) - (br and cut or 0), t, c)
    fill(bb, x, y + (tl and cut or 0), t, h - (tl and cut or 0) - (bl and cut or 0), c)
    fill(bb, x + w - t, y + (tr and cut or 0), t, h - (tr and cut or 0) - (br and cut or 0), c)
    -- the diagonals, one short run per row
    for i = 0, cut - 1 do
        local inset = cut - i
        if tl then fill(bb, x + inset - 1, y + i, diag, 1, c) end
        if tr then fill(bb, x + w - inset + 1 - diag, y + i, diag, 1, c) end
        if bl then fill(bb, x + inset - 1, y + h - 1 - i, diag, 1, c) end
        if br then fill(bb, x + w - inset + 1 - diag, y + h - 1 - i, diag, 1, c) end
    end
end

-- A chamfered box filled with `fill_c` and outlined with `line_c`.
function Paint.chamferBox(bb, x, y, w, h, cut, spec, t, fill_c, line_c)
    if fill_c then Paint.chamfer(bb, x, y, w, h, cut, spec, fill_c) end
    if line_c then Paint.chamferFrame(bb, x, y, w, h, cut, spec, t, line_c) end
end

-- Corner brackets at the four corners of a box, arms `len` long.
function Paint.brackets(bb, x, y, w, h, len, t, c)
    len = math.min(len, floor(w / 2), floor(h / 2))
    fill(bb, x, y, len, t, c); fill(bb, x, y, t, len, c)
    fill(bb, x + w - len, y, len, t, c); fill(bb, x + w - t, y, t, len, c)
    fill(bb, x, y + h - t, len, t, c); fill(bb, x, y + h - len, t, len, c)
    fill(bb, x + w - len, y + h - t, len, t, c); fill(bb, x + w - t, y + h - len, t, len, c)
end

-- Square brackets on the left and right sides of a box, arms `arm` long.
function Paint.sideBrackets(bb, x, y, w, h, arm, t, c)
    fill(bb, x, y, t, h, c); fill(bb, x + w - t, y, t, h, c)
    fill(bb, x, y, arm, t, c); fill(bb, x, y + h - t, arm, t, c)
    fill(bb, x + w - arm, y, arm, t, c); fill(bb, x + w - arm, y + h - t, arm, t, c)
end

-- Stripes across a box: "h" horizontal, "v" vertical, "d" rising diagonal,
-- "b" falling diagonal; a `thick` line every `period` pixels.
function Paint.stripes(bb, x, y, w, h, dir, period, thick, c)
    if w <= 0 or h <= 0 then return end
    if dir == "h" then
        for yy = 0, h - 1, period do fill(bb, x, y + yy, w, math.min(thick, h - yy), c) end
    elseif dir == "v" then
        for xx = 0, w - 1, period do fill(bb, x + xx, y, math.min(thick, w - xx), h, c) end
    else
        -- diagonals: on each row the stripes shift one pixel
        local run = math.max(1, floor(thick * 1.42 + 0.5))
        for row = 0, h - 1 do
            local shift = (dir == "d" and (h - row) or row) % period
            for xx = shift - period, w - 1, period do
                local x0 = math.max(xx, 0)
                local x1 = math.min(xx + run, w)
                if x1 > x0 then fill(bb, x + x0, y + row, x1 - x0, 1, c) end
            end
        end
    end
end

-- Bar widths of the decorative barcode, repeated across its width.
local BARS = { 3, 2, 1, 3, 4, 1, 1, 3, 2, 2, 1, 4, 3, 1 }

-- A decorative barcode filling the box.
function Paint.barcode(bb, x, y, w, h, unit, c)
    local pos, i = 0, 1
    while pos < w do
        local bar = BARS[i] * unit
        local gap = BARS[(i % #BARS) + 1] * unit
        fill(bb, x + pos, y, math.min(bar, w - pos), h, c)
        pos = pos + bar + gap
        i = (i + 1) % #BARS + 1
    end
end

-- Ruler ticks along a line: a tick `t` wide every `period` pixels.
function Paint.ticks(bb, x, y, w, h, period, t, c)
    for xx = 0, w - 1, period do fill(bb, x + xx, y, t, h, c) end
end

return Paint
