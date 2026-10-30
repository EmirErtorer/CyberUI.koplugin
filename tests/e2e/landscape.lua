-- A book read in landscape, left with the Home gesture: home must come back
-- upright and laid out for the screen it is on, not stuck sideways.
local H = ...
local S = 0.8
local Screen = require("device").screen
local book

H.step(1, function()
    G_reader_settings:saveSetting("park_reader", true)
    book = require("cyberui/data/library").all()[1]
    H.app().openBook(book)
end)
H.step(2.5, function()
    local ui = require("apps/reader/readerui").instance
    H.check(ui ~= nil, "book opened")
    ui:handleEvent(require("ui/event"):new("SetRotationMode", 1))
end)
H.step(S, function()
    H.check(Screen:getWidth() > Screen:getHeight(), "reading in landscape")
    require("apps/reader/readerui").instance:handleEvent(require("ui/event"):new("Home"))
end)
H.step(3, function()
    H.check(H.cyberTop() and H.screen() == "home", "back on CyberUI home")
    H.check(Screen:getWidth() < Screen:getHeight(), "screen upright again")
    local host = H.top()
    local d = host and host.dimen
    H.check(d and d.w == Screen:getWidth() and d.h == Screen:getHeight(), "home laid out for the upright screen")
end)
