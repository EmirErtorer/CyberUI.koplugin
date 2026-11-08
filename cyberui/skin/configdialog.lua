-- KOReader's bottom settings panel in a book (font size, margins, render mode,
-- contrast and the rest), drawn in CyberUI's style. KOReader still builds the
-- panel, keeps every value and does every change: its widgets are made as
-- always but never painted. Each row is read from them (the name and the
-- toggle, letters, icons or steps it holds) and drawn as CyberUI controls
-- whose taps call the original widget, so a choice, a long press to make it
-- the default, the fine-tune and "more" buttons all behave exactly as before.
-- Anything unexpected falls back to KOReader's own drawing.

local Device = require("device")
local Core = require("cyberui/skin/core")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local Format = require("cyberui/format")

local Screen = Device.screen

local Skin = {}

-- Is a stock colour a "selected" one (anything but white)?
local function dark(color)
    if not color then return false end
    return color:getColor8().a < 255
end

-- A CyberUI icon id for one of KOReader's icon names (nil when the device has no such icon).
local function iconId(name)
    local lfs = require("libs/libkoreader-lfs")
    if type(name) ~= "string" then return nil end
    if lfs.attributes("resources/icons/mdlight/" .. name .. ".svg", "mode") == "file" then return "ko:" .. name .. ".svg" end
    local user = require("datastorage"):getDataDir() .. "/icons/" .. name .. ".svg"
    if lfs.attributes(user, "mode") == "file" then return "reader:" .. name .. ".svg" end
    return nil
end

-- Where a tap on position `k` of a toggle switch lands, as the switch reads taps.
local function tapAt(switch, k)
    local d = switch.dimen
    local row = math.ceil(k / switch.n_pos)
    local col = k - (row - 1) * switch.n_pos
    switch.dimen = Geom:new({ x = 0, y = 0, w = d.w, h = d.h })
    return { pos = Geom:new({ x = (col - 0.5) / switch.n_pos * d.w, y = (row - 0.5) / switch.row_count * d.h, w = 0, h = 0 }) }
end

-- The control for one row's items: letters and icons (the original items),
-- a toggle switch (its labels) or a progress of steps. Returns the element, or nil.
local function control(group)
    local Controls = require("cyberui/ui/controls")
    local Button = require("cyberui/ui/button")
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    local options, selected, enabled = {}, nil, true
    for _i, w in ipairs(group) do
        if w.item_text or w.icon then
            -- one letter or icon of a set, each its own widget
            local k = #options + 1
            options[k] = { w.item_text and Format.upper(w.item_text[w.current_item]) or nil, k, icon = w.icon and iconId(w.icon.icon),
                on_tap = function() w:onTapSelect() end, on_hold = function() w:onHoldSelect() end }
            if not options[k][1] and not options[k].icon then options[k][1] = tostring(k) end
            if dark(w.underline_container and w.underline_container.color) then selected = k end
            enabled = enabled and w.enabled ~= false
        elseif w.toggle then
            -- a toggle switch: its labels, one row of them per `row_count`
            local rows = {}
            for k, label in ipairs(w.toggle) do
                local r = math.ceil(k / w.n_pos)
                rows[r] = rows[r] or {}
                rows[r][#rows[r] + 1] = { Format.upper(label), k,
                    on_tap = function() w:onTapSelect(nil, tapAt(w, k)) end,
                    on_hold = function() w:onHoldSelect(nil, tapAt(w, k)) end }
            end
            local els = {}
            for _r, opts in ipairs(rows) do
                els[#els + 1] = Controls.Segmented({ options = opts, value = w.position, disabled = w.enabled == false })
            end
            return #els == 1 and els[1] or Layout.Column:new({ gap = Theme.get().space.s, children = els })
        elseif w.num_buttons then
            -- steps (and fine tune - / + and "more" at the ends): the widget's own buttons
            local btns = w.layout and w.layout[1] or {}
            local function press(i, field)
                local b = btns[i]
                local fn = b and (b[field] or (b[1] and b[1][field]))
                return fn
            end
            local off = w.fine_tune and 1 or 0
            local cells = {}
            local function add(i, label, on)
                cells[#cells + 1] = Button:new({ label = label, grow = true, height = Theme.px(38), kind = "mono_small",
                    variant = on and "chip_on" or "chip", disabled = w.enabled == false,
                    on_tap = w.enabled ~= false and press(i, "callback") or nil,
                    on_hold = w.enabled ~= false and press(i, "hold_callback") or nil })
            end
            if w.fine_tune then add(1, "-", false) end
            for i = 1, w.num_buttons do add(i + off, "", i <= (w.position or 0)) end
            local nxt = off + w.num_buttons + 1
            if w.fine_tune then add(nxt, "+", false); nxt = nxt + 1 end
            if w.more_options then add(nxt, "...", false) end
            return Layout.Row:new({ gap = Theme.px(3), children = cells })
        end
    end
    if #options > 0 then
        return Controls.Segmented({ options = options, value = selected, disabled = not enabled })
    end
