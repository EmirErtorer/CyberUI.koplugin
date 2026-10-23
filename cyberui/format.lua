-- Short text forms shared by every screen: how long ago, durations, minutes
-- and file sizes, in the style's terse capitals.

local _ = require("gettext")

local Format = {}

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

-- "1.2 MB", "640 KB" for a size in bytes.
function Format.size(bytes)
    if not bytes then return "?" end
    if bytes >= 1048576 then return string.format("%.1f MB", bytes / 1048576) end
    return string.format("%d KB", math.max(1, math.floor(bytes / 1024)))
end

return Format
