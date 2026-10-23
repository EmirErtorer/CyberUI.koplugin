-- CyberUI plugin entry: adds "CyberUI" to KOReader's Start with choices,
-- opens CyberUI at boot when chosen, brings it back when a book closes, and
-- offers menu entries and a gesture action to open it.

local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local T = require("ffi/util").template

local START_WITH = "cyberui"

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
            callback = function() G_reader_settings:saveSetting("start_with", START_WITH) end,
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

-- Hook into KOReader when the file browser or the reader starts.
function CyberUI:init()
    registerStartWith()
    require("cyberui/data/sysinfo").started = started
    require("cyberui/sleep").install()
    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()
    if self.ui.document then self:styleReaderMenu() end
end

-- Inside a book, the drop-down menu is CyberUI's too (unless the reader
-- chose KOReader's own in System > Home).
function CyberUI:styleReaderMenu()
    local km = self.ui.menu
    local show = km.onShowMenu
    km.onShowMenu = function(menu, tab_index, do_not_show)
        if do_not_show or not require("cyberui/settings").get("styled_menu", true) then
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
    local from_book = book_closed
    book_closed = false
    local first = not booted
    booted = true
    if from_book then
        if App.isOpen() or App.isHome() or CyberUI.isHome() then App.raise() end
    elseif first and CyberUI.isHome() then
        App.open()
    end
end

-- A book was closed in the reader: its details changed, and the next file
-- browser shown is a return from it.
function CyberUI:onCloseDocument()
    book_closed = true
    local doc = self.ui and self.ui.document
    require("cyberui/app").bookClosed(doc and doc.file)
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
end

return CyberUI
