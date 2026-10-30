-- Reader parking (System > Speed, on by default). Leaving a book for home
-- does not close it: home is raised over the live reader, which stays open
-- underneath, so going home takes one paint and opening the same book again
-- is a swap, with no load. The real close (KOReader writing the book's data
-- and rebuilding its file browser, a second or more on a device) runs later,
-- at a moment the reader is not using the screen:
--   * when a different book is opened (KOReader closes the old one inside the
--     wait the new book already has),
--   * after IDLE_S seconds of no touches while home is on top (checked every
--     EVERY_S seconds),
--   * when something needs the file browser that does not exist while parked
--     (KOReader's menu, the stock browser, a plugin's action).
-- Never under the screensaver or a dialog: only with home on top. Nothing is
-- kept across restarts: the state is the parked reader itself, checked against
-- KOReader's own reader instance each time.

local Device = require("device")
local Event = require("ui/event")
local Settings = require("cyberui/settings")
local UIManager = require("ui/uimanager")
local time = require("ui/time")

local Park = {}

Park.IDLE_S = 30    -- no touches for this long, then the book is closed for real
Park.EVERY_S = 10   -- how often that is checked

local parked              -- the ReaderUI kept open under home
local before              -- home's rotation when the book was opened from it
local last_input = 0      -- when the screen was last touched or a key pressed
local probe_task          -- the scheduled idle check

-- Is parking switched on?
function Park.enabled()
    return Settings.get("park_reader", true) == true
end

-- KOReader's reader, if one is open.
local function reader()
    local ok, ReaderUI = pcall(require, "apps/reader/readerui")
    return ok and ReaderUI.instance or nil
end

-- Is a book parked under home?
function Park.isParked()
    if not parked then return false end
    if reader() ~= parked then   -- it was closed some other way
        parked = nil
        return false
    end
    return true
end

-- The parked book's file, or nil.
function Park.file()
    return Park.isParked() and parked.document and parked.document.file or nil
end

-- The instance plugins' home-side parts live in: the file browser, or the
-- parked reader while there is no file browser.
function Park.ui()
    local fm = require("apps/filemanager/filemanager").instance
    if fm then return fm end
    return Park.isParked() and parked or nil
end

-- Note when something is touched, so the idle close waits for the reader to
-- stop using the screen (also dialogs and keys, through UIManager's own
-- event delivery).
local stamped = false
local function installStamp()
    if stamped then return end
    stamped = true
    local original = UIManager.sendEvent
    UIManager.sendEvent = function(self, event, ...)
        local h = type(event) == "table" and event.handler
        if h == "onGesture" or h == "onKeyPress" or h == "onKeyRepeat" then last_input = time.now() end
        return original(self, event, ...)
    end
end

-- Remember home's rotation as a book is opened from it: a book read turned
-- sideways is not parked, so home comes back the right way up.
function Park.noteOpen()
    before = Device.screen:getRotationMode()
end

-- Stop the idle check.
local function cancel()
    if probe_task then UIManager:unschedule(probe_task); probe_task = nil end
end

-- Close the parked book for real, now (blocking). Home stays on top.
function Park.finish()
    if not Park.isParked() then return false end
    local ui = parked
    parked = nil
    cancel()
    require("cyberui/app").realClose(ui, ui.document and ui.document.file)
    return true
end

-- The idle check: once nothing has been touched for IDLE_S and home is
-- the top window, close the book; else look again.
local function check()
    probe_task = nil
    if not Park.isParked() then return end
    local idle = time.to_s(time.since(last_input))
    if idle >= Park.IDLE_S and require("cyberui/app").onTop() then
        Park.finish()
        return
    end
    probe_task = check
    UIManager:scheduleIn(Park.EVERY_S, probe_task)
end

-- Park the open book (`ui`, KOReader's reader) instead of closing it: the
-- chrome is closed as KOReader does when it switches books, the book's
-- progress and reading time are saved, and the reading clock is paused.
-- False when it cannot be done (the caller then closes the book as usual).
function Park.park(ui)
    if not (Park.enabled() and ui and ui.document) then return false end
    if before == nil or Device.screen:getRotationMode() ~= before then return false end
    ui:handleEvent(Event:new("CloseReaderMenu"))
    ui:handleEvent(Event:new("CloseConfigMenu"))
    if ui.highlight and ui.highlight.onClose then pcall(ui.highlight.onClose, ui.highlight) end
    ui:saveSettings()
    pcall(function()
        require("ui/widget/booklist").setBookInfoCacheProperty(ui.document.file, "percent_finished",
            ui.doc_settings:readSetting("percent_finished"))
    end)
    -- the page being read counts up to now and the numbers reach the database
    -- (home shows them); the clock then stops until the book is read again
    local stats = ui.statistics
    if stats then
        pcall(function()
            stats:onPageUpdate(false)
            stats:insertDB()
            stats:onReadingPaused()
        end)
    end
    parked = ui
    installStamp()
    last_input = time.now()
    cancel()
    probe_task = check
    UIManager:scheduleIn(Park.EVERY_S, probe_task)
    return true
end

-- Bring the parked book back to the front, as it was. `after_open(ui)` runs
-- at once (the book is already open). False when `file` is not the parked book.
function Park.unpark(file, after_open)
    if Park.file() ~= file then return false end
    local ui = parked
    parked = nil
    cancel()
    local stack = UIManager._window_stack
    local index
    for i, entry in ipairs(stack) do
        if entry.widget == ui then index = i; break end
    end
    if not index then return false end
    if index ~= #stack then table.insert(stack, table.remove(stack, index)) end
    if ui.statistics then pcall(ui.statistics.onResume, ui.statistics) end
    UIManager:setDirty(ui, "full")
    if after_open then pcall(after_open, ui) end
    return true
end

return Park
