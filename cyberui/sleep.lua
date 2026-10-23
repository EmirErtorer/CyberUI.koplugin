-- The ASCII sleep screen: when it is on (the default), the screen KOReader
-- shows while the reader sleeps is the last book's cover drawn as character
-- art, whatever sleep screen KOReader is set to, except "disable" and books
-- marked to keep their cover off the sleep screen. Done by running after
-- KOReader's own Screensaver:setup, which has already loaded the cover.

local Settings = require("cyberui/settings")

local Sleep = {}

local installed = false

-- The cover of the last book as KOReader's sleep screen would load it, or nil.
local function lastCover(saver)
    local path = G_reader_settings:readSetting("lastfile")
    if not path or require("libs/libkoreader-lfs").attributes(path, "mode") ~= "file" then return nil end
    local ds = saver.ui.doc_settings or require("docsettings"):open(path)
    if ds:isTrue("exclude_screensaver") then return nil end
    if saver.screensaver_type == "cover" and saver.image then return saver.image, path, false end
    local ok, img = pcall(function() return saver.ui.bookinfo:getCoverImage(saver.ui.document, path) end)
    if ok and img then return img, path, true end
    return nil
end

-- Swap KOReader's sleep image for the ASCII one.
local function apply(saver)
    if not Settings.get("ascii_sleep", true) or not saver.ui or saver.screensaver_type == "disable" then return end
    local cover, path, own = lastCover(saver)
    if not cover then return end
    local Screen = require("device").screen
    local RenderImage = require("ui/renderimage")
    local w, h = Screen:getWidth(), Screen:getHeight()
    local cw, ch = cover:getWidth(), cover:getHeight()
    -- fit the cover to the screen, leaving a margin for the art to breathe
    local scale = math.min(w * 0.92 / cw, h * 0.92 / ch)
    local scaled = RenderImage:scaleBlitBuffer(cover, math.max(1, math.floor(cw * scale)), math.max(1, math.floor(ch * scale)), own)
    local title = require("cyberui/data/books").info(path).title
    local art = require("cyberui/gfx/ascii").render(scaled, w, h, { size = 9, title = title })
    scaled:free()
    if saver.image and saver.image ~= cover then saver.image:free() end
    if saver.image == cover then cover:free() end
    saver.screensaver_type = "cover"
    saver.image, saver.image_file = art, nil
end

-- Run after KOReader's sleep screen setup from now on (once per start).
function Sleep.install()
    if installed then return end
    installed = true
    local Screensaver = require("ui/screensaver")
    local setup = Screensaver.setup
    Screensaver.setup = function(saver, ...)
        setup(saver, ...)
        local ok, err = pcall(apply, saver)
        if not ok then require("logger").warn("CyberUI sleep screen:", err) end
    end
end

return Sleep
