-- Series from the books' own details: Collections has a Series switch, a series card
-- opens its books in series order. (Five books are given a series here, as an EPUB's
-- metadata would give them.)
local H = ...
local Books = require("cyberui/data/books")
local orig = Books.info
local order = { 3, 1, 5, 2, 4 }
local picked = {}
Books.info = function(path)
    local info = orig(path)
    local mine = picked[path]
    if mine then
        info = setmetatable({ series = "The Wise Cycle", series_index = mine }, { __index = info })
    end
    return info
end
H.step(1, function()
    local all = require("cyberui/data/library").all()
    for i = 1, math.min(5, #all) do picked[all[i]] = order[i] end
    H.app().go("collections")
end)
H.step(1.5, function() H.tap("Series") end)
H.step(1.5, function()
    H.shot("series-list")
    H.check(H.find("The Wise Cycle", nil, true) ~= nil, "the series is listed")
    H.tap("The Wise Cycle")
end)
H.step(2, function()
    H.shot("series-books")
    local lib = H.app().current()
    H.check(lib.params and lib.params.series == "The Wise Cycle", "the series opens in the browser")
    local indexes = {}
    for _i, it in ipairs(lib.items) do if it.path then indexes[#indexes + 1] = Books.info(it.path).series_index end end
    local ok = #indexes == 5
    for i = 2, #indexes do ok = ok and indexes[i - 1] < indexes[i] end
    H.check(ok, "its books are in series order")
end)
