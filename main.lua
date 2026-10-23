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

local booted = false   -- the boot takeover runs once per session

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
    self.ui.menu:registerToMainMenu(self)
    self:onDispatcherRegisterActions()
end

-- The gesture and hotkey action "CyberUI home".
function CyberUI:onDispatcherRegisterActions()
    Dispatcher:registerAction("cyberui_home", {
        category = "none", event = "CyberUIHome", title = _("CyberUI home"), general = true,
    })
end

-- The file browser is being shown: open CyberUI over it at boot, or bring it
-- back after a book was closed.
function CyberUI:onShow()
    if self.ui.document then return end
    local App = require("cyberui/app")
    if not booted then
        booted = true
        if CyberUI.isHome() then App.open() end
    elseif App.isOpen() or (CyberUI.isHome() and not App.leftForFiles()) then
        App.raise()
    end
end

-- A book was closed in the reader: its details changed.
function CyberUI:onCloseDocument()
    local doc = self.ui and self.ui.document
    require("cyberui/app").bookClosed(doc and doc.file)
end

-- Open CyberUI; from the reader this closes the book first.
function CyberUI:onCyberUIHome()
    local App = require("cyberui/app")
    if self.ui.document then
        App.returnHome()
        self.ui:onClose()
        self.ui:showFileManager()
    else
        App.open()
    end
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
