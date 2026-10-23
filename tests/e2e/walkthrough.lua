-- Walk through every screen and button of CyberUI in the emulator, checking
-- where each tap lands and saving a screenshot of each screen.
local H = ...
local S = 0.8   -- seconds between steps

-- Tap an element and check the screen that follows.
local function go(text, icon, want, shot)
    H.step(S, function() H.tap(text, icon) end)
    H.step(S, function()
        H.check(H.cyberTop(), (text or icon) .. ": CyberUI stays on top")
        if want then H.check(H.screen() == want, (text or icon) .. " -> " .. want .. " (got " .. tostring(H.screen()) .. ")") end
        if shot then H.shot(shot) end
    end)
end

H.step(1, function()
    H.check(H.cyberTop(), "boots into CyberUI")
    H.check(H.screen() == "home", "home first")
    H.shot("01-home")
end)

-- library: page, view switch, filters, sort
go("LIBRARY", nil, "library", "02-library")
H.step(S, function() H.swipe("west", 300, 400) end)
H.step(S, function() H.check(H.app().current().page == 2, "swipe pages forward"); H.shot("03-library-page2") end)
H.step(S, function() H.swipe("east", 300, 400) end)
H.step(S, function() H.check(H.app().current().page == 1, "swipe pages back") end)
go(nil, "list", "library", "04-library-list")
go(nil, "grid", "library")
go("Unread", nil, "library")
H.step(S, function() H.check(H.app().current().filter == "unread", "filter chip switches the filter") end)
go("All", nil, "library")
H.step(S, function() H.tap("Sort: Recent") end)
H.step(S, function() H.check(H.find("Sort by") ~= nil, "sort dialog opens"); H.shot("05-sort") end)
H.step(S, function() H.tap("Title") end)
H.step(S, function() H.check(H.find("Sort: Title") ~= nil, "sort by title applied") end)
H.step(S, function() H.tap("Sort: Title") end)
H.step(S, function() H.tap("Recent") end)

-- dossier from a hold on the first book tile
H.step(S, function()
    local grid = H.findWhere(function(el) return el.items ~= nil and el.children ~= nil end)
    local first = grid and grid.children[1]
    H.check(first ~= nil, "library grid has tiles")
    if first then H.holdAt(first.x + 20, first.y + 20) end
end)
H.step(S, function() H.check(H.screen() == "dossier", "hold opens the dossier"); H.shot("06-dossier") end)
H.step(S, function() H.tap("COLLECTION +") end)
H.step(S, function() H.check(H.find("Collections") ~= nil, "collection picker opens"); H.shot("07-collect") end)
H.step(S, function() H.tap("Close") end)
H.step(S, function() H.check(H.find("Collections") == nil or H.screen() == "dossier", "picker closes") end)
H.step(S, function() H.tap("/// PURGE FILE ///") end)
H.step(S, function() H.check(H.find("Abort") ~= nil, "delete asks first"); H.shot("08-purge") end)
H.step(S, function() H.tap("Abort") end)
H.step(S, function() H.check(H.screen() == "dossier", "abort keeps the book") end)
go(nil, "back", "library")

-- the other tabs
go("Caches", nil, "collections", "09-collections")
go("Favorites", nil, "library", "10-favorites")
go(nil, "back", "collections")
go("Log", nil, "history", "11-history")
H.step(S, function()
    local s = H.app().current()
    local before = s.day
    local bars = H.findWhere(function(el) return el.values ~= nil and el.children ~= nil end)
    local b = bars and bars.children[2]
    if b then H.tapAt(b.x + b.w / 2, b.y + b.h - 2) end
    H.check(b ~= nil, "chart has bars (day was " .. tostring(before) .. ")")
end)
H.step(S, function() H.check(H.app().current().day == 2, "tapping a bar selects its day") end)
go("System", nil, "settings", "12-settings")
go("Neon", nil, "settings", "13-neon")
go("Dark", nil, "settings", "14-neon-dark")
go("Home", nil, "settings", "15-settings-home")
go("Speed", nil, "settings", "16-settings-speed")
go("Rebuild", nil, "settings")
go("About", nil, "settings")
go("Look", nil, "settings")
go("Mono", nil, "settings")
go("System", nil, "settings")

-- search
H.step(S, function() H.app().push("search") end)
H.step(S + 0.6, function()
    H.check(H.typed() == "", "search opens CyberUI's keyboard")
    H.typeKeys("marx")
end)
H.step(1, function()
    H.check(H.find("> marx") ~= nil, "results follow the typing before Search is tapped")
    H.shot("16b-search-typing")
    H.tap("Search")
end)
H.step(S, function()
    H.check(H.screen() == "search", "search results shown")
    H.check(H.find("> marx") ~= nil, "query field shows the query")
    H.shot("17-search")
end)

-- home again, open the current book, come back with the gesture action
go("Home", nil, "home")
H.step(S, function() H.tap("RESUME") end)
H.step(3, function()
    local t = H.top()
    H.check(t and t.document ~= nil, "Resume opens the reader")
    H.shot("18-reader")
    H.event("CyberUIHome")
end)
H.step(3, function()
    H.check(H.cyberTop(), "CyberUI home comes back after the book closes")
    H.check(H.screen() == "home", "on the home screen")
    H.shot("19-back-home")
end)

-- leave for the file browser and come back through the menu action
H.step(S, function() H.tap("FILES") end)
H.step(S, function()
    H.check(not H.app().isOpen(), "Files leaves CyberUI")
    local FileManager = require("apps/filemanager/filemanager")
    H.check(FileManager.instance ~= nil, "the file browser is there")
    H.shot("20-filebrowser")
    H.event("CyberUIHome")
end)
H.step(S, function() H.check(H.cyberTop() and H.screen() == "home", "the action opens CyberUI again") end)
