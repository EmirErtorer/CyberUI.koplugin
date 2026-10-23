-- KOReader's drop-down menu in CyberUI's style: drops down over CyberUI
-- (30-50% of the screen), switches tabs, goes into a submenu, toggles a
-- checkbox in place and goes back up.
local H = ...
local S = 0.8

local function menu() return require("cyberui/menu").current() end

H.step(1, function() H.app().koreaderMenu() end)
H.step(S, function()
    local m = menu()
    local h = m and m.panel.h / require("device").screen:getHeight()
    H.check(m ~= nil, "the styled menu drops down over CyberUI")
    H.check(h and h >= 0.29 and h <= 0.51, "and covers 30-50% of the screen: " .. tostring(h))
    H.shot("sm01-menu")
    for i, tab in ipairs(m.tabs) do
        if tab.icon == "appbar.settings" then m:switchTab(i) end
    end
end)
H.step(S, function()
    local m = menu()
    H.check(m.tabs[m.tab].icon == "appbar.settings", "switches to KOReader's settings tab")
    H.shot("sm02-settings")
    -- the first submenu holding a checkbox
    for _i, item in ipairs(m.items) do
        local sub = item.sub_item_table_func and item.sub_item_table_func() or item.sub_item_table
        if sub then
            for _j, it in ipairs(sub) do
                if it.checked_func and it.callback and not it.sub_item_table and not it.sub_item_table_func then
                    m:select(item)
                    return
                end
            end
        end
    end
end)
H.step(S, function()
    local m = menu()
    H.check(#m.trail == 1, "goes into a submenu")
    H.shot("sm03-submenu")
    for _i, it in ipairs(m.items) do
        if it.checked_func and it.callback and (not it.enabled_func or it.enabled_func()) then
            m.probe, m.before = it, it.checked_func()
            m:select(it)
            return
        end
    end
end)
H.step(S, function()
    local m = menu()
    if m.probe then
        H.check(m.probe.checked_func() ~= m.before, "a checkbox toggles: " .. tostring(m.probe.text or "?"))
        H.check(menu() == m, "and the menu stays open")
        m:select(m.probe)   -- put it back
    end
end)
H.step(S, function() H.event("Back") end)
H.step(S, function()
    local m = menu()
    H.check(m ~= nil and #m.trail == 0, "Back goes up a menu")
end)
H.step(S, function() H.event("Back") end)
H.step(S, function() H.check(menu() == nil and H.screen() == "home", "Back at the top closes the menu") end)

-- CyberUI's own Deck tab, ZenOS's tabs when it is there, and the styled menu inside a book
local function tabIndex(m, pred) for i, t in ipairs(m.tabs) do if pred(t) then return i end end end
H.step(S, function() H.app().koreaderMenu() end)
H.step(S, function()
    local m = menu()
    local i = tabIndex(m, function(t) return t.deck end)
    if require("cyberui/menu").zenosRunning() then
        H.check(i == nil, "no Deck while ZenOS runs")
    else
        H.check(i == 1, "the Deck is the first tab without ZenOS")
        m:switchTab(i)
        H.check(#m:deckButtons() >= 4, "the Deck has its controls")
    end
end)
H.step(S, function()
    H.shot("sm04-deck")
    local m = menu()
    local qs = tabIndex(m, function(t) return t.id == "quicksettings" end)
    if qs then m:switchTab(qs) end
end)
H.step(S, function()
    local m = menu()
    if m.tabs[m.tab].id == "quicksettings" then
        H.check(#m:panelButtons(m.tabs[m.tab]) > 0, "ZenOS Controls show their buttons")
        H.shot("sm05-zen-controls")
        local la = tabIndex(m, function(t) return t.id == "app_launcher" end)
        if la then m:switchTab(la) end
    end
end)
H.step(S, function()
    local m = menu()
    if m.tabs[m.tab].id == "app_launcher" then
        H.check(#m:panelButtons(m.tabs[m.tab]) > 0, "ZenOS Launcher shows its buttons")
        H.shot("sm06-zen-launcher")
    end
    m:close()
end)
H.step(S, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(3, function() require("apps/reader/readerui").instance.menu:onShowMenu() end)
H.step(S, function()
    local m = menu()
    H.check(m ~= nil and m.reader, "the menu inside a book is the styled one")
    require("ui/uimanager"):forceRePaint()
    H.shot("sm07-reader")
    if m then m:close() end
end)
H.step(S, function() H.check(menu() == nil, "and it closes") end)
