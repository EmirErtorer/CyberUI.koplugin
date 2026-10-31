-- With ZenOS running, its Home tab in a book's menu goes to CyberUI home (not to
-- ZenOS's own library) when CyberUI is the chosen start screen.
-- Run: CYBERUI_SHOT_BOOKS=<folder of epubs> E2E_NO_DIR=1 HOME_SETUP=tests/e2e/setup_zenos.sh tests/e2e/run.sh tests/e2e/zenhome.lua <out>
local H = ...
H.step(8, function()
    H.check(require("cyberui/menu").zenosRunning(), "ZenOS is running")
    H.app().openBook(require("cyberui/data/library").all()[1])
end)
H.step(5, function() require("apps/reader/readerui").instance.menu:onShowMenu() end)
H.step(2, function()
    local m = require("cyberui/menu").current()
    local idx
    for i, t in ipairs(m.tabs) do if t.id == "zen_library_home" then idx = i end end
    H.check(idx ~= nil, "the menu has ZenOS's Home tab")
    m:switchTab(idx)
end)
H.step(3, function()
    H.check(H.cyberTop(), "CyberUI is on top after ZenOS's Home tab")
    H.check(H.screen() == "home", "home is shown")
end)
