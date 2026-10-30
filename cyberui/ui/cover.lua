-- A book's cover tile in the reader's cover style: ASCII art of the cover
-- (the default; in colour on colour screens), the cover image, or a typeset
-- "data card" with the title, author and a pattern, which is also what any
-- style falls back to without a cover. Can carry a small badge (NEW, 64%,
-- DONE). A folder shows its first book's cover stacked on two sheets with a
-- FOLDER strip; an empty one a card with a folder icon.

local Element = require("cyberui/ui/element")
local Ascii = require("cyberui/gfx/ascii")
local Books = require("cyberui/data/books")
local Covers = require("cyberui/data/covers")
local Icons = require("cyberui/gfx/icons")
local Paint = require("cyberui/gfx/paint")
local Settings = require("cyberui/settings")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local Cover = Element:extend({})

-- The patterns a data card can wear, picked from the title so a book keeps its look.
local PATTERNS = { "h", "v", "grid", "solid", "plain" }

-- A stable small number from a string.
local function hash(s)
    local h = 0
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 1000003 end
    return h
end

-- Draw the card's background pattern inside the frame.
local function pattern(bb, x, y, w, h, name, th)
    local period, thick = Theme.px(7), Theme.px(2)
    if name == "h" then Paint.stripes(bb, x, y, w, h, "h", period, thick, th.c.line)
    elseif name == "v" then Paint.stripes(bb, x, y, w, h, "v", period, thick, th.c.line)
    elseif name == "grid" then
        Paint.stripes(bb, x, y, w, h, "h", period * 2, thick, th.c.line)
        Paint.stripes(bb, x, y, w, h, "v", period * 2, thick, th.c.line)
    elseif name == "solid" then Paint.fill(bb, x, y, w, h, th.c.soft) end
end

-- The narrowest a cover may be in the library grid, per size setting (base
-- pixels): the grid fits as many as the screen allows, in any orientation.
Cover.SIZES = { s = 90, m = 120, l = 170, xl = 240 }

-- The recent list on home, per size setting (base pixels): row height, cover
-- width and cover height.
Cover.RECENT_SIZES = {
    s = { row = 54, w = 30, h = 44 },
    m = { row = 74, w = 45, h = 66 },
    l = { row = 96, w = 60, h = 88 },
    xl = { row = 126, w = 80, h = 118 },
}

-- The recent list size setting, "s" when unset or unknown.
function Cover.recentSizeKey()
    local k = Settings.get("recent_cover_size", "s")
    return Cover.RECENT_SIZES[k] and k or "s"
end

-- Row height, cover width and cover height for the recent list on home.
function Cover.recentSize()
    local s = Cover.RECENT_SIZES[Cover.recentSizeKey()]
    return Theme.px(s.row), Theme.px(s.w), Theme.px(s.h)
end

-- The cover style: "ascii" (the default), "image" or "card". Readers who
-- turned real covers on before styles existed keep them.
function Cover.style()
    local s = Settings.get("cover_style")
    if s then return s end
    return Settings.get("cover_images") and "image" or "ascii"
end

-- How deep the tile's top-right corner is cut, or nil when the style has
-- no chamfers.
function Cover:cut(th)
    if not th.decor.chamfer then return nil end
    return self.w >= Theme.px(120) and th.size.cut or th.size.cut_small
end

-- Draw the tile. A folder (stack = true) is its first book's cover with two
-- sheets peeking out behind it and a FOLDER strip along the bottom.
function Cover:draw(bb, x, y)
    if not self.stack then return self:drawFace(bb, x, y) end
    local th = Theme.get()
    local w, h = self.w, self.h
    local off = math.max(Theme.px(4), math.floor(w / 24))
    local stroke = th.size.stroke
    Paint.fill(bb, x, y, w, h, th.c.bg)
    -- the sheets behind, offset up and to the right
    Paint.frame(bb, x + 2 * off, y, w - 2 * off, h - 2 * off, stroke, th.c.muted)
    Paint.fill(bb, x + off, y + off, w - 2 * off, h - 2 * off, th.c.bg)
    Paint.frame(bb, x + off, y + off, w - 2 * off, h - 2 * off, stroke, th.c.ink)
    -- the front cover
    self.w, self.h = w - 2 * off, h - 2 * off
    self:drawFace(bb, x, y + 2 * off)
    self:drawFolderStrip(bb, x, y + 2 * off, th)
    self.w, self.h = w, h
end

