-- A data shard: one highlight as a fragment of broken glass. The outline is an
-- irregular polygon cut from the shard's own id (so each one has its own
-- shape), drawn over a displaced ghost edge and with a short crack, and it
-- says what it is: DATA SHARD, its code, RECOVERED, and which fragment of how
-- many it is, with the book's title.

local Books = require("cyberui/data/books")
local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Profile = require("cyberui/data/profile")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local ShardCard = Element:extend({ lines = 2, text_kind = "small" })

-- The shard's outline in a w x h box, and its crack, from its id: the corners
-- are cut at angles of its own and the top and bottom edges dip once.
local function shape(id, w, h)
    local rnd = Profile.rng(id)
    local function jx(f) return (rnd() - 0.5) * f * w end
    local function jy(f) return (rnd() - 0.5) * f * h end
    local x, y = w - 1, h - 1
    local outline = {
        { 0, 0.22 * y + jy(0.06) }, { 0.06 * x + jx(0.02), 0 }, { 0.52 * x + jx(0.10), 0.05 * y + jy(0.03) },
        { 0.70 * x + jx(0.04), 0 }, { x, 0.10 * y + jy(0.04) }, { x, 0.78 * y + jy(0.08) },
        { 0.93 * x + jx(0.02), y }, { 0.46 * x + jx(0.10), 0.94 * y + jy(0.02) }, { 0.20 * x + jx(0.05), y },
        { 0, 0.84 * y + jy(0.08) },
    }
    -- a short crack running down from the top edge, clear of the words
    local top = outline[4]
    local crack = { { top[1], top[2] }, { top[1] - 0.012 * w, top[2] + 0.09 * y }, { top[1] + 0.010 * w, top[2] + 0.16 * y },
        { top[1] - 0.006 * w, top[2] + 0.22 * y } }
    return outline, crack
end

-- The lines of the highlight that fit the height (when it is fixed).
function ShardCard:textLines()
    local th = Theme.get()
    if not self.height then return self.lines end
    local room = self.height - 2 * Text.height("micro") - 2 * th.space.m - th.space.s
    return math.max(1, math.min(self.lines, math.floor(room / Text.height(self.text_kind))))
end

-- The words of the highlight, quoted.
function ShardCard:quote()
    return "\u{201C}" .. self.shard.text .. "\u{201D}"
end

-- Tall enough for the label, the lines the highlight needs (up to `lines`) and
-- the footer.
function ShardCard:naturalHeight(w)
    if self.height then return self.height end
    local th = Theme.get()
    local inner = (w or self.w or 0) - Theme.px(4) - 2 * Theme.px(24)
    local n = math.max(1, math.min(self.lines, #Text.wrap(self.text_kind, self:quote(), inner, self.lines)))
    return 2 * Text.height("micro") + n * Text.height(self.text_kind) + 2 * th.space.m + th.space.s
end

-- Draw the ghost edge, the shard, its crack and its words.
function ShardCard:draw(bb, x, y)
    local th = Theme.get()
    local s = self.shard
    local off = Theme.px(4)
    local w, h = self.w - off, self.h - off
    local outline, crack = shape(s.id, w, h)
    local function at(pts, dx, dy)
        local out = {}
        for i, p in ipairs(pts) do out[i] = { x + p[1] + dx, y + p[2] + dy } end
        return out
    end
    Paint.outline(bb, at(outline, off, off), th.size.hair, th.c.muted)
    local body = at(outline, 0, 0)
    Paint.polygon(bb, body, th.c.bg)
    Paint.outline(bb, body, th.size.stroke, th.c.ink)
    Paint.outline(bb, at(crack, 0, 0), th.size.hair, th.c.ink)
    local pad_x = Theme.px(24)
    local inner_w = w - 2 * pad_x
    local micro, ty = Text.height("micro"), y + th.space.s + Theme.px(3)
    local tag = string.format(_("DATA SHARD // 0x%s"), s.id:sub(1, 4))
    Text.draw(bb, x + pad_x, ty, "micro", Text.fit("micro", tag, inner_w), th.c.ink)
    local status = _("RECOVERED")
    Text.draw(bb, x + pad_x + inner_w - Text.width("micro", status), ty, "micro", status, th.c.accent)
    ty = ty + micro + Theme.px(2)
    local lines = Text.wrap(self.text_kind, self:quote(), inner_w, self:textLines())
    for _i, line in ipairs(lines) do
        Text.draw(bb, x + pad_x, ty, self.text_kind, line, th.c.ink)
        ty = ty + Text.height(self.text_kind)
    end
    local from = string.format(_("FRAGMENT %d/%d // %s"), self.number or 1, self.of or 1, Books.info(s.path).title)
    Text.draw(bb, x + pad_x, y + h - micro - Theme.px(12), "micro", Text.fit("micro", from, inner_w), th.c.muted)
end

return ShardCard
