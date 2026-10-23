-- After a restart that reopened the last book, closing it lands on CyberUI
-- home when CyberUI was the reader's home (set up by setup_restart.sh).
local H = ...
-- wait for the reopened book (a big PDF can take a few seconds)
for _i = 1, 30 do
    H.step(0.5, function() end)
end
H.step(0.5, function()
    local ui = require("apps/reader/readerui").instance
    H.check(ui ~= nil, "KOReader started in the last book")
    if ui then ui:handleEvent(require("ui/event"):new("Home")) end
end)
H.step(3, function()
    H.check(H.cyberTop() and H.screen() == "home", "closing it shows CyberUI home (top " .. tostring(H.top() and H.top().name) .. ")")
    H.shot("r01-home")
end)
