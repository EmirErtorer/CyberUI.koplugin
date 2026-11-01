-- A long list of collections is paged in the "add to collection" sheet, so every
-- one can be reached.
-- Run: E2E_NO_DIR=1 HOME_SETUP=tests/e2e/setup_home.py tests/e2e/run.sh tests/e2e/collectpages.lua <out>
local H = ...
local Collections = require("cyberui/data/collections")
local book
H.step(6, function()
    for i = 1, 26 do Collections.create(string.format("Shelf %02d", i)) end
    book = require("cyberui/data/library").all()[1]
    H.check(book ~= nil, "there is a book")
    require("cyberui/actions").collect(book)
end)
H.step(2, function()
    H.shot("collect-1")
    H.check(H.find("Shelf 01", nil, true) ~= nil, "the first page shows the first collection")
    H.check(H.find("Shelf 26", nil, true) == nil, "the last collection is on a later page")
    local n = H.find(">", nil, true)
    H.check(n ~= nil, "there is a next-page button")
    H.tapAt(n.x + n.w / 2, n.y + n.h / 2)
end)
H.step(2, function()
    H.shot("collect-2")
    H.check(H.find("Shelf 10", nil, true) ~= nil, "the next page shows the following collections")
    local n = H.find(">", nil, true)
    H.tapAt(n.x + n.w / 2, n.y + n.h / 2)
end)
H.step(2, function()
    H.shot("collect-3")
    H.check(H.find("Shelf 26", nil, true) ~= nil, "the last page reaches the last collection")
    local t = H.find("Shelf 26", nil, true)
    H.tapAt(t.x + t.w / 2, t.y + t.h / 2)
end)
H.step(2, function()
    H.check(Collections.has(book, "Shelf 26"), "ticking a collection on the last page adds the book")
    H.check(H.find("Shelf 26", nil, true) ~= nil, "and the sheet stays on that page")
end)
