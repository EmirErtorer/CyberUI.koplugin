-- The batch of fixes after 1.0.5: page turn keys page the library and the
-- drop-down menu, a tap in the tab bar's gap is swallowed (no corner gesture
-- reaches the frontlight), and the menu closes cleanly after paging.
local H = ...
local S = 0.8
local Screen = require("device").screen

local function menu() return require("cyberui/menu").current() end

H.step(1, function() H.app().go("library") end)
H.step(S, function()
    local s = H.app().current()
    H.check(H.screen() == "library", "library is open")
    if (s.pages or 1) > 1 then
        H.event("PageNext")
    else
        H.say("library has one page: key paging not checked")
    end
end)
H.step(S, function()
    local s = H.app().current()
    if (s.pages or 1) > 1 then
        H.check(s.page == 2, "PageNext turns the library to page 2: " .. tostring(s.page))
        H.event("PagePrev")
    end
end)
H.step(S, function()
    local s = H.app().current()
    H.check(s.page == 1, "PagePrev turns it back: " .. tostring(s.page))
    -- the tab bar's top divider is no tab: the tap must still be taken
    local th = require("cyberui/theme").get()
    local host = H.top()
    local el = host and host.target and host:target({ x = Screen:getWidth() / 2, y = Screen:getHeight() - th.size.tabbar - 1 }, "on_tap")
    H.check(el ~= nil, "a tap in the tab bar gap is taken")
    H.shot("fx01-library")
    H.app().koreaderMenu()
end)
H.step(S, function()
    local m = menu()
    H.check(m ~= nil, "the menu opens")
    if m and (m.pages or 1) > 1 then
        local p = m.page
        H.event("PageNext")
        H.say("menu pages " .. tostring(m.pages))
        H.check(m.page == p + 1, "PageNext pages the menu: " .. tostring(m.page))
    else
        H.say("menu has one page: key paging not checked")
    end
end)
H.step(S, function() H.event("Back") end)
H.step(S, function() H.app().go("home") end)
