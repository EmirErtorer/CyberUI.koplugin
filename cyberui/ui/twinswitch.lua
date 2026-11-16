-- The switch between CyberUI and its twin SolarUI, shown first on the System
-- page and in the menu's Controls: the plaque (ui/twinart.lua), half garden
-- and half deck, the side in charge lit, and a line under it saying what a
-- tap does. A tap hands over to the other at once, or offers to install,
-- switch on or restart for it (see twin.lua).

local Blitbuffer = require("ffi/blitbuffer")
local DataStorage = require("datastorage")
local Element = require("cyberui/ui/element")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local RenderImage = require("ui/renderimage")
local Theme = require("cyberui/theme")
local TwinArt = require("cyberui/ui/twinart")
local Twin = require("cyberui/twin")
local _ = require("cyberui/gettext")

local TwinSwitch = {}

-- The plaque drawn last, kept for the next paint: { key, bb }.
local kept = {}

-- The plaque at w x h with `active` in charge, laid on the page colour (and
-- turned for KOReader's night mode, which turns it back), in the screen's
-- pixel type; drawn once and kept until the size, state or colours change.
local function picture(screen_type, w, h, active)
    local th = Theme.get()
    local night = Theme.nightMode()
    local key = table.concat({ w, h, active, tostring(th.c.bg), tostring(night), screen_type }, "|")
    if kept.key == key then return kept.bb end
    if kept.bb then kept.bb:free() end
    kept = {}
    local file = DataStorage:getDataDir() .. "/cache/cyberui-twin.svg"
    local f = io.open(file, "w")
    if not f then return nil end
    f:write(TwinArt.document(w, h, active))
    f:close()
    local ok, img = pcall(function() return RenderImage:renderSVGImageFile(file, w, h, 1) end)
    os.remove(file)
    if not (ok and img) then return nil end
    local rgb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)
    rgb:paintRect(0, 0, w, h, th.c.bg)
    rgb:alphablitFrom(img, 0, 0, 0, 0, w, h)
    img:free()
    local out = Blitbuffer.new(w, h, screen_type)
    out:blitFrom(rgb, 0, 0, 0, 0, w, h)
    rgb:free()
    if night then out:invertRect(0, 0, w, h) end
    kept = { key = key, bb = out }
    return out
end

-- How much of the page's width the plaque takes, centred on it.
local SHARE = 0.8

-- The plaque, always five times as wide as it is high.
local Plaque = Element:extend({})

-- A fifth of the width it takes.
function Plaque:naturalHeight(w)
    return math.floor((w or self.w or Theme.px(500)) * SHARE / 5)
end

-- Draw the plaque in the middle of the box.
function Plaque:draw(bb, x, y)
    if self.w < 2 or self.h < 2 then return end
    local w = math.floor(self.w * SHARE)
    local img = picture(bb:getType(), w, self.h, self.active)
    if img then bb:blitFrom(img, x + math.floor((self.w - w) / 2), y, 0, 0, w, self.h) end
end

-- What a tap does, in a line.
local function hint()
    local other = Twin.OTHER.name
    local s = Twin.otherStatus()
    if s == "missing" then return string.format(_("%s is not installed yet. Tap to get it."), other) end
    if s == "disabled" then return string.format(_("%s is switched off. Tap to switch it on."), other) end
    if s == "restart" then return string.format(_("%s is installed. Restart KOReader to use it."), other) end
    return string.format(_("CyberUI is in charge. Tap to switch to %s."), other)
end

-- Build it. o: { width (optional) }.
function TwinSwitch.build(o)
    o = o or {}
    local th = Theme.get()
    return Layout.Column:new({ gap = th.space.xs, width = o.width, on_tap = Twin.switch, children = {
        Plaque:new({ active = Twin.active() }),
        Label:new({ text = hint(), kind = "small", color = "muted", align = "center" }),
    } })
end

return TwinSwitch
