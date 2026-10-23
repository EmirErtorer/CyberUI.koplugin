-- Graphite: soft greys instead of pure black and white, for e-ink screens:
-- dark grey buttons and badges on white, light grey ones on black.

return {
    id = "graphite",
    name = "Graphite",
    grey = true,
    light = {
        bg = "#FFFFFF", ink = "#141414", muted = "#5C5C5C",
        line = "#C4C4C4", soft = "#E3E3E3", accent = "#4A4A4A", accent2 = "#7A7A7A",
    },
    dark = {
        bg = "#000000", ink = "#E8E8E8", muted = "#9E9E9E",
        line = "#4D4D4D", soft = "#262626", accent = "#BDBDBD", accent2 = "#8C8C8C",
    },
}
