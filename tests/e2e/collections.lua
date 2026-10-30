-- Hold a collection to delete it; Favorites stays.
local H = ...
local S = 0.8
local Collections = require("cyberui/data/collections")

H.step(1, function()
    Collections.create("Zz test")
    H.app().push("collections")
end)
H.step(S, function()
    H.check(H.find("Zz test") ~= nil, "new collection listed")
    H.hold("Zz test")
end)
H.step(S, function()
    H.check(H.find("Delete this collection?") ~= nil, "asks before deleting")
    H.tap("Delete")
end)
H.step(1.2, function()
    H.check(H.find("Zz test") == nil, "collection gone")
    local ok = false
    for _, c in ipairs(Collections.list()) do if c.name == "Zz test" then ok = true end end
    H.check(not ok, "removed from KOReader's collections")
    H.check(not Collections.remove(require("readcollection").default_collection_name), "Favorites cannot be removed")
end)
