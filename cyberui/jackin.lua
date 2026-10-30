-- The jack-in card: what the screen shows while a book opens, in place of the
-- small "Opening file" message KOReader would draw over the screen. The card
-- is the worn style of the shop (see cyberui/styles/jackins.lua); this file
-- keeps the card out of the way of KOReader's own message.

local Settings = require("cyberui/settings")
local Shop = require("cyberui/data/shop")
local UIManager = require("ui/uimanager")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local lfs = require("libs/libkoreader-lfs")

local JackIn = {}

-- Is the card on, and is there a file to open?
function JackIn.wanted(path)
    return Settings.get("jack_in", true) and lfs.attributes(path, "mode") == "file"
end

-- The card for a book in the worn style: a floating panel, shown over whatever
-- screen the book was opened from.
function JackIn.card(path)
    return Shop.worn("jackin").build(path)
end

-- Run show() (the call that opens the book) with KOReader's own "Opening file"
-- message kept off the screen, so the card stays alone. Anything else shown on
-- the way (a question about restoring the book's notes) is let through.
function JackIn.silenced(path, show)
    local abbreviated = filemanagerutil.abbreviate(path)
    local original = UIManager.show
    local function quiet(self, widget, ...)
        if widget and widget.timeout == 0 and type(widget.text) == "string" and widget.text:find(abbreviated, 1, true) then
            return
        end
        return original(self, widget, ...)
    end
    UIManager.show = quiet
    local ok, err = pcall(show)
    if UIManager.show == quiet then UIManager.show = original end
    if not ok then error(err, 0) end
end

return JackIn
