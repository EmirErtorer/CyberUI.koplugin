-- CyberUI plugin entry: adds "CyberUI" to KOReader's Start with choices,
-- opens CyberUI at boot when chosen, brings it back when a book closes, and
-- offers menu entries and a gesture action to open it.

-- CyberUI's modules load from compiled copies once made (see cyberui/bccache.lua).
do
    local root = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/main%.lua$")
    local ok, BcCache = pcall(require, "cyberui/bccache")
    if root and ok then pcall(BcCache.install, root, require("datastorage"):getDataDir() .. "/cache/cyberui-bytecode") end
end

local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("cyberui/gettext")
local T = require("ffi/util").template

local START_WITH = "cyberui"

-- The start is over: CyberUI's modules it loaded are kept together for the
-- next one (see cyberui/bccache.lua).
local function packStart()
    local BcCache = _G.package.loaded["cyberui/bccache"]
    if BcCache then pcall(BcCache.packStart) end
end

-- (KOReader closing within seconds of its start packs it then)
do
    local UIManager = require("ui/uimanager")
    if not UIManager._cyberui_packs_on_quit then
        UIManager._cyberui_packs_on_quit = true
        local quit = UIManager.quit
        UIManager.quit = function(...)
            packStart()
            return quit(...)
        end
    end
end

-- Switch LuaJIT's compiler back on (see below).
local function resumeJit()
    if jit then jit.on() end
end

-- A start straight to CyberUI home draws its first screen with LuaJIT's
-- compiler paused: it compiles each loop the first time it runs often, and at
-- start that costs more than running the few loops one screen needs as they
-- are. The compiler is back as soon as home is up, and after a second at the
-- latest whatever happens.
if jit and G_reader_settings and G_reader_settings:readSetting("start_with") == START_WITH then
    jit.off()
    require("ui/uimanager"):scheduleIn(1, resumeJit)
end

local CyberUI = WidgetContainer:extend({
    name = "CyberUI",
    is_doc_only = false,
})

local started = os.time()  -- when KOReader started (this file loads at start)
local booted = false        -- the boot takeover runs once per session
local book_closed = false   -- a book closed since the file browser was last shown

-- CyberUI's own modules are required inside the handlers, not at the top, so
-- KOReader's start loads none of them unless CyberUI is actually used.

-- Add "CyberUI" to the Start with menu (once, on KOReader's own class).
local function registerStartWith()
    local ok, FMMenu = pcall(require, "apps/filemanager/filemanagermenu")
    if not ok or FMMenu._cyberui_start_with or type(FMMenu.getStartWithMenuTable) ~= "function" then return end
    FMMenu._cyberui_start_with = true
    local orig = FMMenu.getStartWithMenuTable
    FMMenu.getStartWithMenuTable = function(menu)
        local t = orig(menu)
        if type(t) ~= "table" or type(t.sub_item_table) ~= "table" then return t end
        table.insert(t.sub_item_table, {
            text = _("CyberUI"),
            radio = true,
            checked_func = function() return G_reader_settings:readSetting("start_with") == START_WITH end,
            callback = function()
                G_reader_settings:saveSetting("start_with", START_WITH)
                require("cyberui/twin").claim()   -- (with its twin installed too, this one is in charge)
            end,
        })
        local orig_text = t.text_func
        t.text_func = function()
            if G_reader_settings:readSetting("start_with") == START_WITH then return T(_("Start with: %1"), _("CyberUI")) end
            return orig_text and orig_text() or ""
        end
        return t
    end
end

-- Is CyberUI the chosen home screen?
function CyberUI.isHome()
    return G_reader_settings:readSetting("start_with") == START_WITH
end

-- Will home cover the file browser being built now? At the first start when
-- CyberUI is the start screen, and when a book closes back to home (the same
-- choice onShow makes).
local function homeWillCover()
    if not require("cyberui/twin").mine() then return false end
    if book_closed then
        local App = _G.package.loaded["cyberui/app"]
        return (App and App.isOpen()) or require("cyberui/settings").get("home_active", false) or CyberUI.isHome()
    end
    return not booted and CyberUI.isHome()
end

-- Hook into KOReader when the file browser or the reader starts.
function CyberUI:init()
    registerStartWith()
    if not self.ui.document then
        local LazyFM = require("cyberui/lazyfm")
        LazyFM.install()
        LazyFM.arm(homeWillCover())
    end
    require("cyberui/data/sysinfo").started = started
    -- (the sleep screen's hook loads KOReader's sleep screen code: not while starting)
    require("ui/uimanager"):scheduleIn(2, function() require("cyberui/sleep").install() end)
    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()
    require("cyberui/skin/all").install(self.ui.document ~= nil)
    if self.ui.document then
        self:styleReaderMenu()
    end
end

-- Inside a book, the drop-down menu is CyberUI's too (unless the reader
-- chose KOReader's own in System > Home).
function CyberUI:styleReaderMenu()
    local km = self.ui.menu
    local show = km.onShowMenu
    km.onShowMenu = function(menu, tab_index, do_not_show)
        if do_not_show or not require("cyberui/settings").get("styled_menu", true) or not require("cyberui/twin").mine() then
            return show(menu, tab_index, do_not_show)
        end
        local Menu = require("cyberui/menu")
        local ok, err = pcall(function() if not Menu.current() then Menu.open({ km = menu, reader = true }) end end)
        if not ok then
            require("logger").warn("CyberUI menu:", err)
            return show(menu, tab_index, do_not_show)
        end
        return true
    end
end

-- The gesture and hotkey action "CyberUI home".
function CyberUI:onDispatcherRegisterActions()
    Dispatcher:registerAction("cyberui_home", {
        category = "none", event = "CyberUIHome", title = _("CyberUI home"), general = true,
    })
end

-- The file browser is being shown. After a book closes, CyberUI comes back
-- when it is the reader's home; at a fresh start it opens when it is the
-- chosen start screen.
function CyberUI:onShow()
    if self.ui.document then return end
    local App = require("cyberui/app")
    local LazyFM = require("cyberui/lazyfm")
    local from_book = book_closed
    book_closed = false
    local first = not booted
    booted = true
    LazyFM.arm(false)
    -- (with its twin installed too, only the one in charge comes back or starts)
    if require("cyberui/twin").mine() then
        if from_book then
            if App.isOpen() or App.isHome() or CyberUI.isHome() then App.raise() end
        elseif first and CyberUI.isHome() then
            App.open()
        end
    end
    if first then
        require("ui/uimanager"):tickAfterNext(resumeJit)
        require("ui/uimanager"):scheduleIn(3, packStart)
    end
    -- the browser left without its list is on the screen after all
    if not App.isOpen() then LazyFM.fill() end
end

-- The book is ready: hide CyberUI's window under it (without loading CyberUI when
-- it is unused), and if the book is a gig taken, start following what is read.
function CyberUI:onReaderReady()
    require("ui/uimanager"):scheduleIn(3, packStart)   -- (a start straight into a book)
    local App = _G.package.loaded["cyberui/app"]
    if App then App.bookOpened() end
    local Gigs = require("cyberui/data/gigs")
    local doc = self.ui.document
    Gigs.follow(doc and doc.file)
    -- a book that pays is measured once, a moment after it shows (never on a page turn)
    if doc and Gigs.needsMeasure() then
        require("ui/uimanager"):scheduleIn(Gigs.MEASURE_AFTER, function()
            local ReaderUI = require("apps/reader/readerui")
            if ReaderUI.instance and ReaderUI.instance.document == doc then Gigs.measure(doc) end
        end)
    end
