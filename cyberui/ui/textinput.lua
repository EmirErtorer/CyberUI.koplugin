-- Typing a line of text in the style: a panel docked at the bottom with a
-- title, the text field and the on-screen keyboard. The caller keeps the
-- state ({ text, layer, shift }) and redraws through the handlers in `o`.

local Button = require("cyberui/ui/button")
local Element = require("cyberui/ui/element")
local Keyboard = require("cyberui/ui/keyboard")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Paint = require("cyberui/gfx/paint")
local Panel = require("cyberui/ui/panel")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local TextInput = {}

---------------------------------------------------------------- Field
local Field = Element:extend({ placeholder = "" })
TextInput.Field = Field

-- One line of mono text plus padding.
function Field:naturalHeight()
    return Text.height("mono") + 2 * Theme.get().space.m
end

-- An outlined box with a prompt, the end of the text and a block cursor.
function Field:draw(bb, x, y)
    local th = Theme.get()
    local pad = th.space.m
    Paint.fill(bb, x, y, self.w, self.h, th.c.bg)
    Paint.frame(bb, x, y, self.w, self.h, th.size.stroke, th.c.ink)
    local prompt = "> "
    local pw = Text.width("mono", prompt)
    local ty = y + math.floor((self.h - Text.height("mono")) / 2)
    Text.draw(bb, x + pad, ty, "mono", prompt, th.c.muted)
    local cursor_w = Theme.px(9)
    local avail = self.w - 2 * pad - pw - cursor_w - Theme.px(2)
    local tx = x + pad + pw
    if self.state.text == "" then
        Text.draw(bb, tx + cursor_w + Theme.px(4), ty, "mono", Text.fit("mono", self.placeholder, avail), th.c.muted)
        Paint.fill(bb, tx, ty, cursor_w, Text.height("mono"), th.c.ink)
        return
    end
    local shown = Text.fitTail("mono", self.state.text, avail)
    local w = Text.draw(bb, tx, ty, "mono", shown, th.c.ink)
    Paint.fill(bb, tx + w + Theme.px(2), ty, cursor_w, Text.height("mono"), th.c.ink)
end

---------------------------------------------------------------- Panel
-- Build the docked input panel. o: { title, placeholder, ok_label, state,
-- on_char, on_back, on_enter, on_cancel, on_layer, on_shift, screen_w }.
-- Returns the panel and its field (to repaint alone while typing).
function TextInput.build(o)
    local th = Theme.get()
    local field = Field:new({ state = o.state, placeholder = o.placeholder or "" })
    local header = Layout.Row:new({ gap = th.space.m, children = {
        Label:new({ text = o.title, kind = "title", grow = true }),
        Button:new({ label = _("Cancel"), variant = "ghost", on_tap = o.on_cancel }),
    } })
    local keyboard = Keyboard.build({
        layer = o.state.layer, shift = o.state.shift, enter_label = o.ok_label,
        on_char = o.on_char, on_back = o.on_back, on_enter = o.on_enter,
        on_layer = o.on_layer, on_shift = o.on_shift,
    })
    local panel = Panel:new({ shape = "header", title = "// INPUT", title_right = o.state.layer == "acc" and "ÄÖÇ" or nil,
        fill = "bg", width = o.screen_w, pad = { th.space.m, th.space.m, th.space.s, th.space.m },
        child = Layout.Column:new({ gap = th.space.m, children = { header, field, keyboard } }) })
    panel.dock = "bottom"
    return panel, field
end

return TextInput
