-- Setting controls built from the shared Button and Panel: a toggle switch, a
-- segmented choice and a stepper. Each calls on_change(new_value).

local Button = require("cyberui/ui/button")
local Element = require("cyberui/ui/element")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Paint = require("cyberui/gfx/paint")
local Panel = require("cyberui/ui/panel")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local _ = require("cyberui/gettext")

local Controls = {}

---------------------------------------------------------------- Toggle
local Toggle = Element:extend({ on = false })
Controls.Toggle = Toggle

-- A fixed-size switch.
function Toggle:naturalWidth() return Theme.px(72) end
function Toggle:naturalHeight() return Theme.px(32) end

-- Flip and report the new state.
function Toggle:on_tap()
    self.on = not self.on
    if self.on_change then self.on_change(self.on) end
end

-- An outlined track with a filled knob on the side of the state.
function Toggle:draw(bb, x, y)
    local th = Theme.get()
    local t = th.size.stroke
    Paint.frame(bb, x, y, self.w, self.h, t, th.c.ink)
    local inset = t + Theme.px(2)
    local kw = math.floor(self.w / 2) - inset
    local kh = self.h - 2 * inset
    local kx = self.on and (x + self.w - inset - kw) or (x + inset)
    Paint.fill(bb, kx, y + inset, kw, kh, self.on and th.c.accent or th.c.ink)
    local s = self.on and _("ON") or _("OFF")
    s = Text.fit("micro", s)
    local color = self.on and th.c.on_accent or th.c.on_ink
    Text.draw(bb, kx + math.floor((kw - Text.width("micro", s)) / 2),
        y + inset + math.floor((kh - Text.height("micro")) / 2), "micro", s, color)
end

---------------------------------------------------------------- Segmented
-- A framed row of choices; `options` is a list of { label, value }.
function Controls.Segmented(o)
    local row = Layout.Row:new({ children = {} })
    for _i, opt in ipairs(o.options) do
        row.children[#row.children + 1] = Button:new({
            label = opt[1], grow = true, height = o.height or Theme.px(38),
            kind = o.kind or "mono_small",
            variant = (opt[2] == o.value) and "seg_on" or "seg",
            on_tap = function() if o.on_change then o.on_change(opt[2]) end end,
        })
    end
    local th = Theme.get()
    return Panel:new({ shape = "frame", pad = th.size.stroke, child = row, width = o.width, grow = o.grow })
end

---------------------------------------------------------------- Stepper
-- A framed minus / value / plus control for numbers from `min` to `max`.
function Controls.Stepper(o)
    local step = o.step or 1
    local function set(v)
        v = math.max(o.min, math.min(o.max, v))
        if v ~= o.value and o.on_change then o.on_change(v) end
    end
    local side = Theme.px(40)
    local row = Layout.Row:new({ children = {
        Button:new({ icon = "back", variant = "seg", width = side, height = side, icon_size = 16,
            on_tap = function() set(o.value - step) end }),
        Label:new({ text = o.format and o.format(o.value) or tostring(o.value), kind = "mono", align = "center",
            width = Theme.px(o.value_w or 64) }),
        Button:new({ icon = "forward", variant = "seg_on", width = side, height = side, icon_size = 16,
            on_tap = function() set(o.value + step) end }),
    } })
    return Panel:new({ shape = "frame", pad = Theme.get().size.stroke, child = row })
end

return Controls
