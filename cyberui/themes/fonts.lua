-- The font sets offered in System > Fonts, all under the SIL Open Font
-- License (licence texts in the fonts folder) except KOReader's own. Each set
-- names a file for display, title, body and mono text; "koreader:" means one
-- of KOReader's built-in faces. `scale` evens out the faces' different sizes
-- so every set fits the same layout; `<role>_scale` sizes one role on its own
-- (mono is 1 unless mono_scale says otherwise). Any font installed on the
-- device can be chosen too (see Registry.fontSet).

local _ = require("cyberui/gettext")

return {
    {
        id = "oxanium", name = "Oxanium", note = _("Angular sci-fi face, the default"),
        display = "Oxanium-Bold.ttf", title = "Oxanium-SemiBold.ttf", body = "Oxanium-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 0.95,
    },
    {
        id = "chakra", name = "Chakra Petch", note = _("Squared-off techno face"),
        display = "ChakraPetch-Bold.ttf", title = "ChakraPetch-SemiBold.ttf", body = "ChakraPetch-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 1,
    },
    {
        id = "tomorrow", name = "Tomorrow", note = _("Wide, clean console face"),
        display = "Tomorrow-Bold.ttf", title = "Tomorrow-SemiBold.ttf", body = "Tomorrow-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 0.92,
    },
    {
        id = "rajdhani", name = "Rajdhani", note = _("Tall and narrow, fits more on a line"),
        display = "Rajdhani-Bold.ttf", title = "Rajdhani-SemiBold.ttf", body = "Rajdhani-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 1.12,
    },
    {
        id = "orbitron", name = "Orbitron", note = _("The classic sci-fi display face, with Exo 2 for reading"),
        display = "Orbitron-Bold.ttf", title = "Orbitron-SemiBold.ttf", body = "Exo2-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 0.86, body_scale = 0.98,
    },
    {
        id = "turret", name = "Turret Road", note = _("Low, wide and geometric"),
        display = "TurretRoad-Bold.ttf", title = "TurretRoad-Medium.ttf", body = "TurretRoad-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 1.02,
    },
    {
        id = "michroma", name = "Michroma", note = _("Extended headings, Electrolize for reading"),
        display = "Michroma-Regular.ttf", title = "Michroma-Regular.ttf", body = "Electrolize-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 0.8, body_scale = 0.98,
    },
    {
        id = "audiowide", name = "Audiowide", note = _("Rounded racing headings over Share Tech"),
        display = "Audiowide-Regular.ttf", title = "Audiowide-Regular.ttf", body = "ShareTech-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 0.88, body_scale = 1.02,
    },
    {
        id = "wallpoet", name = "Wallpoet", note = _("Stencilled street headings over Share Tech"),
        display = "Wallpoet-Regular.ttf", title = "Wallpoet-Regular.ttf", body = "ShareTech-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 0.86, body_scale = 1.02,
    },
    {
        id = "russo", name = "Russo One", note = _("Heavy block headings over Share Tech"),
        display = "RussoOne-Regular.ttf", title = "RussoOne-Regular.ttf", body = "ShareTech-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 0.9, body_scale = 1.02,
    },
    {
        id = "iceland", name = "Iceland", note = _("Narrow digital readout"),
        display = "Iceland-Regular.ttf", title = "Iceland-Regular.ttf", body = "Iceland-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 1.2,
    },
    {
        id = "terminal", name = "Terminal", note = _("VT323, a 1980s video terminal, everywhere"),
        display = "VT323-Regular.ttf", title = "VT323-Regular.ttf", body = "VT323-Regular.ttf",
        mono = "VT323-Regular.ttf", scale = 1.3, mono_scale = 1.3,
    },
    {
        id = "arcade", name = "Arcade", note = _("Press Start 2P pixel headings over VT323"),
        display = "PressStart2P-Regular.ttf", title = "PressStart2P-Regular.ttf", body = "VT323-Regular.ttf",
        mono = "VT323-Regular.ttf", scale = 0.62, body_scale = 1.3, mono_scale = 1.3,
    },
    {
        id = "koreader", name = "KOReader", note = _("KOReader's own fonts, for the plainest reading"),
        display = "koreader:tfont", title = "koreader:tfont", body = "koreader:cfont", -- i18n: keep
        mono = "koreader:infont", scale = 0.95,
    },
}
