-- The cyberpunk batch, each feature used for real and photographed: the
-- operator ID card with a photo from the device, the jack-in card, the bounty
-- board, data shards, the skyline and the colour dial. Needs
-- setup_newfeatures.sh (reading data for the skyline).
local H = ...
local S = 0.8
local Settings = require("cyberui/settings")

local books, home
local function app() return H.app() end
local function screen() return H.app().current() end

-- Highlights for two books, and a picture to use as the photo.
H.step(1, function()
    local Library = require("cyberui/data/library")
    books = Library.all()
    home = G_reader_settings:readSetting("home_dir")
    local DocSettings = require("docsettings")
    local texts = {
        "The only way to deal with an unfree world is to become so absolutely free that your very existence is an act of rebellion.",
        "Whatever you do, do it with all your heart.",
        "Not all those who wander are lost, but some of us simply misplaced the map.",
    }
    for i = 1, 2 do
        local ds = DocSettings:open(books[i])
        local list = {}
        for n, t in ipairs(texts) do
            list[#list + 1] = { text = t, note = n == 1 and "worth remembering" or nil, chapter = "Chapter " .. n, datetime = string.format("2026-10-%02d 21:%02d:00", 10 + i, n), page = n * 10 }
        end
        ds:saveSetting("annotations", list)
        ds:flush()
        require("cyberui/data/shards").refresh(books[i])
    end
    local BB = require("ffi/blitbuffer")
    local pic = BB.new(480, 320, BB.TYPE_BBRGB32)
    pic:fill(BB.Color8(235))
    for y = 0, 319, 8 do pic:paintRect(0, y, 480, 3, BB.Color8(150)) end
    pic:paintRect(150, 60, 180, 200, BB.COLOR_BLACK)
    pic:paintRect(190, 100, 100, 60, BB.COLOR_WHITE)
    pic:writePNG(home .. "/me.png")
    pic:free()
    Library.reset()
    H.check(require("cyberui/data/shards").count() >= 6, "the shards were collected: " .. require("cyberui/data/shards").count())
    Settings.set("handle", nil)
    app().go("home")
end)

---------------------------------------------------------------- home
H.step(S, function()
    H.check(H.find(nil, "bounty") ~= nil, "home has the bounties button")
    H.check(H.findWhere(function(el) return el.shard ~= nil end) ~= nil, "home shows a data shard")
    H.shot("cp01-home")
end)

---------------------------------------------------------------- operator ID card
H.step(S, function()
    H.check(H.find(require("cyberui/data/profile").handle()) ~= nil, "home has the operator strip with the handle")
    app().push("card")
end)
H.step(S, function()
    H.check(H.find("PHOTO") ~= nil, "the card has a PHOTO tag under the face")
    H.shot("cp02-card")
    H.tap("PHOTO")
end)
H.step(S, function()
    H.check(H.find("Choose a picture") ~= nil, "the photo sheet offers a picture from the device")
    H.shot("cp03-photo-sheet")
    H.tap("Choose a picture")
end)
H.step(S, function()
    H.check(screen().id == "filepick", "the file picker opens")
    H.shot("cp04-filepick")
    H.tap("me.png")
end)
H.step(S, function()
    H.check(require("cyberui/data/profile").hasPhoto(), "the picture became the photo")
    H.check(screen().id == "card", "back on the card")
    H.shot("cp05-card-photo")
    H.tap(nil, "edit")
end)
H.step(S, function() H.typeKeys("NOVA") end)
H.step(S, function()
    H.shot("cp05b-handle-input")
    H.tap("Save")
end)
H.step(S, function()
    H.check(require("cyberui/data/profile").handle() == "NOVA", "the handle was changed: " .. require("cyberui/data/profile").handle())
    H.tap(nil, "download")
end)
H.step(S, function()
    local file = string.format("%s/screenshots/cyberui-id-%s.png", require("datastorage"):getDataDir(), require("cyberui/data/profile").id())
    H.check(require("libs/libkoreader-lfs").attributes(file, "size") ~= nil, "the card was saved as a picture")
    H.shot("cp06-card-exported")
    app().go("home")
end)

---------------------------------------------------------------- jack-in card
H.step(S, function()
    local JackIn = require("cyberui/jackin")
    app().flash(JackIn.card(books[1]))
    H.shot("cp07-jackin")
    app().update()
end)

---------------------------------------------------------------- bounty board
H.step(S, function()
    H.tap(nil, "bounty")
end)
H.step(S, function()
    H.check(screen().id == "bounty", "the bounties button opens the board")
    H.check(H.find("CLAIM") ~= nil, "the most wanted book has a poster")
    H.shot("cp08-bounty")
    app().go("home")
end)

---------------------------------------------------------------- data shards
H.step(S, function()
    app().push("shards")
end)
H.step(S, function()
    H.shot("cp09-shards")
    local card = H.findWhere(function(el) return el.shard ~= nil end)
    H.check(card ~= nil, "the shards screen lists shards")
    H.tapAt(card.x + card.w / 2, card.y + card.h / 2)
end)
H.step(S, function()
    H.check(screen().id == "shard", "a tap opens the shard whole")
    H.shot("cp10-shard")
    app().pop()
end)
H.step(S, function()
    H.tap("BY BOOK")
end)
H.step(S, function()
    H.shot("cp11-shards-books")
    app().go("home")
end)

---------------------------------------------------------------- skyline
H.step(S, function()
    Settings.set("cal_view", "skyline")
    app().go("history")
    screen().tab = "calendar"
    app().update()
end)
H.step(S, function()
    H.check(H.findWhere(function(el) return el.buildings ~= nil end) ~= nil, "the calendar shows the skyline")
    H.shot("cp12-skyline-month")
    screen().tab = "goal"
    app().update()
end)
H.step(S, function()
    H.check(H.findWhere(function(el) return el.buildings ~= nil end) ~= nil, "the goal tab shows the year skyline")
    H.shot("cp13-skyline-year")
    Settings.set("cal_view", nil)
end)

---------------------------------------------------------------- colour dial
H.step(S, function()
    Settings.set("scheme", "custom")
    require("cyberui/theme").refresh()
    app().go("settings")
    screen().section = "look"
    app().update()
end)
H.step(S, function()
    H.tap("Pick")
end)
H.step(S, function()
    H.check(screen().id == "colourpick", "the colour dial opens")
    H.shot("cp14-dial")
    local dial = H.findWhere(function(el) return el.hue ~= nil and el.on_change ~= nil end)
    H.check(dial ~= nil, "the dial is on screen")
    local th = require("cyberui/theme")
    H.tapAt(dial.x + dial.w / 2 + dial.w / 2 - th.px(9) - th.px(8), dial.y + dial.h / 2)
end)
H.step(S, function()
    H.check(math.abs(screen().hue - 90) < 4, "a tap on the ring set the hue: " .. screen().hue)
    local dial = H.findWhere(function(el) return el.hue ~= nil and el.on_change ~= nil end)
    H.tapAt(dial.x + dial.w / 2 - 20, dial.y + dial.h / 2 + 30)
end)
H.step(S, function()
    H.check(screen().sat < 1 and screen().val < 1, "a tap in the matrix set saturation and brightness")
    H.shot("cp15-dial-picked")
    H.tap("USE COLOUR")
end)
H.step(S, function()
    H.check(screen().id == "settings" and Settings.get("custom_accent") ~= nil and Settings.get("custom_accent") ~= "#2457D6", "the colour was used: " .. tostring(Settings.get("custom_accent")))
    H.shot("cp16-custom-colour")
    Settings.set("scheme", "mono")
    require("cyberui/theme").refresh()
end)
