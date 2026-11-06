-- KOReader's own button dialogs, drawn in CyberUI's style: the highlight menu
-- (what appears after selecting text) and the one for changing a saved
-- highlight. KOReader builds them and everything they do stays KOReader's; this
-- only takes the dialog just made, shows its buttons as CyberUI's docked sheet
-- and keeps the original (unseen, unpainted) in KOReader's window stack, so the
-- calls that close or look at it still work and closing either closes both.

local Device = require("device")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local Settings = require("cyberui/settings")

local Screen = Device.screen

local Skin = {}

-- Is the styled look wanted? (System > Home, the same switch as the menu's.)
function Skin.wanted()
    return Settings.get("styled_menu", true)
end

-- Where a floating dialog sits: centred across, and down the screen where
-- KOReader's own dialog would be (its `anchor`: the middle by default, near the
-- top or bottom, or by the selected text). A dialog is a list of rows and the
-- anchor asks for its height, which the unpainted original cannot give.
local function placer(dialog)
    return function(el)
        local x = math.floor((Screen:getWidth() - el.w) / 2)
        local y = math.floor((Screen:getHeight() - el.h) / 2)
        if type(dialog.anchor) == "function" then
            dialog.getContentSize = function() return { w = el.w, h = el.h } end
            local ok, anchor, pop_down = pcall(dialog.anchor)
            if ok and type(anchor) == "table" and anchor.y then
                y = pop_down and anchor.y or anchor.y - el.h
                y = math.max(0, math.min(y, Screen:getHeight() - el.h))
            end
        end
        return x, y
    end
end

-- Show `dialog` (a KOReader ButtonDialog just built) in CyberUI's style.
function Skin.present(dialog)
    local Dialog = require("cyberui/ui/dialog")
    local Popup = require("cyberui/popup")
    -- the original stays shown so it can be closed, but draws nothing and hears nothing
    dialog.dimen = Geom:new({ x = 0, y = 0, w = 0, h = 0 })
    dialog.paintTo = function() end
    dialog.onShow = function() end
    dialog.ges_events, dialog.key_events = {}, {}
    local popup
    local function dismiss()
        if dialog.tap_close_callback then dialog.tap_close_callback() end
        UIManager:close(dialog)
    end
    dialog.onCloseWidget = function()
        if popup then
            local p = popup
            popup = nil
            UIManager:close(p, "ui", p:box())
        end
    end
    popup = Popup:new({
        element = Dialog.rows({ rows = dialog.buttons }, Screen:getWidth()),
        place = placer(dialog),
        on_outside = dismiss,
    })
    UIManager:show(dialog, "ui", dialog.dimen)
    popup:open()
end

-- Is this one of the dialogs to restyle? (A built ButtonDialog: it has its rows.)
local function isButtonDialog(widget)
    return type(widget) == "table" and type(widget.buttons) == "table" and widget.buttontable ~= nil
end

-- Wrap `host[method]` so a button dialog it shows is drawn by CyberUI instead.
-- Anything going wrong shows KOReader's own, as it would have been.
local function restyle(host, method)
    local orig = host[method]
    if type(orig) ~= "function" then return end
    host[method] = function(self, ...)
        if not Skin.wanted() then return orig(self, ...) end
        local real_show = UIManager.show
        local held
        UIManager.show = function(um, widget, ...)
            if not held and isButtonDialog(widget) then
                held = { widget, ... }
                return
            end
            return real_show(um, widget, ...)
        end
        local ok, result = pcall(orig, self, ...)
        UIManager.show = real_show
        if not ok then error(result, 0) end
        if held then
            local shown, err = pcall(Skin.present, held[1])
            if not shown then
                require("logger").warn("CyberUI dialog:", err)
                real_show(UIManager, unpack(held))
            end
        end
        return result
    end
end

-- Style the highlight dialogs of a reader (`ui` is the ReaderUI).
function Skin.install(ui)
    local highlight = ui and ui.highlight
    if not highlight or highlight._cyberui_skin then return end
    highlight._cyberui_skin = true
    restyle(highlight, "onShowHighlightMenu")
    restyle(highlight, "showHighlightDialog")
end

return Skin
