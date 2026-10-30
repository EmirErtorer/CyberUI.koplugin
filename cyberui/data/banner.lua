-- What the identity banner on home says: a big line (a preset, the reader's
-- own text, or a live line: greeting, a highlight from their books, the
-- device's status) and a small line above it (the device, the reader's
-- handle, a book, or nothing). Chosen in System > Home.

local Device = require("device")
local DeviceInfo = require("cyberui/data/device")
local History = require("cyberui/data/history")
local Profile = require("cyberui/data/profile")
local Shards = require("cyberui/data/shards")
local Books = require("cyberui/data/books")
local Settings = require("cyberui/settings")
local _ = require("gettext")

local Banner = {}

-- Fixed lines the big line can show; the first is the default.
Banner.PRESETS = {
    { id = "online", text = _("READER // ONLINE") },
    { id = "active", text = _("DECK ACTIVE") },
    { id = "nominal", text = _("SYSTEMS NOMINAL") },
    { id = "boot", text = _("BOOT COMPLETE") },
    { id = "jack", text = _("READY TO JACK IN") },
    { id = "link", text = _("LINK ESTABLISHED") },
}

-- Lines that change on their own, then the reader's own text.
Banner.LIVE = {
    { id = "greeting", label = _("Greeting"), sub = _("Time of day + handle") },
    { id = "highlight", label = _("Highlight"), sub = _("From your books") },
    { id = "status", label = _("Status"), sub = _("Battery // Wi-Fi") },
    { id = "custom", label = _("Your own text"), sub = _("Typed in") },
}

-- What the small line can show.
Banner.TOPS = {
    { id = "device", label = _("Device") },
    { id = "handle", label = _("Your handle") },
    { id = "book", label = _("Book"), sub = _("Highlight's or current") },
    { id = "off", label = _("Nothing") },
}

-- How many read books are searched for a highlight each time home opens.
local HIGHLIGHT_BOOKS = 8

-- The highlight on show until home opens again: { text, path } or false.
local shown

-- The reader's handle (see Profile.handle).
function Banner.handle()
    return Profile.handle()
end

-- The device family, e.g. "KOBO", "KINDLE" or "BOOX".
function Banner.device()
    local function is(name) return Device[name] and Device[name](Device) end
    if is("isKobo") then return "KOBO" end
    if is("isKindle") then return "KINDLE" end
    if is("isPocketBook") then return "POCKETBOOK" end
    if is("isRemarkable") then return "REMARKABLE" end
    if is("isCervantes") then return "CERVANTES" end
    if is("isAndroid") then
        local ok, android = pcall(require, "android")
        local maker = ok and android.prop and android.prop.manufacturer
        if maker and maker:lower() == "onyx" then return "BOOX" end
        return maker and maker:upper() or "ANDROID"
    end
    return DeviceInfo.name()
end

-- The texts of the highlights saved in a book's reading data.
local function highlightsOf(path)
    local out = {}
    for _i, shard in ipairs(Shards.of(path)) do out[#out + 1] = shard.text end
    return out
end

-- Pick a new highlight next time one is needed (home was opened again).
function Banner.shuffle()
    shown = nil
end

-- A random highlight from the recently read books, or nil when there is none.
local function highlight()
    if shown == nil then
        shown = false
        local books = History.recent(HIGHLIGHT_BOOKS)
        for i = #books, 2, -1 do
            local j = math.random(i)
            books[i], books[j] = books[j], books[i]
        end
        for _i, b in ipairs(books) do
            local list = highlightsOf(b.path)
            if #list > 0 then
                local text = list[math.random(#list)]:gsub("%s+", " ")
                shown = { text = "\u{201C}" .. text .. "\u{201D}", path = b.path }
                break
            end
        end
    end
    return shown or nil
end

-- The greeting for the hour.
local function greeting()
    local hour = tonumber(os.date("%H"))
    local fmt
    if hour < 5 then fmt = _("NIGHT SHIFT, %s")
    elseif hour < 12 then fmt = _("GOOD MORNING, %s")
    elseif hour < 18 then fmt = _("GOOD AFTERNOON, %s")
    else fmt = _("GOOD EVENING, %s") end
    return string.format(fmt, Banner.handle())
end

-- The device's state worth a word, or nil.
local function status()
    local pct = DeviceInfo.battery()
    if DeviceInfo.charging() then return string.format(_("CHARGING // %d%%"), pct or 0) end
    if pct and pct <= 20 then return _("POWER LOW // PLUG IN") end
    if DeviceInfo.wifi() then return _("UPLINK ACTIVE") end
    return nil
end

-- The preset with `id`, or the default one.
local function preset(id)
    for _i, p in ipairs(Banner.PRESETS) do
        if p.id == id then return p.text end
    end
    return Banner.PRESETS[1].text
end

-- The big line and whether it is a quote (shown smaller, on two lines).
function Banner.title()
    local id = Settings.get("banner_title", "online")
    if id == "greeting" then return greeting() end
    if id == "status" then return status() or preset() end
    if id == "custom" then
        local t = Settings.get("banner_text")
        return (t and t ~= "") and t or preset()
    end
    if id == "highlight" then
        local h = highlight()
        if h then return h.text, true end
        return preset()
    end
    return preset(id)
end

-- The small line, or nil for none.
function Banner.top()
    local id = Settings.get("banner_top", "device")
    if id == "off" then return nil end
    if id == "handle" then return "ID // " .. Banner.handle() end
    if id == "book" then
        local h = Settings.get("banner_title") == "highlight" and highlight()
        local cur = h and h.path or (History.current() or {}).path
        if cur then return "FILE // " .. Books.info(cur).title end
    end
    return "CYBERDECK // " .. Banner.device() .. " // " .. _("OPERATOR ACCESS")
end

return Banner
