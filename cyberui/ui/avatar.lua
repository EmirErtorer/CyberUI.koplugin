-- The operator's face: the photo they chose, else a 5 x 5 glyph made from their
-- handle (mirrored, so it reads as a face-like emblem). Cut at the corners
-- like the rest of the style; tap it to change the photo.

local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Profile = require("cyberui/data/profile")
local Theme = require("cyberui/theme")

local Avatar = Element:extend({ size = 88, cut = "cut_small" })

-- Square, whatever the room given.
function Avatar:naturalWidth() return Theme.px(self.size) end
function Avatar:naturalHeight() return Theme.px(self.size) end

-- The glyph's 5 x 5 cells for a seed: three columns drawn, two mirrored.
local function glyph(seed)
    local rnd = Profile.rng(seed)
    local rows = {}
    for r = 1, 5 do
        local c = { rnd() > 0.5, rnd() > 0.5, rnd() > 0.4 }
        rows[r] = { c[1], c[2], c[3], c[2], c[1] }
    end
    return rows
end

-- Draw the photo or the glyph in a frame.
function Avatar:draw(bb, x, y)
    local th = Theme.get()
    local w, h = self.w, self.h
    local stroke = th.size.stroke
    local cut = th.size[self.cut]
    local photo = Profile.photo(math.min(w, h) - 2 * stroke)
    Paint.fill(bb, x, y, w, h, th.c.bg)
    if photo then
        bb:blitFrom(photo, x + stroke, y + stroke, 0, 0, photo:getWidth(), photo:getHeight())
    else
        local inner = math.min(w, h) - 2 * stroke
        local pad = math.floor(inner / 12)
        local cell = math.floor((inner - 2 * pad) / 5)
        local ox = x + stroke + math.floor((inner - cell * 5) / 2)
        local oy = y + stroke + math.floor((inner - cell * 5) / 2)
        for r, row in ipairs(glyph(self.seed or "")) do
            for c, on in ipairs(row) do
                if on then Paint.fill(bb, ox + (c - 1) * cell, oy + (r - 1) * cell, cell, cell, th.c.ink) end
            end
        end
    end
    Paint.cutCorners(bb, x, y, w, h, cut, "tb", th.c.bg)
    Paint.chamferFrame(bb, x, y, w, h, cut, "tb", stroke, th.c.ink)
end

return Avatar