-- The FOLDER strip along a folder's bottom edge: icon, word and count.
function Cover:drawFolderStrip(bb, x, y, th)
    local kind = self.w < Theme.px(90) and "micro" or "label"
    local sh = Text.height(kind) + Theme.px(6)
    local sy = y + self.h - sh
    Paint.fill(bb, x, sy, self.w, sh, th.c.ink)
    local isz = sh - Theme.px(6)
    Icons.draw(bb, "folder", x + Theme.px(4), sy + Theme.px(3), isz, th.c.on_ink, th.c.on_ink)
    local text = self.count and string.format("FOLDER // %d", self.count) or "FOLDER"
    Text.draw(bb, x + Theme.px(8) + isz, sy + Theme.px(3), kind, Text.fit(kind, text, self.w - isz - Theme.px(12)), th.c.on_ink)
end

-- Draw a cover face: image or data card (an empty slot is just its frame),
-- then badge and folder icon, then the cut corner over all of it.
function Cover:drawFace(bb, x, y)
    local th = Theme.get()
    local w, h = self.w, self.h
    local stroke = th.size.stroke
    Paint.fill(bb, x, y, w, h, th.c.bg)
    local drawn = false
    local style = Cover.style()
    if self.path and style ~= "card" then
        local img = Covers.get(self.path, w - 2 * stroke, h - 2 * stroke)
        if img and style == "ascii" then img = Ascii.get(self.path, img, Books.info(self.path).title) end
        if img then
            local iw, ih = img:getWidth(), img:getHeight()
            local ix, iy = x + math.floor((w - iw) / 2), y + math.floor((h - ih) / 2)
            -- night mode inverts the whole screen, so a picture goes in inverted to come out as it is
            if style ~= "ascii" and Theme.nightMode() then bb:invertblitFrom(img, ix, iy, 0, 0, iw, ih)
            else bb:blitFrom(img, ix, iy, 0, 0, iw, ih) end
            drawn = true
        end
    end
    if not drawn and (self.path or self.title) then self:drawCard(bb, x, y, th) end
    if self.folder and not self.path then self:drawFolderTab(bb, x, y, th) end
    if self.badge then self:drawBadge(bb, x, y, th) end
    local cut = self:cut(th)
    if cut then
        Paint.cutCorners(bb, x, y, w, h, cut, "r", th.c.bg)
        Paint.chamferFrame(bb, x, y, w, h, cut, "r", stroke, th.c.ink)
    else
        Paint.frame(bb, x, y, w, h, stroke, th.c.ink)
    end
end

-- The typeset card: pattern, then a box with title and author at the bottom.
function Cover:drawCard(bb, x, y, th)
    local w, h = self.w, self.h
    local info = self.path and Books.info(self.path)
    local title = self.title or (info and info.title) or ""
    local author = self.author or (info and info.author)
    pattern(bb, x, y, w, h, PATTERNS[hash(title) % #PATTERNS + 1], th)
    if h < Theme.px(60) then return end
    local pad = math.max(Theme.px(4), math.floor(w / 16))
    local inner = w - 4 * pad
    local kind = w < Theme.px(90) and "micro" or "label"
    local lines = Text.wrap(kind, title, inner, h < Theme.px(130) and 2 or 3)
    local lh = Text.height(kind)
    local box_h = #lines * lh + 2 * pad
    local alh = Text.height("micro")
    if author and w >= Theme.px(70) then box_h = box_h + alh end
    local bx, by = x + pad, y + h - pad - box_h
    Paint.fill(bb, bx, by, w - 2 * pad, box_h, th.c.bg)
    for i, line in ipairs(lines) do
        Text.draw(bb, bx + pad, by + pad + (i - 1) * lh, kind, Text.fit(kind, line, inner), th.c.ink)
    end
    if author and w >= Theme.px(70) then
        Text.draw(bb, bx + pad, by + pad + #lines * lh, "micro", Text.fit("micro", author, inner), th.c.muted)
    end
end

-- A small label in the top-right corner, kept clear of the cut corner.
function Cover:drawBadge(bb, x, y, th)
    local s = Text.fit("micro", self.badge)
    local pad = Theme.px(4)
    local pad_r = math.max(pad, self:cut(th) or 0)
    local bw = Text.width("micro", s) + pad + pad_r
    local bh = Text.height("micro") + Theme.px(2)
    local fill = self.badge_on and th.c.accent or th.c.ink
    local fg = self.badge_on and th.c.on_accent or th.c.on_ink
    Paint.fill(bb, x + self.w - bw, y, bw, bh, fill)
    Text.draw(bb, x + self.w - bw + pad, y + Theme.px(1), "micro", s, fg)
end

-- An empty folder's card: a large folder icon in the middle.
function Cover:drawFolderTab(bb, x, y, th)
    local size = math.floor(math.min(self.w, self.h) * 0.42)
    local ix, iy = x + math.floor((self.w - size) / 2), y + math.floor((self.h - size) / 2) - Theme.px(8)
    Paint.fill(bb, ix - Theme.px(4), iy - Theme.px(4), size + Theme.px(8), size + Theme.px(8), th.c.bg)
    Icons.draw(bb, "folder", ix, iy, size, th.c.ink, th.c.accent)
end

return Cover
