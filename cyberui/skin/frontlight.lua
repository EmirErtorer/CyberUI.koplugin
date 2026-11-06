-- KOReader's own frontlight window (Settings > Frontlight, or a gesture)
-- drawn as CyberUI's: a floating card with a slider for the light and, when
-- the device has it, one for the warmth, and a switch. KOReader still builds
-- the window and sets the light through it (so the device's rules about
-- limits and toggling stay its own); its widgets are never painted.

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

-- The card for the window `w`: its title, the sliders and the buttons.
local function build(w, popup_of)
    local Button = require("cyberui/ui/button")
    local Host = require("cyberui/host")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Panel = require("cyberui/ui/panel")
    local Slider = require("cyberui/ui/slider")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    local th = Theme.get()
    local function row(name, min, max, value, set)
        local slider = Slider:new({ min = min, max = max, value = value, grow = true, on_change = set,
            on_redraw = function(el)
                local popup = popup_of()
                if popup then UIManager:setDirty(popup, Theme.isDark() and "ui" or "fast", Host.box(el)) end
            end })
        return Layout.Row:new({ gap = th.space.s, children = {
            Label:new({ text = name, kind = "label", width = Theme.px(76) }), slider } })
    end
    local kids = {}
    kids[#kids + 1] = row(_("LUMEN"), w.fl.min, w.fl.max, w.fl.cur, function(v) w:setBrightness(v) end)
    if w.has_nl and w.nl then
        kids[#kids + 1] = row(_("TINT"), w.nl.min, w.nl.max, w.nl.cur, function(v) w:setWarmth(v, true) end)
    end
    local function close() UIManager:close(w) end
    kids[#kids + 1] = Layout.Row:new({ gap = th.space.s, children = {
        Button:new({ label = _("Close"), variant = "ghost", grow = true, on_tap = close }),
    } })
    local width = math.min(Screen:getWidth() - 2 * th.space.xl, Theme.px(520))
    return Panel:new({ shape = "chamfer", corners = "tb", fill = "bg", pad = th.space.xl, width = width,
        child = Layout.Column:new({ gap = th.space.m, children = kids }) })
end

-- Style KOReader's frontlight window (patches its class once).
function Skin.install()
    local FrontLightWidget = require("ui/widget/frontlightwidget")
    if FrontLightWidget._cyberui_skin then return end
    FrontLightWidget._cyberui_skin = true
    local init, on_show, on_close_widget = FrontLightWidget.init, FrontLightWidget.onShow, FrontLightWidget.onCloseWidget
    FrontLightWidget.init = function(self, ...)
        init(self, ...)
        if not Skin.wanted() then return end
        local Popup = require("cyberui/popup")
        local ok, element = pcall(build, self, function() return self._cyber_popup end)
        if not ok then
            require("logger").warn("CyberUI frontlight:", element)
            return
        end
        -- KOReader's window stays unpainted and its own refreshes do nothing
        self.paintTo = function() end
        self.update = function() return true end
        self.dimen = Geom:new({ x = 0, y = 0, w = 0, h = 0 })
        self.ges_events, self.key_events = {}, {}
        self._cyber_popup = Popup:new({
            element = element,
            place = function(el)
                return math.floor((Screen:getWidth() - el.w) / 2), math.floor((Screen:getHeight() - el.h) / 2)
            end,
            on_outside = function() UIManager:close(self) end,
        })
    end
    FrontLightWidget.onShow = function(self)
        local popup = self._cyber_popup
        if popup then
            UIManager:show(popup, "ui", popup:box())
            return true
        end
        return on_show(self)
    end
    FrontLightWidget.onCloseWidget = function(self, ...)
        local popup = self._cyber_popup
        if popup then
            self._cyber_popup = nil
            UIManager:close(popup, "flashui", popup:box())
            return
        end
        return on_close_widget(self, ...)
    end
end

return Skin
