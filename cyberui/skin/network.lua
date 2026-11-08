-- KOReader's list of Wi-Fi networks in CyberUI's style: each network with its
-- strength and whether it is open or secured, the one you are on marked, and
-- Disconnect or Edit beside it. A tap on a network does what it does in KOReader
-- (joins a saved one, asks for the password of a new one, warns about WEP): the
-- tap is handed to KOReader's own row, which keeps the networks and does the
-- connecting. Close and a tap outside leave the list.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Geom = require("ui/geometry")
local Specs = require("cyberui/skin/specs")

local Screen = Device.screen

local Skin = {}

-- KOReader's rows of the list, one per network.
local function rows(widget)
    local list = Anatomy.find(widget, function(t)
        return type(t.items) == "table" and t.items[1] ~= nil and type(t.items[1].info) == "table" and t.items[1].setting_ui ~= nil
    end)
    return list and list.items or {}
end

-- The buttons KOReader's window has besides its rows (a retry, a rescan: whatever
-- this version of KOReader puts in the window or its title bar), found by what they are
-- so none goes missing: { text or icon, callback }. The close cross is not one.
local function extras(widget)
    local out, seen = {}, {}
    local list = rows(widget)
    local inside = {}
    for _i, item in ipairs(list) do inside[item] = true end
    local function walk(t, depth)
        if type(t) ~= "table" or seen[t] or inside[t] or depth > 9 then return end
        seen[t] = true
        if Anatomy.is(t, "ui/widget/button") and type(t.callback) == "function" then
            local icon = type(t.icon) == "string" and t.icon or nil
            if not (icon and (icon:find("close", 1, true) or icon:find("exit", 1, true) or icon:find("cancel", 1, true))) then
                out[#out + 1] = { text = t.text, icon = icon, callback = t.callback, enabled = t.enabled ~= false }
            end
            return
        end
        for k, v in pairs(t) do
            if k ~= "setting_ui" and k ~= "show_parent" and k ~= "parent" and type(v) == "table" then walk(v, depth + 1) end
        end
    end
    walk(widget, 0)
    return out
end

-- Hand KOReader's row a tap at a place that means this: the row decides from where a tap fell
-- whether it is on its disconnect text, its edit mark or the network itself, so those are given
-- places of their own and the tap is sent to the one meant.
local PLACES = { disconnect = Geom:new({ x = 1, y = 1, w = 1, h = 1 }), edit = Geom:new({ x = 5, y = 5, w = 1, h = 1 }) }
local function tapRow(item, what)
    if item.btn_disconnect then item.btn_disconnect.dimen = PLACES.disconnect end
    if item.btn_edit_nw then item.btn_edit_nw.dimen = PLACES.edit end
    local at = what and PLACES[what] or Geom:new({ x = -100, y = -100, w = 0, h = 0 })
    item:onTapSelect(nil, { pos = Geom:new({ x = at.x, y = at.y, w = 0, h = 0 }) })
end

-- KOReader's own icon for a network's strength, open or secured (the same steps it uses).
function Skin.signalIcon(info, secure)
    local q = tonumber(info.signal_quality) or 0
    local step = q > 80 and 100 or q > 55 and 75 or q > 30 and 50 or q > 5 and 25 or 0
    return string.format("ko:wifi.%s.%d.svg", secure and "secure" or "open", step)
end

-- The card for one page of the networks.
local function card(widget, state)
    local Button = require("cyberui/ui/button")
    local Dialog = require("cyberui/ui/dialog")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    local th = Theme.get()
    -- the network you are on first (KOReader's own row for it, wherever it keeps it), then the rest
    local items, connected = {}, widget.connected_item
    if connected then items[1] = connected end
    for _i, item in ipairs(rows(widget)) do
        if item ~= connected then items[#items + 1] = item end
    end
    local per = math.max(3, Dialog.rowsPerPage(Screen:getHeight()) - 1)
    local pages = math.max(1, math.ceil(#items / per))
    state.page = math.max(1, math.min(state.page or 1, pages))
    local body = {}
    for i = (state.page - 1) * per + 1, math.min(state.page * per, #items) do
        local item = items[i]
        local info = item.info
        local secure = tostring(info.flags or ""):find("WPA", 1, true) ~= nil
        local meta = string.format("%d%% // %s", math.floor(tonumber(info.signal_quality) or 0), secure and _("SECURED") or _("OPEN"))
        if info.connected then meta = table.concat({ _("CONNECTED"), meta }, " // ") end
        local line = {
            Layout.Column:new({ grow = true, children = {
                Label:new({ text = item.display_ssid or tostring(info.ssid), kind = "heading" }),
                Label:new({ text = meta, kind = "micro", color = info.connected and "accent" or "muted" }),
            } }),
        }
        if info.connected then
            line[#line + 1] = Button:new({ label = _("Disconnect"), variant = "danger", on_tap = function() tapRow(item, "disconnect"); state.redraw() end })
        elseif info.password then
            line[#line + 1] = Button:new({ label = _("Edit"), variant = "chip", on_tap = function() tapRow(item, "edit") end })
        end
        table.insert(line, 1, Button:new({ icon = Skin.signalIcon(info, secure), variant = info.connected and "chip_on" or "soft", width = th.size.touch,
            on_tap = function() tapRow(item); state.redraw() end }))
        local row = Layout.Row:new({ gap = th.space.m, height = Theme.px(64), children = line })
        body[#body + 1] = Layout.Column:new({ on_tap = function() tapRow(item); state.redraw() end, children = { row } })
    end
    if #items == 0 then body[#body + 1] = Label:new({ text = _("No networks found"), kind = "body", color = "muted" }) end
    if pages > 1 then body[#body + 1] = Dialog.pager(state.page, pages, function(p) state.page = p; state.redraw() end) end
    local more = extras(widget)
    if #more > 0 then
        local buttons = {}
        for _i, b in ipairs(more) do
            local refresh = b.icon and (b.icon:find("refresh", 1, true) or b.icon:find("reload", 1, true) or b.icon:find("restart", 1, true) or b.icon:find("rotate", 1, true))
            buttons[#buttons + 1] = Button:new({ label = b.text or (refresh and _("Retry")) or nil, icon = b.icon and (refresh and "restore" or "forward") or nil,
                variant = "soft", grow = true, disabled = not b.enabled, on_tap = b.enabled and function() b.callback(); state.redraw() end or nil })
        end
        body[#body + 1] = Layout.Row:new({ gap = th.space.s, children = buttons })
    end
    body[#body + 1] = Specs.wide({ text = _("Close"), callback = function() Core.dismiss(widget) end }, "ghost", "close")
    return Dialog.card({ tag = _("// WI-FI"), title = _("Wi-Fi networks"), rows = body }, Screen:getWidth())
end

Core.register({
    name = "network",
    matches = function(widget) return Anatomy.is(widget, "ui/widget/networksetting") and #rows(widget) > 0 end,
    present = function(widget)
        local state = {}
        state.redraw = function() Core.redraw(widget, card(widget, state)) end
        -- a network joined or left through KOReader's row (it asks for a refresh of the row when done)
        local item_class = getmetatable(rows(widget)[1]).__index
        if not item_class._cyber_watched then
            item_class._cyber_watched = true
            local refresh = item_class.refresh
            item_class.refresh = function(item, ...)
                local r = refresh(item, ...)
                local ui = item.setting_ui
                if ui and ui._cyber_redraw then ui._cyber_redraw() end
                return r
            end
        end
        widget._cyber_redraw = function() if widget._cyber_popup then state.redraw() end end
        return {
            element = card(widget, state),
            place = Core.centered,
            on_outside = function() Core.dismiss(widget) end,
            on_back = function() Core.dismiss(widget); return true end,
        }
    end,
})

return Skin
