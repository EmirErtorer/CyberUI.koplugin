-- CyberUI's menu tab with ZenOS running: it sits after ZenOS's Controls and
-- Launcher and has two pages, the operator ID card and the controls, in the
-- order the reader chose. Run with ZenOS on (WANT=zenos,CyberUI in a setup that
-- leaves the other home plugins off).
local H = ...
local Settings = require("cyberui/settings")
local function menu() return require("cyberui/menu").current() end

H.step(10, function()
    Settings.set("deck_first", nil)
    H.app().open()
    H.app().koreaderMenu()
end)
H.step(2, function()
    local m = menu()
    H.check(m ~= nil, "the menu opens")
    local ids = {}
    for i, t in ipairs(m.tabs) do ids[i] = tostring(t.id or t.icon) end
    H.check(m.tabs[1].id == "quicksettings" and m.tabs[2].id == "app_launcher" and m.tabs[3].deck, "CyberUI's tab follows ZenOS's Controls and Launcher: " .. table.concat(ids, ","))
    m:switchTab(3)
end)
H.step(1.5, function()
    H.check(menu():deckPage() == "card", "the operator ID is the first page")
    H.check(H.find("EDDIES") ~= nil and H.find("OPERATOR ID") ~= nil, "it shows the eddies and the page names")
    H.shot("deck1-card")
    menu():turnDeck(1)
end)
H.step(1.5, function()
    H.check(menu():deckPage() == "controls" and H.find("LUMEN") ~= nil or menu():deckPage() == "controls", "the second page has the controls")
    H.shot("deck2-controls")
    menu():close()
    Settings.set("deck_first", "controls")
    H.app().koreaderMenu()
end)
H.step(2, function()
    local m = menu()
    m:switchTab(3)
end)
H.step(1.5, function()
    H.check(menu():deckPage() == "controls", "with the order changed the controls come first")
    H.shot("deck3-controls-first")
    menu():close()
    Settings.set("deck_first", nil)
end)
