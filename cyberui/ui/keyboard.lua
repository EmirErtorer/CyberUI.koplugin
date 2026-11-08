-- The on-screen keyboard in the style: letters, numbers and accented letters
-- as three layers, a shift key (one letter, or locked on a second tap) that
-- works on the letters and the accented letters, backspace, space and an
-- enter key. Keys report through the handlers given: on_char(c), on_back(),
-- on_enter().

local Button = require("cyberui/ui/button")
local Layout = require("cyberui/ui/layout")
local Theme = require("cyberui/theme")
local Utf8Proc = require("ffi/utf8proc")
local _ = require("cyberui/gettext")

local Keyboard = {}

-- The character rows of each layer.
local LAYERS = {
    abc = { "qwertyuiop", "asdfghjkl", "zxcvbnm" },
    num = { "1234567890", "-/:;()&@\"", ".,?!'#=+" },
    acc = { "áàâãäåæçéè", "êëíìîïñóòô", "õöøœúùûüýÿ", "ßğışąćęł", "ńśźż¿¡" },
}

-- The layers that have a shift key (the numbers have no capitals).
local SHIFTS = { abc = true, acc = true }

-- Which row of a layer carries the shift and backspace keys (the last but one
-- for the accented letters, whose last row is the short one of punctuation).
local function edgeRow(layer)
    return layer == "acc" and 4 or 3
end

-- The characters of a row as a list (they may be several bytes each).
local function chars(row)
    local out = {}
    for ch in row:gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = ch end
    return out
end

-- Rows of keys from descriptions, drawn as the style's keyboard. A key is
-- { label, icon, kind, variant, width, weight, on_tap, on_hold }: `width` is
-- fixed, otherwise it takes a share of the row by `weight` (1 by default).
-- o: { gap, key_h, pad }.
function Keyboard.grid(rows, o)
    local th = Theme.get()
    o = o or {}
    local key_h = o.key_h or Theme.px(46)
    local gap = o.gap or Theme.px(4)
    local out = {}
    for _i, row in ipairs(rows) do
        local keys = {}
        for _j, k in ipairs(row) do
            keys[#keys + 1] = Button:new({
                label = k.label, icon = k.icon, kind = k.kind, variant = k.variant or "soft", height = key_h,
                width = k.width, grow = not k.width and (k.weight or true) or nil,
                on_tap = k.on_tap, on_hold = k.on_hold, disabled = k.disabled,
            })
        end
        out[#out + 1] = Layout.Row:new({ gap = gap, children = keys })
    end
    return Layout.Column:new({ gap = gap, pad = o.pad or { th.space.s, th.space.s }, children = out })
end

-- Build the keyboard. o: { layer, shift (true or "once" for one letter,
-- "lock" until tapped again), enter_label, on_char, on_back, on_enter,
-- on_layer(layer), on_shift() }.
function Keyboard.build(o)
    local layer = LAYERS[o.layer] and o.layer or "abc"
    local edge = Theme.px(54)
    local rows = {}
    for i, row in ipairs(LAYERS[layer]) do
        local keys = {}
        if i == edgeRow(layer) and SHIFTS[layer] then
            local locked = o.shift == "lock"
            keys[#keys + 1] = { label = locked and "\u{21E7}\u{21E7}" or "\u{21E7}", on_tap = o.on_shift, width = edge,
                variant = locked and "primary" or (o.shift and "chip_on" or "soft") }
        end
        for _i, ch in ipairs(chars(row)) do
            local shown = o.shift and Utf8Proc.uppercase_dumb(ch) or ch
            keys[#keys + 1] = { label = shown, kind = "mono", on_tap = function() o.on_char(shown) end }
        end
        if i == edgeRow(layer) then
            keys[#keys + 1] = { icon = "backspace", on_tap = o.on_back, width = edge, variant = "icon_on" }
        end
        rows[#rows + 1] = keys
    end
    local bottom = {}
    local function layerKey(id, label)
        bottom[#bottom + 1] = { label = label, on_tap = function() o.on_layer(id) end, width = Theme.px(62), variant = "seg" }
    end
    if layer ~= "abc" then layerKey("abc", "abc") end
    if layer ~= "num" then layerKey("num", "?123") end
    if layer ~= "acc" then layerKey("acc", "\u{E1}\u{E3}\u{E7}") end
    bottom[#bottom + 1] = { label = _("space"), on_tap = function() o.on_char(" ") end, variant = "secondary", kind = "mono_small" }
    bottom[#bottom + 1] = { label = o.enter_label or _("OK"), on_tap = o.on_enter, variant = "primary", width = Theme.px(110) }
    rows[#rows + 1] = bottom
    return Keyboard.grid(rows)
end

return Keyboard
