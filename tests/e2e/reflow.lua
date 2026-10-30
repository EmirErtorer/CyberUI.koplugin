-- A seamless reload of the open book (KOReader does it a few seconds after a
-- font or margin change): home must stay hidden the whole time.
local H = ...
local UIManager = require("ui/uimanager")
local host
local log = {}
H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(3, function()
    host = H.top() and nil
    for _, e in ipairs(UIManager._window_stack) do if e.widget.name == "cyberui" then host = e.widget end end
    H.check(host and host.invisible, "home hidden under the book")
    local ui = require("apps/reader/readerui").instance
    local orig = host.paintTo
    host.paintTo = function(self, ...) log[#log + 1] = "paint invisible=" .. tostring(self.invisible); return orig(self, ...) end
    ui:reloadDocument(nil, true)
end)
H.step(3, function()
    local ok = true
    for _, l in ipairs(log) do if l ~= "paint invisible=true" then ok = false end end
    H.check(host.invisible, "home still hidden after the reload")
    H.check(ok, "home never painted: " .. table.concat(log, ","))
    local top = H.top()
    H.check(top and top ~= host, "reader on top")
    H.shot("after")
end)
