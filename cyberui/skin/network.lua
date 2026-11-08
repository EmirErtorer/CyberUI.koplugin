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

-- The card for one page of the networks.
local function card(widget, state)
    local Button = require("cyberui/ui/button")
    local Dialog = require("cyberui/ui/dialog")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    local th = Theme.get()
    local items = rows(widget)
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
        table.insert(line, 1, Button:new({ icon = "network", variant = info.connected and "chip_on" or "soft", width = th.size.touch,
            on_tap = function() tapRow(item); state.redraw() end }))
        local row = Layout.Row:new({ gap = th.space.m, height = Theme.px(64), children = line })
        body[#body + 1] = Layout.Column:new({ on_tap = function() tapRow(item); state.redraw() end, children = { row } })
    end
    if #items == 0 then body[#body + 1] = Label:new({ text = _("No networks found"), kind = "body", color = "muted" }) end
    if pages > 1 then body[#body + 1] = Dialog.pager(state.page, pages, function(p) state.page = p; state.redraw() end) end
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
