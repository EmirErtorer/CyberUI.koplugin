-- The active look: colours by role, text faces, sizes and decorations, worked
-- out once from the chosen style, colour scheme and light or dark mode. Screens
-- and widgets ask for roles here and never hold a colour or size of their own.

local Device = require("device")
local Font = require("ui/font")
local Color = require("cyberui/theme/color")
local Paths = require("cyberui/paths")
local Registry = require("cyberui/theme/registry")
local Settings = require("cyberui/settings")

local Screen = Device.screen

local Theme = {}

Theme.MODES = { "light", "dark", "system" }

local current
local listeners = {}

-- "light", "dark" or "system".
function Theme.mode()
    local m = Settings.get("mode", "system")
    if m == "light" or m == "dark" then return m end
    return "system"
end

-- Is KOReader's night mode inverting the whole screen?
function Theme.nightMode()
    if Screen.night_mode ~= nil then return Screen.night_mode == true end
    return G_reader_settings and G_reader_settings:isTrue("night_mode") or false
end

-- Does the reader see a dark screen?
function Theme.isDark()
    local m = Theme.mode()
    if m == "system" then return Theme.nightMode() end
    return m == "dark"
end

-- Must the dark palette be painted? Night mode inverts the screen already, so
-- the light palette is painted when that inversion gives the look chosen.
function Theme.paintsDark()
    return Theme.isDark() ~= Theme.nightMode()
end

-- Scale a size in base pixels to the screen.
function Theme.px(n)
    return Screen:scaleBySize(n)
end

-- Work out every role, size and face for the current settings.
local function resolve()
    local style = Registry.style(Settings.get("style", "cyberdeck"))
    local scheme = Registry.scheme(Settings.get("scheme", "mono"))
    local palette = Theme.paintsDark() and scheme.dark or scheme.light
    local colour = Screen:isColorEnabled() and true or false

    -- the colours as the screen shows them, so contrast is judged on what is seen
    local seen = {}
    for role, hex in pairs(palette) do
        local rgb = Color.parse(hex)
        if not colour then
            local g = Color.grey(rgb)
            rgb = { g, g, g }
        end
        seen[role] = rgb
    end
    seen.on_accent = Color.readableOn(seen.accent, seen.bg, seen.ink, { 0, 0, 0 }, { 255, 255, 255 })
    seen.on_accent2 = Color.readableOn(seen.accent2, seen.bg, seen.ink, { 0, 0, 0 }, { 255, 255, 255 })
    seen.on_ink = seen.bg

    local c = {}
    for role, rgb in pairs(seen) do c[role] = Color.toScreen(rgb, colour) end

    local size = {}
    for k, v in pairs(style.size) do size[k] = Screen:scaleBySize(v) end
    local space = {}
    for k, v in pairs(style.space) do space[k] = Screen:scaleBySize(v) end

    current = {
        night = Theme.nightMode(),
        style = style,
        scheme = scheme,
        colour = colour,
        c = c,
        rgb = seen,
        size = size,
        space = space,
        decor = style.decor,
        faces = {},
        version = (current and current.version or 0) + 1,
    }
end

-- The resolved theme: { c, rgb, size, space, decor, style, scheme, version }.
function Theme.get()
    if not current then resolve() end
    return current
end

-- The screen colour for a role ("ink", "accent"...); a colour passes through.
function Theme.color(role)
    if type(role) ~= "string" then return role end
    local t = Theme.get()
    return t.c[role] or t.c.ink
end

-- A font set's file as Font:getFace wants it: KOReader's own faces by name,
-- device and plugin fonts by a path from KOReader's fonts folder.
local function fontPath(file)
    local builtin = file:match("^koreader:(.+)$")
    if builtin then return builtin end
    if file:find("/", 1, true) then return Paths.fontRelative(file) end
    return Paths.fromFonts("fonts/" .. file)
end

-- The face for a kind of text in a font set (the chosen one by default):
-- { face, tracking, caps, height, ascent }. Cached per set and kind.
function Theme.text(kind, set_id)
    local t = Theme.get()
    set_id = set_id or Settings.get("fontset", "oxanium")
    local key = set_id .. "|" .. kind
    local f = t.faces[key]
    if f then return f end
    local set = Registry.fontSet(set_id)
    local spec = t.style.text[kind] or t.style.text.body
    local role = spec[1]
    local own = role == "mono" and (set.mono_scale or 1) or set[role .. "_scale"] or set.scale or 1
    local scale = own * Settings.get("text_scale", 1)
    local size = math.floor(spec[2] * scale + 0.5)
    -- KOReader's own face if the file cannot be read, rather than no text
    local face = Font:getFace(fontPath(set[role] or set.body), size) or Font:getFace("cfont", size)
    local height, ascent = face.ftsize:getHeightAndAscender()
    f = {
        face = face,
        tracking = Screen:scaleBySize(t.style.tracking[kind] or 0),
        caps = t.style.caps[kind] or false,
        height = math.ceil(height),
        ascent = math.ceil(ascent),
    }
    t.faces[key] = f
    return f
end

-- Pick up a night mode switch made in KOReader since the look was worked out.
-- Elements read colours when they draw, so nothing needs rebuilding.
function Theme.sync()
    if current and current.night ~= Theme.nightMode() then resolve() end
end

-- Call fn() whenever the look changes.
function Theme.onChange(fn)
    listeners[#listeners + 1] = fn
end

-- Settings changed (or night mode, rotation, screen size): rebuild everything.
function Theme.refresh()
    resolve()
    for _i, fn in ipairs(listeners) do fn() end
end

-- Save a theme setting and apply it at once.
function Theme.set(key, value)
    Settings.save(key, value)
    Theme.refresh()
end

return Theme
