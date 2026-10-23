-- Deeper flows in the emulator: changing a book's status, collections,
-- custom colours, every settings control, the KOReader menu, folder
-- browsing, night mode, rotation and gesture passthrough; also logs timings.
local H = ...
local S = 0.8
local UIManager = require("ui/uimanager")

-- The first element that has field `key`.
local function findBy(key) return H.findWhere(function(el) return el[key] ~= nil end) end
-- The stepper's minus button (a "back" icon in a segment, not the header's).
local function stepperMinus() return H.findWhere(function(el) return el.icon == "back" and el.variant == "seg" end) end
local function perf() local p = require("cyberui/perf").last; return string.format("build %.1f ms, paint %.1f ms", p.build or -1, p.paint or -1) end
-- A book that already has reading data, so changing its status adds no new files.
local BOOK
H.step(1, function()
    for _i, item in ipairs(require("readhistory").hist) do
        if item.file and require("docsettings"):hasSidecarFile(item.file) and item.file:match("%.pdf$") then BOOK = item.file break end
    end
    H.check(BOOK ~= nil, "found a book with reading data: " .. tostring(BOOK))
    H.say("timing at boot: " .. perf())
end)

-- status: mark done and back
H.step(S, function() H.app().push("dossier", { path = BOOK }) end)
H.step(S, function()
    local before = require("cyberui/data/books").state(BOOK).status
    H.say("status before: " .. tostring(before))
    H.tap(before == "complete" and "MARK READING" or "MARK DONE")
end)
H.step(S, function()
    local st = require("cyberui/data/books").state(BOOK).status
    H.check(st == "complete" or st == "reading", "status changed to " .. tostring(st))
    H.shot("f01-status")
    H.tap(st == "complete" and "MARK READING" or "MARK DONE")
end)
H.step(S, function() H.say("status after restore: " .. tostring(require("cyberui/data/books").state(BOOK).status)) end)

-- collections: toggle Favorites from the picker, then make a new collection
H.step(S, function() H.tap("COLLECTION +") end)
H.step(S, function() H.tap("Favorites") end)
H.step(S, function()
    H.check(require("cyberui/data/collections").has(BOOK, "favorites"), "book added to Favorites")
    H.check(H.find("Collections") ~= nil, "picker reopens to show the tick")
    H.shot("f02-collect-ticked")
    H.tap("Favorites")
end)
H.step(S, function()
    H.check(not require("cyberui/data/collections").has(BOOK, "favorites"), "book taken out of Favorites")
    H.tap("New collection")
end)
H.step(S + 0.6, function()
    local t = H.top()
    H.check(t and t.setInputText ~= nil, "new collection asks for a name")
    t:setInputText("Cyber test")
    for _i, row in ipairs(t.buttons or {}) do for _j, b in ipairs(row) do if b.is_enter_default then b.callback() end end end
end)
H.step(S, function()
    H.check(require("cyberui/data/collections").has(BOOK, "Cyber test"), "book is in the new collection")
    H.shot("f03-new-collection")
end)
H.step(S, function() H.tap("SHOW FOLDER") end)
H.step(S, function()
    local s = H.app().current()
    H.check(s.id == "library" and s.params.dir ~= nil, "show folder opens the book's folder")
    H.shot("f04-folder")
end)

