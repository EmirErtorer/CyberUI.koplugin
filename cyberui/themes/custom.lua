-- Custom: the reader's own accent colours on the Mono base. Softer shades are
-- derived from the accent so every role stays readable.

local Color = require("cyberui/theme/color")

local Custom = {}

Custom.DEFAULT_ACCENT = "#2457D6"
Custom.DEFAULT_ACCENT2 = "#0F8076"

-- Ready-made colours offered when picking a custom accent.
Custom.PRESETS = {
    "#2457D6", "#0F8076", "#C62828", "#7B3FB0", "#D06000", "#E0574B",
    "#93E4EA", "#7BF0A8", "#FFB347", "#F2C94C", "#EC4899", "#000000",
}

-- Build the scheme from two hex colours.
function Custom.build(accent_hex, accent2_hex)
    local accent = Color.parse(accent_hex) or Color.parse(Custom.DEFAULT_ACCENT)
    local accent2 = Color.parse(accent2_hex) or accent
    local white, black = { 255, 255, 255 }, { 0, 0, 0 }
    -- on a dark page the accents are lifted so they glow rather than sink
    local function lift(c) return Color.luminance(c) < 0.2 and Color.mix(c, white, 0.35) or c end
    local d1, d2 = lift(accent), lift(accent2)
    return {
        id = "custom",
        name = "Custom",
        light = {
            bg = "#FFFFFF", ink = "#000000", muted = "#555555",
            line = Color.hex(Color.mix(accent, white, 0.7)), soft = Color.hex(Color.mix(accent, white, 0.85)),
            accent = Color.hex(accent), accent2 = Color.hex(accent2),
        },
        dark = {
            bg = "#000000", ink = Color.hex(Color.mix(d2, white, 0.6)), muted = "#A6A6A6",
            line = Color.hex(Color.mix(d1, black, 0.6)), soft = Color.hex(Color.mix(d1, black, 0.75)),
            accent = Color.hex(d1), accent2 = Color.hex(d2),
        },
    }
end

return Custom
