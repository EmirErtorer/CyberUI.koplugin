-- A book's cover tile: the real cover when there is one and covers are on,
-- otherwise a typeset "data card" with the title, author and a pattern. Can
-- carry a small badge (NEW, 64%, DONE) and a folder tab.

local Element = require("cyberui/ui/element")
local Books = require("cyberui/data/books")
local Covers = require("cyberui/data/covers")
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

-- Show real covers? (the reader's choice; data cards are the fast default)
function Cover.imagesOn()
    return Settings.get("cover_images", false)
end

-- Draw the tile: image or data card (an empty slot is just its frame), then
-- badge and folder tab.
function Cover:draw(bb, x, y)
    local th = Theme.get()
    local w, h = self.w, self.h
    local stroke = th.size.stroke
    Paint.fill(bb, x, y, w, h, th.c.bg)
    local drawn = false
    if self.path and Cover.imagesOn() then
        local img = Covers.get(self.path, w - 2 * stroke, h - 2 * stroke)
        if img then
            local iw, ih = img:getWidth(), img:getHeight()
            bb:blitFrom(img, x + math.floor((w - iw) / 2), y + math.floor((h - ih) / 2), 0, 0, iw, ih)
            drawn = true
        end
    end
    if not drawn and (self.path or self.title) then self:drawCard(bb, x, y, th) end
    Paint.frame(bb, x, y, w, h, stroke, th.c.ink)
    if self.folder then self:drawFolderTab(bb, x, y, th) end
    if self.badge then self:drawBadge(bb, x, y, th) end
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
        Text.draw(bb, bx + pad, by + pad + (i - 1) * lh, kind, line, th.c.ink)
    end
    if author and w >= Theme.px(70) then
        Text.draw(bb, bx + pad, by + pad + #lines * lh, "micro", Text.fit("micro", author, inner), th.c.muted)
    end
end

-- A small label in the top-right corner.
function Cover:drawBadge(bb, x, y, th)
    local s = Text.fit("micro", self.badge)
    local pad = Theme.px(4)
    local bw = Text.width("micro", s) + 2 * pad
    local bh = Text.height("micro") + Theme.px(2)
    local fill = self.badge_on and th.c.accent or th.c.ink
    local fg = self.badge_on and th.c.on_accent or th.c.on_ink
    Paint.fill(bb, x + self.w - bw, y, bw, bh, fill)
    Text.draw(bb, x + self.w - bw + pad, y + Theme.px(1), "micro", s, fg)
end

-- A folder tab sticking out of the top-left edge.
function Cover:drawFolderTab(bb, x, y, th)
    local tab_w = math.floor(self.w / 2.5)
    local tab_h = Theme.px(7)
    Paint.chamfer(bb, x + Theme.px(6), y, tab_w, tab_h, tab_h, "r", th.c.ink)
end

return Cover
