-- The skin registry: how KOReader's own widgets are drawn in CyberUI's style.
-- A skin says which widgets it takes (`matches`) and what to draw for one
-- (`present`, which returns the options of a Popup). KOReader still builds the
-- widget and everything it does stays KOReader's: the original is shown as
-- usual, in the same place in KOReader's window stack, but draws nothing and
-- hears nothing; the Popup is shown right above it, so whatever KOReader puts
-- over or under the widget stays so. Closing either closes both. When a skin
-- fails, the widget is shown the way KOReader built it.
--
-- Skins register themselves (`Core.register`) and are switched on together
-- with `Core.install()`; a new one needs no change here.

local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local Settings = require("cyberui/settings")
local logger = require("logger")


local Core = { skins = {} }

-- Is the styled look wanted? The main switch (System > Dialogs) and, for a skin in a group, the
-- group's own. Asked each time a widget is shown, so a switch works at once.
function Core.wanted(skin_name)
    if not Settings.get("styled_widgets", true) then return false end
    local Groups = require("cyberui/skin/groups")
    local group = skin_name and Groups.of(skin_name)
    return not group or Settings.get(Groups.key(group), true)
end

-- Add a skin: { name, matches(widget) -> bool, present(widget) -> Popup options or nil,
-- install() (optional: patches KOReader's classes once) }.
function Core.register(skin)
    for i, s in ipairs(Core.skins) do
        if s.name == skin.name then Core.skins[i] = skin; return end
    end
    Core.skins[#Core.skins + 1] = skin
end

-- Run fn(...) with KOReader's refresh requests doing nothing (the widget's own
-- places and sizes are not the skin's): its timers and callbacks still run.
local function quietly(fn, ...)
    local set_dirty = UIManager.setDirty
    UIManager.setDirty = function() end
    local ok, result = pcall(fn, ...)
    UIManager.setDirty = set_dirty
    if not ok then error(result, 0) end
    return result
end
Core.quietly = quietly

-- Make a widget draw nothing and hear nothing, but stay where it is in the
-- window stack so the calls that close it or look at it still work.
function Core.silence(widget)
    widget.dimen = Geom:new({ x = 0, y = 0, w = 0, h = 0 })
    widget.paintTo = function() end
    widget.ges_events, widget.key_events = {}, {}
    for _i, method in ipairs({ "onShow", "onCloseWidget" }) do
        local stock = widget[method]
        if type(stock) == "function" then
            widget[method] = function(self, ...) return quietly(stock, self, ...) end
        end
    end
end

-- Close a widget the way KOReader's own dismissing does (a tap outside, Back).
function Core.dismiss(widget)
    if widget.dismissable == false then return end
    if type(widget.onClose) == "function" then widget:onClose() else UIManager:close(widget) end
end

-- The Popup showing a widget, or nil.
function Core.popupOf(widget)
    return widget._cyber_popup
end

-- Draw another element in place of the widget's current one.
function Core.redraw(widget, element)
    local popup = widget._cyber_popup
    if popup then popup:redraw(element) end
end

-- Where a floating popup sits by default: the middle of the screen.
function Core.centered(el)
    local Screen = require("device").screen
    return math.floor((Screen:getWidth() - el.w) / 2), math.floor((Screen:getHeight() - el.h) / 2)
end

-- Show `widget` as usual with its Popup right above it.
local function twin(real_show, widget, popup, opts, ...)
    Core.silence(widget)
    widget._cyberui_skinned = true
    widget._cyber_popup = popup
    local stock_close = widget.onCloseWidget
    widget.onCloseWidget = function(self, ...)
        local p = self._cyber_popup
        self._cyber_popup = nil
        self._cyberui_skinned = nil
        if p then UIManager:close(p, opts.close_refresh or (require("device").screen:isColorEnabled() and "partial" or "ui"), p:box()) end
        if opts.on_close then opts.on_close(self) end
        if type(stock_close) == "function" then return stock_close(self, ...) end
    end
    local result = real_show(UIManager, widget, ...)
    popup:open()
    if opts.on_shown then opts.on_shown(widget, popup) end
    return result
end

-- Is a CyberUI popup (one that takes touches) open? KOReader keeps modal windows above every window
-- that is not modal, so a window shown now that is not modal would land under it.
local function popupOpen()
    for _i, w in ipairs(UIManager._window_stack or {}) do
        local widget = w.widget
        if widget and widget.name == "cyberui_popup" and not widget.passive then return true end
    end
    return false
end

-- Show a window KOReader's way: a window no skin took (one with extra parts, or a skin that is
-- switched off) still has to appear in front of the popup of the list it was opened from.
local APPS = { ReaderUI = true, FileManager = true, filemanager = true, cyberui = true }   -- (the app windows are never raised)
local function plainly(real_show, um, widget, ...)
    if not widget.modal and not widget.toast and not APPS[widget.name] and popupOpen() then widget.modal = true end
    return real_show(um, widget, ...)
end

local installed

-- Turn the skins on: from now on a widget a skin takes is shown through it.
function Core.install()
    if installed then return end
    installed = true
    for _i, skin in ipairs(Core.skins) do
        if skin.install then
            local ok, err = pcall(skin.install)
            if not ok then logger.warn("CyberUI skin " .. skin.name .. " (install):", err) end
        end
    end
    local real_show = UIManager.show
    UIManager.show = function(um, widget, ...)
        if type(widget) ~= "table" or widget._cyberui_skinned or widget.name == "cyberui_popup" or not Core.wanted() then
            return real_show(um, widget, ...)
        end
        for _i, skin in ipairs(Core.skins) do
            -- ask the skin and build its popup before touching the widget: any failure shows KOReader's own
            local ok, popup, opts = pcall(function()
                if not skin.matches(widget) then return nil end
                -- a skin that is switched off still owns its widget: it shows as KOReader made it, not in another skin
                if not Core.wanted(skin.name) then return false end
                local o = skin.present(widget)
                return o and require("cyberui/popup"):new(o), o
            end)
            if not ok then
                logger.warn("CyberUI skin " .. skin.name .. ":", popup)
            elseif popup == false then
                return plainly(real_show, um, widget, ...)
            elseif popup then
                return twin(real_show, widget, popup, opts, ...)
            end
        end
        return plainly(real_show, um, widget, ...)
    end
end

return Core
