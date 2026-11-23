-- Home asked for while home is shown: nothing is painted again when nothing
-- on it changed, a tap still lands where the buttons are, and a change (a
-- setting here) is painted.
local H = ...
local S = 0.8
local UIManager = require("ui/uimanager")

local painted = 0
local real = UIManager.setDirty
UIManager.setDirty = function(self, widget, ...)
    if widget and widget.name == "cyberui" then painted = painted + 1 end
    return real(self, widget, ...)
end

H.step(1.5, function() H.app().go("home") end)
H.step(S, function()
    H.check(H.screen() == "home" and H.cyberTop(), "home is shown")
    painted = 0
    H.app().go("home")
end)
H.step(S, function()
    H.check(painted == 0, "home again with nothing changed is not painted again: " .. painted)
    H.check(H.screen() == "home", "and home is still shown")
    H.tap("LIBRARY")
end)
H.step(S, function()
    H.check(H.screen() == "library", "a tap after it still opens the library")
    H.app().go("home")
end)
H.step(S, function()
    local Settings = require("cyberui/settings")
    H.keep_card = Settings.get("home_card", true)
    Settings.set("home_card", not H.keep_card)
    painted = 0
    H.app().go("home")
end)
H.step(S, function()
    H.check(painted > 0, "home again after a setting changed is painted")
    H.shot("homeagain-changed")
    require("cyberui/settings").set("home_card", H.keep_card)
    H.app().go("home")
end)
H.step(S, function()
    UIManager.setDirty = real
    H.check(H.screen() == "home", "home is back as it was")
end)
