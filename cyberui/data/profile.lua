-- The reader's operator profile: a handle, a rank earned from lifetime reading
-- hours, an ID code, the totals the card shows and a photo chosen from the
-- device. Everything stays on the device; the photo is kept as a small square
-- PNG in KOReader's settings folder, so moving or deleting the original does
-- not lose it.

local Blitbuffer = require("ffi/blitbuffer")
local DataStorage = require("datastorage")
local Goal = require("cyberui/data/goal")
local Insights = require("cyberui/data/insights")
local RenderImage = require("ui/renderimage")
local Settings = require("cyberui/settings")
local bit = require("bit")
local lfs = require("libs/libkoreader-lfs")
local _ = require("cyberui/gettext")

local Profile = {}

-- Ranks, by lifetime hours of reading.
Profile.RANKS = {
    { id = "script_kid", name = _("SCRIPT KID"), hours = 0 },
    { id = "runner", name = _("RUNNER"), hours = 25 },
    { id = "fixer", name = _("FIXER"), hours = 100 },
    { id = "netrunner", name = _("NETRUNNER"), hours = 250 },
    { id = "legend", name = _("LEGEND"), hours = 500 },
}

local ADJECTIVES = { "NIGHT", "NEON", "GHOST", "CHROME", "VOID", "STATIC", "RAZOR", "ECHO", "BLACK", "COLD" }
local NOUNS = { "OWL", "FOX", "WOLF", "MOTH", "RAVEN", "VIPER", "LYNX", "CROW", "HARE", "KITE" }

local PHOTO_PX = 256       -- the stored photo is this many pixels square
Profile.PHOTO_MAX = 1600   -- pictures are read no larger than this on a side
local PHOTO_MAX = Profile.PHOTO_MAX
local photos = {}          -- size -> scaled photo, or false when there is none

-- A bit operation's result as an unsigned 32 bit number (LuaJIT's are signed).
local function u32(v)
    return v % 4294967296
end

-- A 32 bit hash of a string (FNV-1a).
function Profile.hash(s)
    local h = 2166136261
    for i = 1, #s do
        h = u32(bit.bxor(h, s:byte(i)) * 16777619)
    end
    return h
end

-- A deterministic stream of numbers in [0, 1) from a seed string.
function Profile.rng(seed)
    local x = Profile.hash(seed)
    if x == 0 then x = 1 end
    return function()
        x = u32(bit.bxor(x, bit.lshift(x, 13)))
        x = u32(bit.bxor(x, bit.rshift(x, 17)))
        x = u32(bit.bxor(x, bit.lshift(x, 5)))
        return x / 4294967296
    end
end

-- The seed this device's profile is made from, made on first use and kept.
function Profile.seed()
    local s = Settings.get("profile_seed")
    if not s then
        s = string.format("%d-%d", os.time(), math.floor(os.clock() * 1e6))
        Settings.save("profile_seed", s)
    end
    return s
end

