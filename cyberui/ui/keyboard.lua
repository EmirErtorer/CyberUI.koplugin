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

-- Build the keyboard. o: { layer, shift (true or "once" for one letter,
-- "lock" until tapped again), enter_label, on_char, on_back, on_enter,
-- on_layer(layer), on_shift() }.
function Keyboard.build(o)
    local th = Theme.get()
    local layer = LAYERS[o.layer] and o.layer or "abc"
    local key_h = Theme.px(46)
    local gap = Theme.px(4)
    local function key(label, on_tap, extra)
        local b = { label = label, variant = "soft", kind = "label", height = key_h, grow = true, on_tap = on_tap }
        for k, v in pairs(extra or {}) do b[k] = v end
        return Button:new(b)
    end
    local rows = {}
    for i, row in ipairs(LAYERS[layer]) do
        local keys = {}
        if i == edgeRow(layer) and SHIFTS[layer] then
            local locked = o.shift == "lock"
            keys[#keys + 1] = key(locked and "⇧⇧" or "⇧", o.on_shift,
                { variant = locked and "primary" or (o.shift and "chip_on" or "soft"), grow = false, width = Theme.px(54) })
        end
        for _i, ch in ipairs(chars(row)) do
            local shown = o.shift and Utf8Proc.uppercase_dumb(ch) or ch
            keys[#keys + 1] = key(shown, function() o.on_char(shown) end, { kind = "mono" })
        end
        if i == edgeRow(layer) then
            keys[#keys + 1] = key(nil, o.on_back, { icon = "backspace", grow = false, width = Theme.px(54), variant = "icon_on" })
        end
        rows[#rows + 1] = Layout.Row:new({ gap = gap, children = keys })
    end
    local function layerKey(id, label)
        return key(label, function() o.on_layer(id) end, { grow = false, width = Theme.px(62), variant = "seg" })
    end
    local bottom = {}
    if layer ~= "abc" then bottom[#bottom + 1] = layerKey("abc", "abc") end
    if layer ~= "num" then bottom[#bottom + 1] = layerKey("num", "?123") end
    if layer ~= "acc" then bottom[#bottom + 1] = layerKey("acc", "áãç") end
    bottom[#bottom + 1] = key(_("space"), function() o.on_char(" ") end, { variant = "secondary", kind = "mono_small" })
    bottom[#bottom + 1] = key(o.enter_label or _("OK"), o.on_enter, { variant = "primary", grow = false, width = Theme.px(110) })
    rows[#rows + 1] = Layout.Row:new({ gap = gap, children = bottom })
    return Layout.Column:new({ gap = gap, pad = { th.space.s, th.space.s }, children = rows })
end

return Keyboard
