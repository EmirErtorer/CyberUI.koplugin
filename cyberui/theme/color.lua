-- Colour helpers for the theme layer: hex parsing, brightness and contrast,
-- and turning a colour into what the screen shows (grey on e-ink, RGB on colour).

local Blitbuffer = require("ffi/blitbuffer")
local ffi = require("ffi")

local Color = {}

local RGB32 = Blitbuffer.ColorRGB32

-- "#RRGGBB" or "RRGGBB" to {r, g, b}; nil when it is not a colour.
function Color.parse(hex)
    if type(hex) == "table" then return hex end
    if type(hex) ~= "string" then return nil end
    local r, g, b = hex:match("^#?(%x%x)(%x%x)(%x%x)$")
    if not r then return nil end
    return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
end

-- {r, g, b} to "#RRGGBB".
function Color.hex(rgb)
    return string.format("#%02X%02X%02X", rgb[1], rgb[2], rgb[3])
end

-- sRGB channel (0..255) to linear light.
local function linear(c)
    c = c / 255
    return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
end

-- Relative luminance, 0 (black) to 1 (white).
function Color.luminance(rgb)
    return 0.2126 * linear(rgb[1]) + 0.7152 * linear(rgb[2]) + 0.0722 * linear(rgb[3])
end

-- Contrast ratio between two colours, 1 to 21.
function Color.contrast(a, b)
    local la, lb = Color.luminance(a), Color.luminance(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end

-- Of the candidates, the one that reads best on `bg`.
function Color.readableOn(bg, ...)
    local best, best_ratio
    for _, c in ipairs({ ... }) do
        local ratio = Color.contrast(bg, c)
        if not best_ratio or ratio > best_ratio then best, best_ratio = c, ratio end
    end
    return best
end

-- A colour `t` of the way from a to b (0 gives a, 1 gives b).
function Color.mix(a, b, t)
    return {
        math.floor(a[1] + (b[1] - a[1]) * t + 0.5),
        math.floor(a[2] + (b[2] - a[2]) * t + 0.5),
        math.floor(a[3] + (b[3] - a[3]) * t + 0.5),
    }
end

-- The grey level (0..255) that shows a colour on a black and white screen.
function Color.grey(rgb)
    return math.floor(Color.luminance(rgb) ^ (1 / 2.2) * 255 + 0.5)
end

-- The Blitbuffer colour to paint with: grey when the screen has no colour or
-- the colour is a grey, RGB otherwise.
function Color.toScreen(rgb, colour_screen)
    if not colour_screen or (rgb[1] == rgb[2] and rgb[2] == rgb[3]) then
        local level = (rgb[1] == rgb[2] and rgb[2] == rgb[3]) and rgb[1] or Color.grey(rgb)
        return Blitbuffer.Color8(level)
    end
    return RGB32(rgb[1], rgb[2], rgb[3], 0xFF)
end

-- Is a Blitbuffer colour an RGB one (needs the colour paint paths)?
function Color.isRGB(c)
    return ffi.istype(RGB32, c)
end

return Color