end

-- A page was shown: it counts toward the gig's payouts.
function CyberUI:onPageUpdate(page)
    local doc = self.ui.document
    -- (after a change of font KOReader keeps the old page count until the book is laid out again)
    local unsettled = self.ui.rolling ~= nil and self.ui.rolling.rendering_state ~= nil
    if type(page) == "number" and doc then require("cyberui/data/gigs").page(page, doc:getPageCount(), unsettled) end
end

-- A charger was plugged in or out: the status bar asks again.
function CyberUI:onCharging()
    require("cyberui/data/device").forgetCharging()
end
CyberUI.onNotCharging = CyberUI.onCharging

-- The device sleeps: pay what has been read so the sleep cannot lose it.
function CyberUI:onSuspend()
    require("cyberui/sleep").install()
    require("cyberui/data/gigs").settle()
end

-- A book was closed in the reader: its details changed, and the next file
-- browser shown is a return from it.
function CyberUI:onCloseDocument()
    book_closed = true
    local doc = self.ui and self.ui.document
    require("cyberui/app").bookClosed(doc and doc.file)
end

-- A book's details or cover were changed in KOReader (its book information
-- window): what CyberUI keeps of it is read again.
function CyberUI:onInvalidateMetadataCache(file)
    if not file then return end
    local App = _G.package.loaded["cyberui/app"]
    if App then
        require("cyberui/data/books").forget(file)
        require("cyberui/data/covers").forget(file)
    end
end

-- Close CyberUI on Exit too, or a window is left and KOReader never quits.
function CyberUI:onExit()
    require("cyberui/app").close(true)
end

-- Open CyberUI; from the reader, home shows at once and the book closes
-- just after.
function CyberUI:onCyberUIHome()
    require("logger").info("CyberUI: home action", self.ui.document and "from a book" or "from the file browser")
    local App = require("cyberui/app")
    if self.ui.document then
        App.homeFromBook(self.ui)
    else
        App.open()
    end
    return true
end

-- KOReader's own Home action in the reader takes the same fast way when
-- CyberUI is the reader's home (plugins hear it before the reader does).
function CyberUI:onHome()
    if not self.ui.document then return false end
    if not require("cyberui/twin").mine() then return false end
    local App = require("cyberui/app")
    if not (App.isHome() or CyberUI.isHome()) then return false end
    App.homeFromBook(self.ui)
    return true
end

-- Menu entries in the file browser and the reader.
function CyberUI:addToMainMenu(menu_items)
    menu_items.cyberui = {
        text = self.ui.document and _("CyberUI home") or _("CyberUI"),
        sorting_hint = "tools",
        callback = function() self:onCyberUIHome() end,
    }
    -- in a book, Ink Away's annotation mode is one tap away (when it is running)
    if self.ui.document and require("cyberui/apps/addons").loadedIn(self.ui, require("cyberui/apps/inkaway")) then
        menu_items.cyberui_annotate = {
            text = _("Annotate this book"),
            sorting_hint = "tools",
            callback = function() self.ui:handleEvent(require("ui/event"):new("InkAwayAnnotate")) end,
        }
    end
end

return CyberUI