-- settings: custom colours, every control
H.step(S, function() H.app().go("settings") end)
H.step(S, function() H.tap("Custom") end)
H.step(S, function() H.check(H.find("Accent") ~= nil, "custom offers accent pickers"); H.tap("Pick") end)
H.step(S, function()
    H.shot("f05-picker")
    local cell = H.findWhere(function(el) return el.on_tap and el.child and el.child.colors end)
    H.check(cell ~= nil, "picker shows colour cells")
    if cell then H.tapAt(cell.x + cell.w / 2, cell.y + cell.h / 2) end
end)
H.step(S, function()
    H.check(require("cyberui/settings").get("custom_accent") ~= nil, "custom accent saved")
    H.shot("f06-custom")
end)
H.step(S, function() local t = findBy("on") ; H.check(t ~= nil, "cover toggle there"); if t then H.tapAt(t.x + t.w / 2, t.y + t.h / 2) end end)
H.step(S, function() H.check(require("cyberui/settings").get("cover_images") == true, "cover images on"); H.shot("f07-covers-on") end)
H.step(S, function() H.app().go("library") end)
H.step(S + 1, function() H.shot("f08-library-covers"); H.say("library with covers: " .. perf()) end)
H.step(S, function() H.app().go("settings") end)
H.step(S, function() local t = findBy("on"); if t then H.tapAt(t.x + t.w / 2, t.y + t.h / 2) end end)
H.step(S, function() H.check(require("cyberui/settings").get("cover_images") == false, "cover images off again") end)
H.step(S, function() H.tap("Mono") end)
H.step(S, function() H.tap("Home") end)
H.step(S, function()
    local t = findBy("on")
    local was = G_reader_settings:readSetting("start_with")
    if t then H.tapAt(t.x + t.w / 2, t.y + t.h / 2) end
    H.say("start_with was " .. tostring(was))
end)
H.step(S, function()
    H.check(G_reader_settings:readSetting("start_with") == "filemanager", "start with CyberUI switched off")
    local t = findBy("on")
    if t then H.tapAt(t.x + t.w / 2, t.y + t.h / 2) end
end)
H.step(S, function()
    H.check(G_reader_settings:readSetting("start_with") == "cyberui", "and on again")
    H.tap(nil, "forward")
end)
H.step(S, function() H.check(require("cyberui/settings").get("daily_goal") == 35, "daily goal stepper adds 5"); H.shot("f09-home-settings") end)
H.step(S, function() local m = stepperMinus(); if m then H.tapAt(m.x + m.w / 2, m.y + m.h / 2) end end)
H.step(S, function() H.check(require("cyberui/settings").get("daily_goal") == 30, "and takes 5 off") end)
H.step(S, function() H.tap("Speed") end)
H.step(S, function() H.tap(nil, "forward") end)
H.step(S, function() H.check(require("cyberui/settings").get("full_refresh_every") == 7, "refresh stepper") end)

-- KOReader menu from a swipe down at the top
H.step(S, function() H.swipe("south", 300, 20) end)
H.step(S, function()
    local t = H.top()
    H.check(t and not H.cyberTop(), "swipe down from the top opens KOReader's menu")
    H.shot("f10-komenu")
    require("apps/filemanager/filemanager").instance.menu:onCloseFileManagerMenu()
end)
H.step(S, function() H.check(H.cyberTop(), "closing the menu shows CyberUI again") end)

-- night mode and rotation
H.step(S, function() H.event("ToggleNightMode") end)
H.step(S, function()
    H.check(require("cyberui/theme").nightMode(), "night mode on")
    H.shot("f11-night")
    H.event("ToggleNightMode")
end)
H.step(S, function()
    local FileManager = require("apps/filemanager/filemanager")
    FileManager.instance:onSetRotationMode(1)
end)
H.step(S + 0.5, function()
    local Screen = require("device").screen
    H.check(Screen:getWidth() > Screen:getHeight(), "rotated to landscape")
    H.check(H.cyberTop(), "CyberUI still on top")
    H.shot("f12-landscape-settings")
    H.app().go("home")
end)
H.step(S, function() H.shot("f13-landscape-home"); H.say("landscape home: " .. perf()) end)
H.step(S, function() H.app().go("library") end)
H.step(S, function() H.shot("f14-landscape-library") end)
H.step(S, function() require("apps/filemanager/filemanager").instance:onSetRotationMode(0) end)
H.step(S + 0.5, function()
    local Screen = require("device").screen
    H.check(Screen:getWidth() < Screen:getHeight(), "back to portrait")
    H.app().go("home")
end)
H.step(S, function() H.say("portrait home: " .. perf()); H.shot("f15-home-end") end)
