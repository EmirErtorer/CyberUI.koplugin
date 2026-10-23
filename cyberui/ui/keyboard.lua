-- The on-screen keyboard in the style: letters, numbers and accented letters
-- as three layers, a one-shot shift, backspace, space and an enter key.
-- Keys report through the handlers given: on_char(c), on_back(), on_enter().

local Button = require("cyberui/ui/button")
local Layout = require("cyberui/ui/layout")
local Theme = require("cyberui/theme")
local Utf8Proc = require("ffi/utf8proc")
local _ = require("gettext")

local Keyboard = {}

-- The character rows of each layer.
local LAYERS = {
    abc = { "qwertyuiop", "asdfghjkl", "zxcvbnm" },
    num = { "1234567890", "-/:;()&@\"", ".,?!'#=+" },
    acc = { "çğıöşüéèêà", "âäëïîôûùñß", "øåõíóúýæ" },
}

-- The characters of a row as a list (they may be several bytes each).
local function chars(row)
    local out = {}
    for ch in row:gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = ch end
    return out
end

-- Build the keyboard. o: { layer, shift, enter_label, on_char, on_back,
-- on_enter, on_layer(layer), on_shift() }.
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
        if i == 3 and layer == "abc" then
            keys[#keys + 1] = key("⇧", o.on_shift, { variant = o.shift and "chip_on" or "soft", grow = false, width = Theme.px(54) })
        end
        for _i, ch in ipairs(chars(row)) do
            local shown = o.shift and Utf8Proc.uppercase_dumb(ch) or ch
            keys[#keys + 1] = key(shown, function() o.on_char(shown) end, { kind = "mono" })
        end
        if i == 3 then
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
    if layer ~= "acc" then bottom[#bottom + 1] = layerKey("acc", "äöç") end
    bottom[#bottom + 1] = key(_("space"), function() o.on_char(" ") end, { variant = "secondary", kind = "mono_small" })
    bottom[#bottom + 1] = key(o.enter_label or _("OK"), o.on_enter, { variant = "primary", grow = false, width = Theme.px(110) })
    rows[#rows + 1] = Layout.Row:new({ gap = gap, children = bottom })
    return Layout.Column:new({ gap = gap, pad = { th.space.s, th.space.s }, children = rows })
end

return Keyboard
