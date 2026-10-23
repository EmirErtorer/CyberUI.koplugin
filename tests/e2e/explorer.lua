-- The library explorer on a copy of the library: make a folder, move a book
-- (with its reading data) into it through the folder picker, open it and use
-- the breadcrumbs, rename the folder, delete the book to the trash and put
-- it back where it was, in its history again. Also the Ink Away tile.
local H = ...
local S = 0.8
local lfs = require("libs/libkoreader-lfs")
local DocSettings = require("docsettings")
local ReadHistory = require("readhistory")
local home, book, name

local function exists(p) return lfs.attributes(p, "mode") ~= nil end
-- history keeps fully resolved paths
local function inHistory(p) return ReadHistory:getIndexByFile(require("ffi/util").realpath(p) or p) ~= nil end

H.step(1, function()
    home = G_reader_settings:readSetting("home_dir")
    for f in lfs.dir(home) do
        if f:match("%.pdf$") and DocSettings:hasSidecarFile(home .. "/" .. f) then book, name = home .. "/" .. f, f end
    end
    H.check(book ~= nil, "a book with reading data to move: " .. tostring(name))
    H.app().go("library")
end)
H.step(S, function()
    H.check(H.find("Library") ~= nil, "breadcrumb starts at Library")
    H.shot("x01-explorer")
    H.tap("+ New")
end)
H.step(S, function() H.shot("x02-new-sheet"); H.tap("Folder") end)
H.step(S, function() H.typeKeys("Test folder") end)
H.step(S, function() H.tap("Create") end)
H.step(S, function()
    H.check(lfs.attributes(home .. "/Test folder", "mode") == "directory", "+ New > Folder makes the folder")
    H.check(H.find("Test folder") ~= nil, "and it shows in the explorer")
end)
-- move the book through its hold sheet and the picker
H.step(S, function() H.app().current().filter = "reading"; H.app().update() end)
H.step(S, function()
    local tile = H.findWhere(function(el) return el.on_hold ~= nil and el.children and el.children[1] and el.children[1].path == book end)
    H.check(tile ~= nil, "the book's tile is on the page")
    if tile then H.holdAt(tile.x + 10, tile.y + 10) end
end)
H.step(S, function() H.shot("x03-book-sheet"); H.tap("Move to") end)
H.step(S, function()
    H.check(H.app().current().params.pick ~= nil, "Move to opens the folder picker")
    H.shot("x04-picker")
    H.tap("Test folder")
end)
H.step(S, function()
    H.check(H.find("Test folder") ~= nil, "the picker went into the folder")
    H.tap("Move here")
end)
local moved
H.step(S, function()
    moved = home .. "/Test folder/" .. name
    H.check(exists(moved) and not exists(book), "the book moved into the folder")
    H.check(DocSettings:hasSidecarFile(moved), "its reading data went with it")
    H.check(inHistory(moved), "its history follows the new place")
    H.check(H.app().current().params.pick == nil, "back in the explorer")
    H.app().current().filter = "all"; H.app().update()
end)
-- open the folder in place, breadcrumbs and Back
H.step(S, function() H.tap("Test folder") end)
H.step(S, function()
    local s = H.app().current()
    H.check(#s.trail == 2, "the folder opened in place")
    H.shot("x05-in-folder")
    H.event("Back")
end)
H.step(S, function() H.check(#H.app().current().trail == 1, "Back goes up a folder") end)
-- rename the folder through its hold sheet
H.step(S, function() H.hold("Test folder") end)
H.step(S, function() H.shot("x06-folder-sheet"); H.tap("Rename") end)
H.step(S, function()
    for _i = 1, #"folder" do H.tap(nil, "backspace") end
    H.typeKeys("box")
end)
H.step(S, function() H.tap("Rename") end)
H.step(S, function()
    moved = home .. "/Test box/" .. name
    H.check(exists(moved) and lfs.attributes(home .. "/Test box", "mode") == "directory", "the folder is renamed, book inside")
end)
-- delete the book to the trash, then put it back
H.step(S, function()
    require("cyberui/actions").delete(moved)
end)
H.step(S, function() H.shot("x07-delete"); H.tap("Delete") end)
H.step(S, function()
    local Trash = require("cyberui/data/trash")
    H.check(not exists(moved) and Trash.count() == 1, "the book went to the trash")
    H.check(not inHistory(moved), "and out of the history while it waits")
    H.app().push("trash")
end)
H.step(S, function() H.shot("x08-trash"); H.tap(name) end)
H.step(S, function() H.tap("Put back") end)
H.step(S, function()
    H.check(exists(moved) and DocSettings:hasSidecarFile(moved), "put back where it was, with its reading data")
    H.check(inHistory(moved), "and in its history again")
    H.check(require("cyberui/data/trash").count() == 0, "the trash is empty again")
end)
-- the Ink Away tile: installed here, so it opens Ink Away
H.step(S, function() H.app().go("home") end)
H.step(S, function() H.tap("INK AWAY") end)
H.step(2, function()
    local UIManager = require("ui/uimanager")
    local above = {}
    for i = #UIManager._window_stack, 1, -1 do
        local w = UIManager._window_stack[i].widget
        if w.name == "cyberui" then break end
        above[#above + 1] = w
    end
    local inkaway = false
    for _i, w in ipairs(above) do if tostring(w.name):find("inkaway") then inkaway = true end end
    H.check(inkaway, "INK AWAY opens Ink Away over CyberUI")
    H.shot("x09-inkaway")
    for _i, w in ipairs(above) do UIManager:close(w) end
end)
-- as if it were not installed: the tile describes it and offers the install
local Addons, real_status
H.step(S, function()
    Addons = require("cyberui/apps/addons")
    real_status = Addons.status
    Addons.status = function() return "missing" end
    H.app().update()
end)
H.step(S, function()
    H.check(H.find("GET IT // FREE") ~= nil, "the tile says it can be got")
    H.tap("INK AWAY")
end)
H.step(S, function()
    H.check(H.find("Install") ~= nil, "without Ink Away the tile offers to install it")
    H.shot("x10-install-offer")
    H.tap("Not now")
    Addons.status = real_status
end)
H.step(S, function() H.check(H.cyberTop() and H.screen() == "home", "Not now leaves home as it was") end)
