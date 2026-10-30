-- How many recent books the home list shows with a data shard on top, and how
-- much room is left under the last one. Run at a device's size, e.g.
--   tests/e2e/run.sh tests/e2e/homefit.lua out 1072 1448 300
-- Needs setup_newfeatures.sh (history and books).
local H = ...
local function app() return H.app() end

H.step(2, function()
    local Library = require("cyberui/data/library")
    local DocSettings = require("docsettings")
    local ds = DocSettings:open(Library.all()[1])
    ds:saveSetting("annotations", { { text = "A highlight for the shard on home.", chapter = "One", datetime = "2026-10-11 21:01:00", page = 10 } })
    ds:flush()
    require("cyberui/data/shards").refresh(Library.all()[1])
    app().go("home")
end)
H.step(2, function()
    local col = H.findWhere(function(el) return el.clip == true and el.children ~= nil end)
    H.check(col ~= nil, "found the recent column")
    local last = col.children[#col.children]
    local rows = #col.children
    local left = (col.y + col.h) - (last.y + last.h)
    H.check(true, string.format("recent column: %d children, column %d px tall, %d px left under the last (row height %d)", rows, col.h, left, last.h))
    H.shot("homefit")
end)