-- The reader's handle: the one they typed, else one made from the seed.
function Profile.handle()
    local h = Settings.get("handle")
    if h and h ~= "" then return h end
    local h32 = Profile.hash(Profile.seed())
    return string.format("%s_%s.%d", ADJECTIVES[h32 % #ADJECTIVES + 1], NOUNS[math.floor(h32 / 16) % #NOUNS + 1], math.floor(h32 / 256) % 10)
end

-- The ID code, three groups of hex digits; it does not change with the handle.
function Profile.id()
    local s = Profile.seed()
    return string.format("%04X-%04X-%04X", Profile.hash(s .. "a") % 65536, Profile.hash(s .. "b") % 65536, Profile.hash(s .. "c") % 65536)
end

-- The rank for a number of hours: { index, count, name, next (name or nil),
-- need (hours of the next rank), value (0 to 1 toward it) }.
function Profile.rank(hours)
    local index = 1
    for i, r in ipairs(Profile.RANKS) do
        if hours >= r.hours then index = i end
    end
    local cur, nxt = Profile.RANKS[index], Profile.RANKS[index + 1]
    return {
        index = index, count = #Profile.RANKS, name = cur.name, next = nxt and nxt.name, need = nxt and nxt.hours,
        value = nxt and math.min(1, (hours - cur.hours) / (nxt.hours - cur.hours)) or 1,
    }
end

-- The totals on the card: { hours, pages, days, books, best_run, since }.
function Profile.stats()
    local t = Insights.allTime()
    return {
        hours = t.seconds / 3600, pages = t.pages, days = t.days, since = t.first,
        books = #Goal.finished(), best_run = Insights.streaks().day_best,
    }
end

---------------------------------------------------------------- photo

-- The file the chosen photo is kept in (in `Profile.dir` when a test sets one).
function Profile.photoFile()
    return (Profile.dir or DataStorage:getSettingsDir()) .. "/cyberui-photo.png"
end

-- Free the scaled copies (the photo changed).
local function dropPhotos()
    for k, bb in pairs(photos) do
        if bb then bb:free() end
        photos[k] = nil
    end
end

-- Is there a photo?
function Profile.hasPhoto()
    return lfs.attributes(Profile.photoFile(), "mode") == "file"
end

-- The picture at `path` on a white page, so a see-through PNG does not turn
-- black, at most `max` pixels on a side. Returns it, or nil and a reason.
function Profile.load(path, max)
    local ok, img = pcall(RenderImage.renderImageFile, RenderImage, path, false)
    if not ok or not img then return nil, _("That file is not a picture KOReader can read") end
    local w, h = img:getWidth(), img:getHeight()
    if math.max(w, h) > max then
        -- a big photo is made smaller first, so the copies below stay small
        local f = max / math.max(w, h)
        img = RenderImage:scaleBlitBuffer(img, math.max(1, math.floor(w * f)), math.max(1, math.floor(h * f)), true)
        w, h = img:getWidth(), img:getHeight()
    end
    local flat = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
    flat:fill(Blitbuffer.COLOR_WHITE)
    local kind = img:getType()
    if kind == Blitbuffer.TYPE_BBRGB32 or kind == Blitbuffer.TYPE_BB8A then
        flat:alphablitFrom(img, 0, 0, 0, 0, w, h)
    else
        flat:blitFrom(img, 0, 0, 0, 0, w, h)
    end
    img:free()
    return flat
end

-- Keep the square of `img` at (x, y), `side` pixels wide, as the photo; a
-- part of the square outside the picture stays white. True when it worked,
-- else nil and a reason.
function Profile.savePhoto(img, x, y, side)
    x, y, side = math.floor(x + 0.5), math.floor(y + 0.5), math.max(1, math.floor(side + 0.5))
    local square = Blitbuffer.new(side, side, Blitbuffer.TYPE_BBRGB32)
    square:fill(Blitbuffer.COLOR_WHITE)
    local dx, dy = math.max(0, -x), math.max(0, -y)
    local sx, sy = math.max(0, x), math.max(0, y)
    local w, h = math.min(side - dx, img:getWidth() - sx), math.min(side - dy, img:getHeight() - sy)
    if w > 0 and h > 0 then square:blitFrom(img, dx, dy, sx, sy, w, h) end
    local out = RenderImage:scaleBlitBuffer(square, PHOTO_PX, PHOTO_PX, true)
    local wrote = pcall(out.writePNG, out, Profile.photoFile())
    out:free()
    dropPhotos()
    if not wrote then return nil, _("The photo could not be saved") end
    return true
end

-- Take the middle square of the picture at `path` as the photo.
function Profile.setPhoto(path)
    local img, err = Profile.load(path, PHOTO_MAX)
    if not img then return nil, err end
    local side = math.min(img:getWidth(), img:getHeight())
    local ok, why = Profile.savePhoto(img, math.floor((img:getWidth() - side) / 2), math.floor((img:getHeight() - side) / 2), side)
    img:free()
    return ok, why
end

-- Go back to the generated face.
function Profile.clearPhoto()
    os.remove(Profile.photoFile())
    dropPhotos()
end

-- The photo scaled to size x size, kept for the next draw; nil when there is none.
function Profile.photo(size)
    local bb = photos[size]
    if bb ~= nil then return bb or nil end
    if Profile.hasPhoto() then
        local ok, img = pcall(RenderImage.renderImageFile, RenderImage, Profile.photoFile(), false)
        if ok and img then bb = RenderImage:scaleBlitBuffer(img, size, size, true) end
    end
    photos[size] = bb or false
    return bb
end

return Profile
