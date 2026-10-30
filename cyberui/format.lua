-- Short text forms shared by every screen: how long ago, durations, minutes
-- and file sizes, in the style's terse capitals.

local _ = require("cyberui/gettext")

local Case = require("cyberui/i18n/case")

local Format = {}

-- `s` in capitals for the language in use (Turkish i, Greek without accents...).
function Format.upper(s)
    return Case.upper(s, _.language())
end

-- The first `n` characters of `s` (whole UTF-8 characters, not bytes).
function Format.chars(s, n)
    local out, count = {}, 0
    for c in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        out[#out + 1] = c
        if count == n then break end
    end
    return table.concat(out)
end

-- os.date with the names of days and months in the reader's language (KOReader
-- has them translated): %a %A %b %B give those names, the rest is as os.date.
function Format.date(fmt, t)
    local ok, datetime = pcall(require, "datetime")
    if ok then
        fmt = fmt:gsub("%%([aAbB])", function(c)
            local short = os.date("%a", t)
            local name
            if c == "a" then name = datetime.shortDayOfWeekTranslation[short]
            elseif c == "A" then name = datetime.shortDayOfWeekToLongTranslation[short]
            elseif c == "b" then name = datetime.shortMonthTranslation[os.date("%b", t)]
            else name = datetime.longMonthTranslation[os.date("%B", t)] end
            return (name or os.date("%" .. c, t)):gsub("%%", "%%%%")
        end)
    end
    return os.date(fmt, t)
end

-- "JUST NOW", "5H AGO", "3D AGO", "2W AGO" for a time in the past.
function Format.ago(t)
    if not t then return _("NEVER") end
    local d = os.time() - t
    if d < 3600 then return _("JUST NOW") end
    if d < 86400 then return string.format(_("%dH AGO"), math.floor(d / 3600)) end
    if d < 86400 * 14 then return string.format(_("%dD AGO"), math.floor(d / 86400)) end
    return string.format(_("%dW AGO"), math.floor(d / (86400 * 7)))
end

-- Whole minutes in a number of seconds.
function Format.minutes(s)
    return math.floor((s or 0) / 60)
end

-- "6:12" hours and minutes, or "38M" under an hour.
function Format.duration(s)
    s = s or 0
    if s < 3600 then return string.format(_("%dM"), math.floor(s / 60)) end
    return string.format("%d:%02d", math.floor(s / 3600), math.floor(s % 3600 / 60))
end

-- A whole number with a space between thousands: "18 430".
function Format.number(n)
    local s = string.format("%d", math.floor((n or 0) + 0.5))
    return (s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
end

-- An amount of the in-game money, "¥1 430".
function Format.credits(n)
    return "\u{00A5}" .. Format.number(n)
end

-- "3.1 GB", "1.2 MB", "640 KB" for a size in bytes.
function Format.size(bytes)
    if not bytes then return "?" end
    if bytes >= 1073741824 then return string.format("%.1f GB", bytes / 1073741824) end
    if bytes >= 1048576 then return string.format("%.1f MB", bytes / 1048576) end
    return string.format("%d KB", math.max(1, math.floor(bytes / 1024)))
end

return Format
