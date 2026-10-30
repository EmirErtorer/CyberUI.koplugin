-- Capital letters the way each language writes them. Lua's upper() leaves
-- every letter outside ASCII alone, and the style shows many labels in
-- capitals: Turkish needs i to become İ, German ß becomes SS, Greek capitals
-- carry no accents, and Cyrillic and Latin letters with accents need mapping.
-- No dependencies, so the tools can check translations with it.

local Case = {}

-- The next UTF-8 character of s at i: its code point and byte length.
local function decode(s, i)
    local b = s:byte(i)
    if b < 0x80 then return b, 1 end
    if b >= 0xF0 then
        local b2, b3, b4 = s:byte(i + 1, i + 3)
        return ((b % 8) * 262144) + ((b2 % 64) * 4096) + ((b3 % 64) * 64) + (b4 % 64), 4
    elseif b >= 0xE0 then
        local b2, b3 = s:byte(i + 1, i + 2)
        return ((b % 16) * 4096) + ((b2 % 64) * 64) + (b3 % 64), 3
    elseif b >= 0xC0 then
        return ((b % 32) * 64) + (s:byte(i + 1) % 64), 2
    end
    return b, 1   -- a stray continuation byte
end

-- A code point as UTF-8.
local function encode(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64) end
    if cp < 0x10000 then
        return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
    end
    return string.char(0xF0 + math.floor(cp / 262144), 0x80 + math.floor(cp / 4096) % 64, 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

-- Greek letters with an accent mark, and the capital that carries none.
local GREEK_STRIP = {
    [0x386] = 0x391, [0x388] = 0x395, [0x389] = 0x397, [0x38A] = 0x399, [0x38C] = 0x39F, [0x38E] = 0x3A5, [0x38F] = 0x3A9,
    [0x3AC] = 0x391, [0x3AD] = 0x395, [0x3AE] = 0x397, [0x3AF] = 0x399, [0x3CC] = 0x39F, [0x3CD] = 0x3A5, [0x3CE] = 0x3A9,
    [0x390] = 0x3AA, [0x3B0] = 0x3AB,
}

-- The capital of a code point (a code point, or a string for ß), for language `lang`.
local function upperOf(cp, lang)
    if cp >= 0x61 and cp <= 0x7A then
        if cp == 0x69 and lang == "tr" then return 0x130 end
        return cp - 32
    end
    if cp < 0x80 then return cp end
    if cp == 0xDF then return "SS" end
    if cp >= 0xE0 and cp <= 0xFE and cp ~= 0xF7 then return cp - 32 end
    if cp == 0xFF then return 0x178 end
    if cp == 0x131 then return 0x49 end
    if cp >= 0x100 and cp <= 0x17F then
        if cp == 0x130 or cp == 0x138 or cp == 0x149 or cp == 0x178 then return cp end
        if cp == 0x17F then return 0x53 end
        if (cp >= 0x139 and cp <= 0x148) or (cp >= 0x179 and cp <= 0x17E) then
            return cp % 2 == 0 and cp - 1 or cp
        end
        return cp % 2 == 1 and cp - 1 or cp
    end
    if cp >= 0x370 and cp <= 0x3FF then
        if GREEK_STRIP[cp] then return GREEK_STRIP[cp] end
        if cp == 0x3C2 then return 0x3A3 end
        if (cp >= 0x3B1 and cp <= 0x3C9) or cp == 0x3CA or cp == 0x3CB then return cp - 32 end
        return cp
    end
    if cp >= 0x430 and cp <= 0x44F then return cp - 32 end
    if cp >= 0x450 and cp <= 0x45F then return cp - 80 end
    if cp >= 0x460 and cp <= 0x4FF and cp % 2 == 1 and cp ~= 0x482 then return cp - 1 end
    return cp
end

-- `s` in capitals for language `lang` (a KOReader code such as "tr", "el" or
-- "pt_BR"; nil for none in particular).
function Case.upper(s, lang)
    lang = lang and lang:match("^%a+")
    if not s:find("[\128-\255]") and lang ~= "tr" then return s:upper() end
    local out, i = {}, 1
    while i <= #s do
        local cp, len = decode(s, i)
        local up = upperOf(cp, lang)
        out[#out + 1] = type(up) == "string" and up or encode(up)
        i = i + len
    end
    return table.concat(out)
end

-- Is `s` already in capitals (every letter that has a capital is one)?
function Case.isUpper(s, lang)
    return Case.upper(s, lang) == s
end

return Case
