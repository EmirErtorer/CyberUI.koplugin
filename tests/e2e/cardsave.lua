-- Saving the ID card: SAVE asks for a folder, SAVE HERE writes the picture
-- there and the folder is remembered.
local H = ...
local lfs = require("libs/libkoreader-lfs")
local dir = os.getenv("CYBERUI_DRIVE_OUT") .. "/cardfolder"
lfs.mkdir(dir)
require("cyberui/settings").save("card_dir", dir)

H.step(2, function() require("cyberui/profileflow").card() end)
H.step(1.5, function() H.tap("SAVE") end)
H.step(1.5, function()
    H.check(H.app().current().params and H.app().current().params.pick_dir == true, "a folder is asked for")
    H.check(H.find("SAVE HERE", nil, true) ~= nil, "the picker offers SAVE HERE")
    H.shot("pick-folder")
    H.tap("SAVE HERE")
end)
H.step(2, function()
    local found
    for name in lfs.dir(dir) do if name:match("^cyberui%-id%-.*%.png$") then found = name end end
    H.check(found ~= nil, "the card was saved in the chosen folder")
    H.check(require("cyberui/settings").get("card_dir") == dir, "the folder is remembered")
    H.shot("saved")
end)
