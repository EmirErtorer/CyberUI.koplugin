-- The Cyberdeck style: type sizes, spacing and the shapes every element is
-- drawn with. Sizes are in base pixels; the theme scales them to the screen.
-- The faces come from the font set chosen in System > Fonts (themes/fonts.lua).

return {
    id = "cyberdeck",
    name = "Cyberdeck",
    -- font role (from the font set) and size for each kind of text
    text = {
        hero = { "display", 30 },
        display = { "display", 24 },
        title = { "display", 19 },
        heading = { "title", 16 },
        body = { "body", 15 },
        label = { "title", 14 },
        small = { "body", 13 },
        mono = { "mono", 14 },
        mono_small = { "mono", 12 },
        micro = { "mono", 11 },
        number = { "mono", 26 },
    },
    -- letter spacing (base pixels) per kind of text
    tracking = { hero = 1, display = 2, title = 1, heading = 1, label = 1 },
    -- titles and labels are shown in capitals
    caps = { hero = true, display = true, title = true, label = true, micro = true },
    space = { xs = 4, s = 6, m = 10, l = 14, xl = 18 },
    size = {
        touch = 44,        -- smallest tap target
        stroke = 2,        -- outlines
        hair = 1,          -- dividers
        cut = 12,          -- chamfered corner on panels and big buttons
        cut_small = 8,     -- chamfered corner on chips and tiles
        bracket = 16,      -- corner bracket arm
        segment_gap = 2,   -- gap between progress segments
        status = 22,       -- status bar height
        tabbar = 52,       -- bottom tab bar height
    },
    -- decorations this style draws; another style may turn them off
    decor = { brackets = true, barcode = true, hatch = true, ruler = true, chamfer = true },
}
