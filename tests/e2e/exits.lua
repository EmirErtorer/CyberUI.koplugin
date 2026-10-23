-- Every way the reader leaves a book must land on CyberUI home: the Home
-- action, the reader menu's file browser tab and the end-of-book dialog's
-- file browser choice; also when CyberUI was opened from the menu rather than
-- set as the start screen.
local H = ...
local S = 0.8
local book

-- Open the book, run `leave` inside the reader, then check home is back.
local function trip(label, leave)
    H.step(S, function() H.app().openBook(book) end)
    H.step(2.5, function()
        local ui = require("apps/reader/readerui").instance
        H.check(ui ~= nil, label .. ": book opened")
        if ui then leave(ui) end
    end)
    H.step(2.5, function()
        H.check(H.cyberTop() and H.screen() == "home",
            label .. ": back on CyberUI home (top " .. tostring(H.top() and H.top().name) .. ")")
    end)
end

H.step(1, function() book = require("cyberui/data/library").all()[1] end)
trip("Home action", function(ui) ui:handleEvent(require("ui/event"):new("Home")) end)
trip("reader menu file browser", function(ui)
    -- what the menu's file browser tab does
    local file = ui.document.file
    ui:onClose()
    ui:showFileManager(file)
end)
trip("end of book dialog", function(ui) ui.status:openFileBrowser() end)
-- CyberUI opened from the menu while the start screen is the file browser,
-- and the session flag gone as after a restart
H.step(S, function() G_reader_settings:saveSetting("start_with", "filemanager") end)
trip("not the start screen, Home action", function(ui) ui:handleEvent(require("ui/event"):new("Home")) end)
-- after leaving for the file browser on purpose, a closed book goes back there
H.step(S, function() H.app().fileBrowser() end)
H.step(S, function()
    require("apps/reader/readerui"):showReader(book)
end)
H.step(2.5, function() require("apps/reader/readerui").instance:handleEvent(require("ui/event"):new("Home")) end)
H.step(2.5, function()
    H.check(not H.cyberTop(), "chose the file browser: a closed book returns to it")
    H.event("CyberUIHome")
end)
H.step(S, function() H.check(H.cyberTop(), "CyberUI home action works from the file browser") end)
H.step(S, function() G_reader_settings:saveSetting("start_with", "cyberui") end)
