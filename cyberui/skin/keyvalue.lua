-- KOReader's information lists in CyberUI's style: a book's details, the
-- statistics, a device's data and every list a plugin makes with KOReader's
-- KeyValuePage. A short value sits at the right of its name; a long one goes
-- under it, wrapped, and a tap on a value that is cut shows all of it, as in
-- KOReader. KOReader keeps the pairs, and what a tap or a hold on one does
-- (the same callbacks, given the same page and item).

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")

local Screen = Device.screen

local Skin = {}

-- The lines a long value may take under its name before it is cut.
local MAX_LINES = 4

-- What a pair shows: its value on one line (the line breaks KOReader keeps are bars).
local function valueOf(entry)
    return (tostring(entry[2] or ""):gsub("[\n\t]", " | "))
end

-- How a pair is laid out and how tall it is: "side" (value beside its name) or "stacked".
local function measure(entry, inner)
    local Text = require("cyberui/gfx/text")
    local Theme = require("cyberui/theme")
    local th = Theme.get()
    local value = valueOf(entry)
    local key = tostring(entry[1] or "")
    local side = Text.width("mono", value) + Text.width("label", key) + th.space.xl <= inner
    if side then return { mode = "side", h = Theme.px(54), value = value, key = key } end
    local lines = Text.wrap("body", value, inner, MAX_LINES + 1)
    local cut = #lines > MAX_LINES
    local shown = math.min(#lines, MAX_LINES)
    return { mode = "stacked", value = value, key = key, lines = shown, cut = cut,
        h = Text.height("micro") + shown * Text.height("body") + 2 * th.space.s + th.size.hair }
end

-- A pair as a row: the name and the value, a mark at the end when a tap does something.
local function row(page, entry, index, m)
    local Deco = require("cyberui/ui/deco")
    local Icon = require("cyberui/ui/icon")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local UIManager = require("ui/uimanager")
    local Theme = require("cyberui/theme")
    local th = Theme.get()
    -- the item KOReader's callbacks are given: the page and where the pair is in it
    local item = { kv_page = page, kv_pairs_idx = index, key = entry[1], value = entry[2], callback = entry.callback, hold_callback = entry.hold_callback }
    local function show_all()
        UIManager:show(require("ui/widget/textviewer"):new({ title = tostring(entry[1] or ""), text = tostring(entry[2] or "") }))
    end
    local on_tap = entry.callback and function() entry.callback(page, item) end or (m.cut and show_all or nil)
    local on_hold = entry.hold_callback and function() entry.hold_callback(page, item) end or (m.cut and show_all or nil)
    local body
    if m.mode == "side" then
        body = Layout.Row:new({ gap = th.space.m, height = m.h - th.size.hair, children = {
            Label:new({ text = m.key, kind = "label", color = "muted", grow = true }),
            Label:new({ text = m.value, kind = "mono", align = "right" }),
        } })
    else
        body = Layout.Column:new({ gap = th.space.xs, grow = true, children = {
            Label:new({ text = m.key, kind = "micro", color = "muted" }),
            Label:new({ text = m.value, kind = "body", lines = m.lines }),
        } })
        body = Layout.Row:new({ height = m.h - th.size.hair, children = { body } })
    end
    local kids = { body }
    if entry.callback then
        kids[1] = Layout.Row:new({ gap = th.space.m, height = m.h - th.size.hair, children = { body, Icon:new({ name = "forward", size = 18, width = Theme.px(22) }) } })
    end
    local divider = Deco.Divider:new({ color = entry.separator and "ink" or nil })
    return Layout.Column:new({ children = { kids[1], divider }, on_tap = on_tap, on_hold = on_hold })
end

-- Where each page starts, filling every page up to the room there is.
local function pageStarts(page, inner, room)
    local starts, used = { 1 }, 0
    local measured = {}
    for i, entry in ipairs(page.kv_pairs) do
        if type(entry) == "table" then
            measured[i] = measure(entry, inner)
            if used + measured[i].h > room and used > 0 then
                starts[#starts + 1] = i
                used = 0
            end
            used = used + measured[i].h
        end
    end
    return starts, measured
end

-- The whole list as it is now.
local function build(widget, state)
    local Button = require("cyberui/ui/button")
    local Fullpage = require("cyberui/skin/fullpage")
    local Theme = require("cyberui/theme")
    local th = Theme.get()
    local inner = Screen:getWidth() - 2 * th.space.xl
    local starts, measured = pageStarts(widget, inner, Fullpage.room())
    local pages = #starts
    if not state.page then
        -- open on the page KOReader was asked to start on
        local first = ((widget.show_page or 1) - 1) * (widget.items_per_page or 1) + 1
        state.page = 1
        for p, at in ipairs(starts) do if at <= first then state.page = p end end
    end
    state.page = math.max(1, math.min(state.page, pages))
    local from, to = starts[state.page], (starts[state.page + 1] or (#widget.kv_pairs + 1)) - 1
    local rows = {}
    for i = from, to do
        if measured[i] then rows[#rows + 1] = row(widget, widget.kv_pairs[i], i, measured[i]) end
    end
    local actions = {}
    if widget.title_bar_left_icon and widget.title_bar_left_icon_tap_callback then
        actions[1] = Button:new({ icon = "menu", variant = "icon", width = th.size.touch,
            on_tap = function() widget.title_bar_left_icon_tap_callback() end })
    end
    local back = (widget.callback_return and widget.page_return_arrow) and function() widget:onReturn() end or function() widget:onClose() end
    return Fullpage.build({ title = tostring(widget.title or ""), on_back = back, actions = actions, rows = rows, page = state.page, pages = pages,
        show = function(p)
            state.page = p
            state.redraw()
        end })
end

Core.register({
    name = "keyvalue",
    matches = function(widget) return Anatomy.is(widget, "ui/widget/keyvaluepage") and type(widget.kv_pairs) == "table" end,
    present = function(widget)
        local state = {}
        state.redraw = function() Core.redraw(widget, build(widget, state)) end
        -- KOReader fills the page again when pairs are removed or changed: the list follows
        local populate = widget._populateItems
        widget._populateItems = function(self, ...)
            local r = populate(self, ...)
            if widget._cyber_popup then state.redraw() end
            return r
        end
        return {
            element = build(widget, state),
            place = function() return 0, 0 end,
            on_outside = function() end,
            on_back = function() widget:onClose(); return true end,
            on_swipe = function(dir)
                if dir == "west" then state.page = (state.page or 1) + 1 elseif dir == "east" then state.page = (state.page or 1) - 1 else return end
                state.redraw()
            end,
        }
    end,
})

return Skin
