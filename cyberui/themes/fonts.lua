-- The font sets offered in System > Fonts, all under the SIL Open Font
-- License (licence texts in the fonts folder) except KOReader's own. Each set
-- names a file for display, title, body and mono text; "koreader:" means one
-- of KOReader's built-in faces. `scale` evens out the faces' different sizes
-- so every set fits the same layout.

return {
    {
        id = "oxanium", name = "Oxanium", note = "Angular sci-fi face, the default",
        display = "Oxanium-Bold.ttf", title = "Oxanium-SemiBold.ttf", body = "Oxanium-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 0.95,
    },
    {
        id = "chakra", name = "Chakra Petch", note = "Squared-off techno face",
        display = "ChakraPetch-Bold.ttf", title = "ChakraPetch-SemiBold.ttf", body = "ChakraPetch-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 1,
    },
    {
        id = "tomorrow", name = "Tomorrow", note = "Wide, clean console face",
        display = "Tomorrow-Bold.ttf", title = "Tomorrow-SemiBold.ttf", body = "Tomorrow-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 0.92,
    },
    {
        id = "rajdhani", name = "Rajdhani", note = "Tall and narrow, fits more on a line",
        display = "Rajdhani-Bold.ttf", title = "Rajdhani-SemiBold.ttf", body = "Rajdhani-Regular.ttf",
        mono = "ShareTechMono-Regular.ttf", scale = 1.12,
    },
    {
        id = "koreader", name = "KOReader", note = "KOReader's own fonts, for the plainest reading",
        display = "koreader:tfont", title = "koreader:tfont", body = "koreader:cfont",
        mono = "koreader:infont", scale = 0.95,
    },
}
