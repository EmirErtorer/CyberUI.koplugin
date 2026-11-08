-- KOReader's window for putting things in order (the order of the menu's
-- entries, of a plugin's tabs) in CyberUI's style: each row has its own step up
-- and step down, a tap marks it, and the ones KOReader lets be switched on and
-- off have a tick. KOReader keeps the list and does the moving, so what Done
-- passes on is exactly what its own window would; the menu for sorting A to Z
-- and back is KOReader's own, from the button at the top.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Specs = require("cyberui/skin/specs")

local Skin = {}

-- Run KOReader's function for an item without its window asking for refreshes.
local function call(fn, ...)
    if type(fn) == "function" then return pcall(fn, ...) end
end

-- One item as a row: a tick when it can be switched, the name, and steps up and down.
local function row(widget, item, index, total, state)
    local Button = require("cyberui/ui/button")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Panel = require("cyberui/ui/panel")
    local Deco = require("cyberui/ui/deco")
    local Theme = require("cyberui/theme")
    local th = Theme.get()
    local marked = widget.marked == index
    local kids = {}
    if item.checked_func then
        local ok, on = call(item.checked_func)
        kids[#kids + 1] = Button:new({ icon = (ok and on) and "check" or nil, variant = (ok and on) and "chip_on" or "chip", width = th.size.touch,
            on_tap = function() call(item.callback); state.redraw() end })
    end
    kids[#kids + 1] = Label:new({ text = tostring(item.text or ""), kind = marked and "title" or "heading", color = item.dim and "muted" or nil, grow = true })
    if not widget.sort_disabled then
        local function step(by, icon)
            local enabled = index + by >= 1 and index + by <= total
            return Button:new({ icon = icon, variant = "soft", disabled = not enabled, width = th.size.touch,
                on_tap = enabled and function()
                    widget.marked = index
                    widget:moveItem(by)
                end or nil })
        end
        kids[#kids + 1] = step(-1, "up")
        kids[#kids + 1] = step(1, "down")
    end
    local line = Layout.Row:new({ gap = th.space.s, height = Theme.px(60) - th.size.hair, children = kids })
    local built = Layout.Column:new({ children = { line, Deco.Divider:new({}) }, on_tap = function()
        if widget.sort_disabled then
            call(item.callback)
        else
            widget.marked = marked and 0 or index
        end
        state.redraw()
    end, on_hold = function()
        if item.hold_callback then call(item.hold_callback, item, function() widget:_populateItems() end)
        elseif item.callback then call(item.callback); widget:_populateItems() end
    end })
    if marked then
        return Layout.Row:new({ children = { Panel:new({ shape = "rail", line = "accent", pad = { 0, 0, 0, Theme.px(14) }, grow = true, child = built }) } })
    end
    return Layout.Row:new({ children = { built } })
end

-- The whole window as it is now.
local function build(widget, state)
    local Button = require("cyberui/ui/button")
    local Fullpage = require("cyberui/skin/fullpage")
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    local th = Theme.get()
    local items = widget.item_table
    local per = math.max(3, math.floor(Fullpage.room(1) / Theme.px(60)))
    local pages = math.max(1, math.ceil(#items / per))
    if widget.marked and widget.marked > 0 and state.follow then
        state.page = math.ceil(widget.marked / per)   -- a moved item stays in view
    end
    state.follow = nil
    state.page = math.max(1, math.min(state.page or math.ceil(((widget.show_page or 1) - 1) * (widget.items_per_page or per) / per) + 1, pages))
    local rows = {}
    for i = (state.page - 1) * per + 1, math.min(state.page * per, #items) do rows[#rows + 1] = row(widget, items[i], i, #items, state) end
    local actions = {}
    if not widget.sort_disabled then
        actions[1] = Button:new({ icon = "sort", variant = "icon", width = th.size.touch, on_tap = function() widget:onShowWidgetMenu() end })
    end
    local close = Specs.wide({ text = _("Cancel"), callback = function()
        widget:onCancel()
        widget:onClose()
    end }, "ghost", "close")
    local done = Specs.wide({ text = _("Done"), is_enter_default = true, callback = function()
        widget.marked = 0
        widget:onReturn()
    end }, "primary", "check")
    return Fullpage.build({ title = tostring(widget.title or ""), on_back = function() widget:onCancel(); widget:onClose() end, actions = actions,
        rows = rows, page = state.page, pages = pages, show = function(p)
            state.page = p
            state.redraw()
        end, footer = { Layout.Row:new({ gap = th.space.m, children = { close.children[1], done.children[1] } }) } })
end

Core.register({
    name = "sort",
    matches = function(widget) return Anatomy.is(widget, "ui/widget/sortwidget") and type(widget.item_table) == "table" end,
    present = function(widget)
        local state = {}
        state.redraw = function() Core.redraw(widget, build(widget, state)) end
        -- KOReader fills its page again when an item moved or its menu sorted the list: the window follows
        local populate = widget._populateItems
        widget._populateItems = function(self, ...)
            local r = populate(self, ...)
            state.follow = true
            if widget._cyber_popup then state.redraw() end
            return r
        end
        return {
            element = build(widget, state),
            place = function() return 0, 0 end,
            on_outside = function() end,
            on_back = function() widget:onCancel(); widget:onClose(); return true end,
            on_swipe = function(dir)
                if dir == "west" then state.page = (state.page or 1) + 1 elseif dir == "east" then state.page = (state.page or 1) - 1 else return end
                state.redraw()
            end,
        }
    end,
})

return Skin
