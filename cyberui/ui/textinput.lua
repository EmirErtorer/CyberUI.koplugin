-- Typing a line of text in the style: a panel docked at the bottom with a
-- title, the text field and the on-screen keyboard. The caller keeps the
-- state ({ text, layer, shift }) and redraws through the handlers in `o`.

local Button = require("cyberui/ui/button")
local InputField = require("cyberui/ui/inputfield")
local Keyboard = require("cyberui/ui/keyboard")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Theme = require("cyberui/theme")
local util = require("util")
local _ = require("cyberui/gettext")

local TextInput = {}

-- The shift state after a tap on the shift key: off, one letter, locked, off.
function TextInput.nextShift(shift)
    if not shift then return "once" end
    if shift == "lock" then return false end
    return "lock"
end

---------------------------------------------------------------- Panel
-- Build the docked input panel. o: { title, placeholder, ok_label, state,
-- on_char, on_back, on_enter, on_cancel, on_layer, on_shift, screen_w }.
-- Returns the panel and its field (to repaint alone while typing).
function TextInput.build(o)
    local th = Theme.get()
    local collapsed = o.state.collapsed
    local field = InputField:new({
        hint = o.placeholder,
        get = function()
            local chars = util.splitToChars(o.state.text)
            return chars, #chars + 1
        end,
        -- a tap on the field of a put-away keyboard brings it back
        on_caret = collapsed and o.on_expand and function() o.on_expand() end or nil,
    })
    local actions = { Button:new({ label = _("Cancel"), variant = "ghost", on_tap = o.on_cancel }) }
    if collapsed then
        actions[#actions + 1] = Button:new({ label = o.ok_label or _("OK"), variant = "primary", on_tap = o.on_enter })
    elseif o.on_collapse then
        actions[#actions + 1] = Button:new({ icon = "down", variant = "chip", width = Theme.px(46), on_tap = o.on_collapse })
    end
    table.insert(actions, 1, Label:new({ text = o.title, kind = "title", grow = true }))
    local header = Layout.Row:new({ gap = th.space.m, children = actions })
    if collapsed then
        local panel = Panel:new({ shape = "header", title = _("// INPUT"), fill = "bg", width = o.screen_w,
            pad = { th.space.m, th.space.m, th.space.s, th.space.m }, child = Layout.Column:new({ gap = th.space.m, children = { header, field } }) })
        panel.dock = "bottom"
        return panel, field
    end
    local keyboard = Keyboard.build({
        layer = o.state.layer, shift = o.state.shift, enter_label = o.ok_label,
        on_char = o.on_char, on_back = o.on_back, on_enter = o.on_enter,
        on_layer = o.on_layer, on_shift = o.on_shift,
    })
    local panel = Panel:new({ shape = "header", title = _("// INPUT"), title_right = o.state.layer == "acc" and "ÁÃÇ" or nil,
        fill = "bg", width = o.screen_w, pad = { th.space.m, th.space.m, th.space.s, th.space.m },
        child = Layout.Column:new({ gap = th.space.m, children = { header, field, keyboard } }) })
    panel.dock = "bottom"
    return panel, field
end

return TextInput
