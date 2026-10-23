-- KOReader's drop-down menu in CyberUI's style: opens from CyberUI, switches
-- tabs, goes into a submenu, toggles a checkbox in place and goes back up.
local H = ...
local S = 0.8

local function menu() return H.app().current() end

H.step(1, function() H.app().koreaderMenu() end)
H.step(S, function()
    H.check(H.screen() == "menu", "the styled menu opens from CyberUI")
    H.shot("sm01-menu")
    local m = menu()
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
        H.check(H.screen() == "menu", "and the menu stays open")
        m:select(m.probe)   -- put it back
    end
end)
H.step(S, function() H.event("Back") end)
H.step(S, function()
    local m = menu()
    H.check(H.screen() == "menu" and #m.trail == 0, "Back goes up a menu")
end)
H.step(S, function() H.event("Back") end)
H.step(S, function() H.check(H.screen() == "home", "Back at the top leaves the menu") end)
