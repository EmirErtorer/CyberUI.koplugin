-- The ASCII sleep screen redraws the sleep screen KOReader builds: the book
-- cover in "Book covers" mode with the message kept as text, custom images in
-- "Custom images" mode, and leaves other screens alone.
local H = ...
local S = 1.2
local Settings = require("cyberui/settings")
local Screensaver = require("ui/screensaver")

-- Show KOReader's sleep screen of `kind` and report whether the picture was redrawn.
local function sleep(kind, mode, shot)
    G_reader_settings:saveSetting("screensaver_type", kind)
    G_reader_settings:makeTrue("screensaver_show_message")
    Settings.set("ascii_sleep_mode", mode)
    Screensaver:setup()
    Screensaver:show()
    local w = Screensaver.screensaver_widget
    local inner = w and w.widget
    while inner and inner[1] and inner.vertical_position == nil and inner.image == nil do inner = inner[1] end
    require("ui/uimanager"):forceRePaint()
    H.shot(shot)
    return inner and inner.image_disposable and inner.image ~= nil and inner.width == require("device").screen:getWidth()
end

H.step(1, function()
    local book = require("cyberui/data/library").all()[1]
    G_reader_settings:saveSetting("lastfile", book)
    H.check(sleep("cover", "covers", "sl01-cover"), "book cover becomes ASCII")
end)
H.step(S, function()
    Screensaver:close()
end)
H.step(S, function()
    H.check(sleep("random_image", "images", "sl02-image"), "a custom image becomes ASCII")
end)
H.step(S, function() Screensaver:close() end)
H.step(S, function()
    H.check(not sleep("random_image", "covers", "sl03-untouched"), "Book covers mode leaves images alone")
end)
H.step(S, function() Screensaver:close() end)
-- a transparent PNG: its see-through background must stay empty
H.step(S, function()
    G_reader_settings:saveSetting("screensaver_dir", os.getenv("CYBERUI_DRIVE_SCRIPT"):match("^(.*)/") .. "/fixtures/sleep")
    G_reader_settings:makeFalse("screensaver_show_message")
    Settings.set("ascii_sleep_mode", "images")
    G_reader_settings:saveSetting("screensaver_type", "random_image")
    Screensaver:setup()
    Screensaver:show()
    require("ui/uimanager"):forceRePaint()
    H.shot("sl04-transparent")
    -- the corner is see-through in the PNG: no dots there, only the background
    local bb = require("device").screen.bb
    local corner_lit = 0
    for x = 0, 60, 3 do for y = 0, 60, 3 do
        local p = bb:getPixel(x, y):getColorRGB32()
        if p.r + p.g + p.b > 200 then corner_lit = corner_lit + 1 end
    end end
    H.check(corner_lit == 0, "the transparent background stays empty (" .. corner_lit .. " lit)")
end)
H.step(S, function() Screensaver:close() end)