end

-- The CyberUI element for a ConfigDialog's current panel and tab bar, or nil
-- when it can't be read.
local function build(dialog)
    local Button = require("cyberui/ui/button")
    local Dialog = require("cyberui/ui/dialog")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    local th = Theme.get()
    local panel = dialog.config_panel and dialog.config_panel[1]   -- the options' ConfigOption
    local rows = panel and panel[1]                                -- its vertical group
    if not rows then return nil end
    local kids = {}
    local name_w = math.floor(Screen:getWidth() * 0.28)
    for _i, row in ipairs(rows) do
        -- a row is the name (right-aligned, maybe missing) and the items' container
        local first, second = row[1], row[2]
        local name = first and first[1] and first[1].text
        local items = (second or first) and (second or first)[1]
        if type(items) == "table" and items[1] then
            local el = control(items)
            if el then
                if name and second then
                    kids[#kids + 1] = Layout.Row:new({ gap = th.space.m, children = {
                        Label:new({ text = Format.upper(name), kind = "small", color = "muted", width = name_w, lines = 2 }), el } })
                    el.grow = true
                else
                    kids[#kids + 1] = el
                end
            end
        end
    end
    -- the tabs: the icons of KOReader's menu bar
    local tabs = {}
    local bar = dialog.config_menubar
    for c, item in ipairs(bar and bar.menu_items or {}) do
        tabs[#tabs + 1] = Button:new({ icon = iconId(item.icon) or "tools", grow = true, height = th.size.touch, icon_size = 22,
            variant = c == dialog.panel_index and "tab_on" or "tab",
            on_tap = function() dialog:onShowConfigPanel(c) end })
    end
    if #kids == 0 then return nil end
    kids[#kids + 1] = Layout.Row:new({ gap = Theme.px(2), children = tabs })
    return Dialog.docked(kids, "bottom", Screen:getWidth())
end

-- Show the dialog's popup (once KOReader shows the dialog).
local function open(dialog)
    local popup = dialog._cyber_popup
    if popup and not dialog._cyber_open then
        dialog._cyber_open = true
        UIManager:show(popup, "ui", popup:box())
    end
end

-- Draw the dialog's panel as CyberUI's, now and after every change.
local function refresh(dialog)
    local Popup = require("cyberui/popup")
    local ok, element = pcall(build, dialog)
    if not (ok and element) then
        if not ok then require("logger").warn("CyberUI config panel:", element) end
        if dialog._cyber_popup then dialog._cyber_popup:close(); dialog._cyber_open = false end
        dialog._cyber_popup, dialog._cyber = nil, false   -- KOReader's own drawing
        return
    end
    dialog[1] = nil   -- KOReader's panel stays unpainted
    local popup = dialog._cyber_popup
    if popup and dialog._cyber_open then
        popup:redraw(element)
    elseif popup then
        popup:setElement(element)
    else
        popup = Popup:new({
            element = element,
            on_outside = function() dialog:closeDialog() end,
            on_swipe = function(direction) if direction == "south" then dialog:closeDialog() end end,
        })
        dialog._cyber_popup = popup
    end
    -- what KOReader's refreshes and tap tests read
    dialog.dialog_frame.dimen = popup:box()
end

-- Style KOReader's settings panel (patches its class once).
function Skin.install()
    local ConfigDialog = require("ui/widget/configdialog")
    if ConfigDialog._cyberui_skin then return end
    ConfigDialog._cyberui_skin = true
    local init, update, on_close_widget = ConfigDialog.init, ConfigDialog.update, ConfigDialog.onCloseWidget
    ConfigDialog.init = function(self, ...)
        self._cyber = Core.wanted()
        return init(self, ...)
    end
    ConfigDialog.update = function(self, ...)
        update(self, ...)
        if self._cyber then refresh(self) end
    end
    ConfigDialog.onShow = function(self)
        if self._cyber then open(self) end
    end
    ConfigDialog.onCloseWidget = function(self, ...)
        on_close_widget(self, ...)
        local popup = self._cyber_popup
        if popup and self._cyber_open then
            self._cyber_open = false
            popup:close()
        end
    end
end

return Skin
