-- UTF-8 that is safe to hand to the text renderer: a string cut in the middle
-- of a character (or saved that way by an older version) is repaired here, so
-- it never reaches code that crashes on it.

local Utf8Safe = {}

-- The byte length of the well-formed character starting at `i`, or nil.
local function width(s, i)
    local b = s:byte(i)
    if b < 0x80 then return 1 end
    local n = (b >= 0xC2 and b <= 0xDF and 2) or (b >= 0xE0 and b <= 0xEF and 3) or (b >= 0xF0 and b <= 0xF4 and 4)
    if not n or i + n - 1 > #s then return nil end
    for k = i + 1, i + n - 1 do
        local c = s:byte(k)
        if c < 0x80 or c > 0xBF then return nil end
    end
    return n
end

-- Short strings already checked (labels are painted again and again): string -> clean form.
local checked, checked_n = {}, 0
local CHECKED_MAX, CHECKED_LEN = 1024, 256

-- `s` without any byte that is not part of a whole character (worked out).
local function clean(s)
    -- (plain text, the common case, needs no walk)
    if not s:find("[\128-\255]") then return s end
    local out, i = {}, 1
    while i <= #s do
        local n = width(s, i)
        if n then
            out[#out + 1] = s:sub(i, i + n - 1)
            i = i + n
        else
            i = i + 1
        end
    end
    return table.concat(out)
end

-- `s` without any byte that is not part of a whole character.
function Utf8Safe.clean(s)
    if type(s) ~= "string" then return s end
    local known = checked[s]
    if known then return known end
    local out = clean(s)
    if #s <= CHECKED_LEN then
        if checked_n >= CHECKED_MAX then checked, checked_n = {}, 0 end
        checked[s] = out
        checked_n = checked_n + 1
    end
    return out
end

-- At most `max` bytes of `s`, ending on a whole character, with `tail` after it when it was cut.
function Utf8Safe.clip(s, max, tail)
    s = Utf8Safe.clean(s)
    if #s <= max then return s end
    local cut = max
    -- back up to the start of the character the cut falls in
    while cut > 0 do
        local b = s:byte(cut + 1)
        if b < 0x80 or b >= 0xC0 then break end
        cut = cut - 1
    end
    return s:sub(1, cut) .. (tail or "")
end

return Utf8Safe
