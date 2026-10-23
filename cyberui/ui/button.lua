-- The one button of the style. A variant picks its colours and shape:
-- primary, secondary, soft, ghost, chip, chip_on, tab, tab_on and icon. Content
-- is an optional icon, a label and an optional small line under it.

local Element = require("cyberui/ui/element")
local Icons = require("cyberui/gfx/icons")
local Paint = require("cyberui/gfx/paint")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local Button = Element:extend({ variant = "secondary", align = "center", icon_size = 20 })

-- Fill, outline, text colour, cut size and cut corners of each variant.
local VARIANTS = {
    primary   = { fill = "accent", text = "on_accent", cut = "cut", corners = "rl" },
    accent2   = { fill = "accent2", text = "on_accent2", cut = "cut", corners = "rl" },
    secondary = { line = "ink", text = "ink", cut = "cut", corners = "rl" },
    soft      = { fill = "soft", text = "ink", cut = "cut_small", corners = "r" },
    ghost     = { text = "ink", brackets = true },
    chip      = { line = "ink", text = "ink", cut = "cut_small", corners = "r" },
    chip_on   = { fill = "accent", text = "on_accent", cut = "cut_small", corners = "r" },
    tab       = { text = "ink" },
    tab_on    = { fill = "accent", text = "on_accent" },
    icon      = { line = "ink", text = "ink" },
    icon_on   = { fill = "ink", text = "on_ink" },
    seg       = { text = "ink" },
    seg_on    = { fill = "ink", text = "on_ink" },
    disabled  = { line = "line", text = "muted", stripes = true },
    danger    = { line = "accent", text = "accent", cut = "cut_small", corners = "r" },
}
Button.VARIANTS = VARIANTS

-- The variant's colour roles.
function Button:look()
    return VARIANTS[self.disabled and "disabled" or self.variant] or VARIANTS.secondary
end

-- Text kinds used for the label and the small line.
function Button:kinds()
    return self.kind or "label", self.sub_kind or "micro"
end

-- Width of the content plus padding.
function Button:naturalWidth()
    if self.width then return self.width end
    local th = Theme.get()
    local kind, sub_kind = self:kinds()
    local w = 0
    if self.label then w = Text.width(kind, self.label) end
    if self.sub then w = math.max(w, Text.width(sub_kind, self.sub)) end
    if self.icon then
        w = w + Theme.px(self.icon_size) + (self.label and th.space.s or 0)
    end
    local pad = self.variant:sub(1, 4) == "icon" and 0 or 2 * th.space.l
    return math.max(w + pad, th.size.touch)
end

-- Buttons are at least one touch target tall.
function Button:naturalHeight()
    return self.height or Theme.get().size.touch
end

-- Draw the shape, then the icon and text.
function Button:draw(bb, x, y)
    local th = Theme.get()
    local look = self:look()
    local w, h = self.w, self.h
    local stroke = th.size.stroke
    local fill = look.fill and Theme.color(look.fill)
    local line = look.line and Theme.color(look.line)
    local cut = (look.cut and th.decor.chamfer) and th.size[look.cut] or 0
    if look.stripes then Paint.stripes(bb, x, y, w, h, "d", Theme.px(10), Theme.px(4), th.c.soft) end
    if cut > 0 then
        Paint.chamferBox(bb, x, y, w, h, cut, self.corners or look.corners, stroke, fill, line)
    else
        if fill then Paint.fill(bb, x, y, w, h, fill) end
        if line then Paint.frame(bb, x, y, w, h, stroke, line) end
    end
    if look.brackets and th.decor.brackets then
        Paint.sideBrackets(bb, x, y, w, h, math.floor(h / 4), stroke, Theme.color(look.text))
    end
    -- an icon's accent lights only stand out on an unfilled button
    self:drawContent(bb, x, y, Theme.color(look.text), not fill and Theme.color("accent") or nil)
end

-- Lay out icon, label and small line inside the button (the small line only
-- when there is room for both).
function Button:drawContent(bb, x, y, color, accent)
    local th = Theme.get()
    local kind, sub_kind = self:kinds()
    local pad = self.variant:sub(1, 4) == "icon" and 0 or th.space.m
    local isz = self.icon and Theme.px(self.icon_size) or 0
    local igap = (self.icon and self.label) and th.space.s or 0
    local text_w = self.w - 2 * pad - isz - igap
    local label = self.label and Text.fit(kind, self.label, text_w)
    -- a button too short for both lines keeps its label alone
    local two_lines = self.label and self.sub and Text.height(kind) + Text.height(sub_kind) <= self.h
    local sub = self.sub and (two_lines or not self.label) and Text.fit(sub_kind, self.sub, text_w)
    local lw = label and Text.width(kind, label) or 0
    local sw = sub and Text.width(sub_kind, sub) or 0
    local content_w = isz + igap + math.max(lw, sw)
    local cx = x + pad
    if self.align == "center" then cx = x + math.floor((self.w - content_w) / 2) end
    if self.icon then
        Icons.draw(bb, self.icon, cx, y + math.floor((self.h - isz) / 2), isz, color, accent)
        cx = cx + isz + igap
    end
    local lh = label and Text.height(kind) or 0
    local sh = sub and Text.height(sub_kind) or 0
    local ty = y + math.floor((self.h - lh - sh) / 2)
    if label then
        local lx = cx
        if self.align == "center" and lw < sw then lx = cx + math.floor((sw - lw) / 2) end
        Text.draw(bb, lx, ty, kind, label, color)
    end
    if sub then
        local sx = cx
        if self.align == "center" and sw < lw then sx = cx + math.floor((lw - sw) / 2) end
        Text.draw(bb, sx, ty + lh, sub_kind, sub, color)
    end
end

return Button
