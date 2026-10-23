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
-- a transparent PNG: its see-through background shows the screen behind it
H.step(S, function() H.app().render("full"); require("ui/uimanager"):forceRePaint() end)
H.step(S, function()
    G_reader_settings:saveSetting("screensaver_dir", os.getenv("CYBERUI_DRIVE_SCRIPT"):match("^(.*)/") .. "/fixtures/sleep")
    G_reader_settings:makeFalse("screensaver_show_message")
    Settings.set("ascii_sleep_mode", "images")
    G_reader_settings:saveSetting("screensaver_type", "random_image")
    local bb = require("device").screen.bb
    local before = bb:copy()
    Screensaver:setup()
    Screensaver:show()
    require("ui/uimanager"):forceRePaint()
    H.shot("sl04-transparent")
    -- the corners are see-through in the PNG: they still show what was there
    local same, total = 0, 0
    for x = 0, 80, 4 do for y = 0, 80, 4 do
        total = total + 1
        local a, b = bb:getPixel(x, y):getColorRGB32(), before:getPixel(x, y):getColorRGB32()
        if a.r == b.r and a.g == b.g and a.b == b.b then same = same + 1 end
    end end
    before:free()
    H.check(same == total, "the screen shows through the transparent background (" .. same .. "/" .. total .. ")")
    -- and the circle in the middle is drawn
    local lit = 0
    local cx, cy = math.floor(bb:getWidth() / 2), math.floor(bb:getHeight() / 2)
    for x = cx - 40, cx + 40, 2 do for y = cy - 40, cy + 40, 2 do
        local p = bb:getPixel(x, y):getColorRGB32()
        if p.r > 120 and p.g < 110 then lit = lit + 1 end
    end end
    H.check(lit > 50, "the circle is drawn (" .. lit .. " red points)")
end)
