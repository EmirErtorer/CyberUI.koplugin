-- Text drawing for every widget: measures and paints a line in any theme
-- colour (KOReader's own text path is grey only), with letter spacing,
-- capitals, ellipsis and word wrap. Widths are cached per face and string.
-- A `kind` is a text kind ("body", "title"...) in the chosen font set, or a
-- { kind, font_set_id } pair to show another set (the Fonts page does).

local RenderText = require("ui/rendertext")
local TextWidget = require("ui/widget/textwidget")
local Utf8Proc = require("ffi/utf8proc")
local Color = require("cyberui/theme/color")
local Theme = require("cyberui/theme")

local Text = {}

local ELLIPSIS = "…"
local widths = setmetatable({}, { __mode = "k" })   -- face -> { str -> width }

-- Decode a UTF-8 string into a list of code points.
local function codepoints(s)
    local out = {}
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local b1 = ch:byte(1)
        local cp
        if b1 < 0x80 then cp = b1
        elseif b1 < 0xE0 then cp = (b1 - 0xC0) * 0x40 + (ch:byte(2) or 0x80) - 0x80
        elseif b1 < 0xF0 then
            cp = (b1 - 0xE0) * 0x1000 + ((ch:byte(2) or 0x80) - 0x80) * 0x40 + (ch:byte(3) or 0x80) - 0x80
        else
            cp = (b1 - 0xF0) * 0x40000 + ((ch:byte(2) or 0x80) - 0x80) * 0x1000
                + ((ch:byte(3) or 0x80) - 0x80) * 0x40 + (ch:byte(4) or 0x80) - 0x80
        end
        out[#out + 1] = cp
    end
    return out
end
Text.codepoints = codepoints

-- Does the string hold Hebrew or Arabic letters? Those need joining and right
-- to left order, which KOReader's shaping does and the glyph by glyph path
-- below does not.
local function isRTL(s)
    return s:find("[\214-\219]") ~= nil or s:find("\239[\172-\187]") ~= nil
end

local shaped = setmetatable({}, { __mode = "k" })   -- face -> { str -> shaped line }

-- The shaped line for a right to left string, kept for reuse.
local function shapedLine(face, s)
    local cache = shaped[face]
    if not cache then cache = {}; shaped[face] = cache end
    local tw = cache[s]
    if not tw then
        tw = TextWidget:new({ text = s, face = face, auto_para_direction = true })
        cache[s] = tw
    end
    return tw
end

-- The face spec for a kind (see the note at the top).
local function specOf(kind)
    if type(kind) == "table" then return Theme.text(kind[1], kind[2]) end
    return Theme.text(kind)
end

-- The string as it is shown for this kind of text (capitals when the style asks).
function Text.shown(kind, s)
    s = tostring(s or "")
    if specOf(kind).caps then s = Utf8Proc.uppercase_dumb(s) end
    -- composed form, so accents are part of their letter and not drawn apart
    return Utf8Proc.normalize_NFC(s)
end

-- Width in pixels of an already shown string.
local function measure(spec, s)
    local cache = widths[spec]
    if not cache then cache = {}; widths[spec] = cache end
    local w = cache[s]
    if w then return w end
    local face, track = spec.face, spec.tracking
    if isRTL(s) then
        w = shapedLine(face, s):getWidth()
        cache[s] = w
        return w
    end
    w = 0
    local prev = 0
    local cps = codepoints(s)
    for i, cp in ipairs(cps) do
        local glyph = RenderText:getGlyph(face, cp, false)
        if prev ~= 0 then w = w + face.ftsize:getKerning(prev, cp) end
        w = w + glyph.ax + (i < #cps and track or 0)
        prev = cp
    end
    cache[s] = w
    return w
end

-- Width of `s` drawn as `kind`.
function Text.width(kind, s)
    return measure(specOf(kind), Text.shown(kind, s))
end

-- `s` shortened with an ellipsis to fit `max_w` (already shown form).
local function fit(spec, s, max_w)
    if measure(spec, s) <= max_w then return s end
    local cps = codepoints(s)
    local function prefix(n)
        local chars = {}
        for i = 1, n do chars[i] = cps[i] end
        return Text.fromCodepoints(chars)
    end
    -- binary search the longest prefix that fits with the ellipsis
    local lo, hi = 0, #cps
    while lo < hi do
        local mid = math.ceil((lo + hi) / 2)
        if measure(spec, prefix(mid) .. ELLIPSIS) <= max_w then lo = mid else hi = mid - 1 end
    end
    return (prefix(lo):gsub("%s+$", "")) .. ELLIPSIS
end

-- Encode code points back into UTF-8.
function Text.fromCodepoints(cps)
    local parts = {}
    for i, cp in ipairs(cps) do
        if cp < 0x80 then parts[i] = string.char(cp)
        elseif cp < 0x800 then parts[i] = string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
        elseif cp < 0x10000 then
            parts[i] = string.char(0xE0 + math.floor(cp / 0x1000), 0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
        else
            parts[i] = string.char(0xF0 + math.floor(cp / 0x40000), 0x80 + math.floor(cp / 0x1000) % 0x40,
                0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
        end
    end
    return table.concat(parts)
end

-- `s` as shown for `kind`, its start cut with an ellipsis so its end fits
-- `max_w` (a text field shows where typing happens).
function Text.fitTail(kind, s, max_w)
    local spec = specOf(kind)
    s = Text.shown(kind, s)
    if measure(spec, s) <= max_w then return s end
    local cps = codepoints(s)
    local function suffix(n)
        local chars = {}
        for i = #cps - n + 1, #cps do chars[#chars + 1] = cps[i] end
        return Text.fromCodepoints(chars)
    end
    local lo, hi = 0, #cps
    while lo < hi do
        local mid = math.ceil((lo + hi) / 2)
        if measure(spec, ELLIPSIS .. suffix(mid)) <= max_w then lo = mid else hi = mid - 1 end
    end
    return ELLIPSIS .. suffix(lo)
end

-- `s` as shown for `kind`, cut with an ellipsis to fit `max_w` when given.
function Text.fit(kind, s, max_w)
    local spec = specOf(kind)
    s = Text.shown(kind, s)
    if not max_w then return s end
    return fit(spec, s, max_w)
end

-- Draw an already fitted string with its top-left at (x, y); returns its width.
function Text.draw(bb, x, y, kind, s, color)
    local spec = specOf(kind)
    local face, track = spec.face, spec.tracking
    local baseline = y + spec.ascent
    color = color or Theme.color("ink")
    if isRTL(s) then
        local tw = shapedLine(face, s)
        tw.fgcolor = color
        tw:paintTo(bb, x, baseline - tw:getBaseline())
        return tw:getWidth()
    end
    local rgb = Color.isRGB(color)
    local pen = 0
    local prev = 0
    for _i, cp in ipairs(codepoints(s)) do
        local glyph = RenderText:getGlyph(face, cp, false)
        if prev ~= 0 then pen = pen + face.ftsize:getKerning(prev, cp) end
        local gbb = glyph.bb
        if rgb then
            bb:colorblitFromRGB32(gbb, x + pen + glyph.l, baseline - glyph.t, 0, 0, gbb:getWidth(), gbb:getHeight(), color)
        else
            bb:colorblitFrom(gbb, x + pen + glyph.l, baseline - glyph.t, 0, 0, gbb:getWidth(), gbb:getHeight(), color)
        end
        pen = pen + glyph.ax + track
        prev = cp
    end
    return pen - track
end

-- Line height of a kind of text.
function Text.height(kind)
    return specOf(kind).height
end

-- Split `s` into at most `max_lines` lines that fit `max_w`; the last line
-- gets an ellipsis when text is left over.
function Text.wrap(kind, s, max_w, max_lines)
    local spec = specOf(kind)
    s = Text.shown(kind, s)
    local lines, line = {}, ""
    -- words, with each line break kept as a word of its own
    local words = {}
    for word in s:gsub("\n", " \n "):gmatch("[^ \t]+") do words[#words + 1] = word end
    for i, word in ipairs(words) do
        if word == "\n" then
            lines[#lines + 1] = line
            line = ""
        else
            local try = line == "" and word or (line .. " " .. word)
            if measure(spec, try) <= max_w then
                line = try
            else
                if line ~= "" then lines[#lines + 1] = line end
                line = word
            end
        end
        if max_lines and #lines >= max_lines and i < #words then
            local rest = table.concat(words, " ", i + 1):gsub("%s*\n%s*", " ")
            lines[max_lines] = fit(spec, lines[max_lines] .. " " .. line .. " " .. rest, max_w)
            for j = #lines, max_lines + 1, -1 do lines[j] = nil end
            return lines
        end
    end
    if line ~= "" then lines[#lines + 1] = fit(spec, line, max_w) end
    if max_lines and #lines > max_lines then
        lines[max_lines] = fit(spec, table.concat(lines, " ", max_lines), max_w)
        for i = #lines, max_lines + 1, -1 do lines[i] = nil end
    end
    return lines
end

-- Forget measured widths (faces change with the theme).
function Text.reset()
    widths = setmetatable({}, { __mode = "k" })
end

Theme.onChange(Text.reset)

return Text
