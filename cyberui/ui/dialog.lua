-- Dialogs and toasts drawn in the style. The host shows the element these
-- build as an overlay; every action calls `close` before it runs.

local Button = require("cyberui/ui/button")
local Deco = require("cyberui/ui/deco")
local Icon = require("cyberui/ui/icon")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local Dialog = {}

-- Width of a dialog on this screen.
local function width(w)
    return math.min(w - 2 * Theme.get().space.xl, Theme.px(460))
end

-- Wrap an action so the dialog closes first.
local function closing(close, fn)
    return function()
        close()
        if fn then fn() end
    end
end

-- A question with cancel and confirm; `danger` adds the warning look, `icon`
-- a large icon over the title. o: { title, text, detail, ok, cancel, danger,
-- icon, on_ok }
function Dialog.confirm(o, close, screen_w)
    local th = Theme.get()
    local kids = {}
    local centred = o.danger or o.icon
    if centred then
        kids[#kids + 1] = Icon:new({ name = o.icon or "warning", size = 44, color = o.danger and "accent" or "ink",
            width = width(screen_w) - 2 * th.space.xl })
        kids[#kids + 1] = Label:new({ text = o.title or _("Attention"), kind = "display", color = o.danger and "accent" or "ink",
            align = "center" })
    else
        kids[#kids + 1] = Label:new({ text = o.title, kind = "title" })
    end
    if o.detail then
        kids[#kids + 1] = Panel:new({ shape = "frame", pad = { th.space.xs, th.space.m }, child =
            Label:new({ text = o.detail, kind = "mono", align = "center" }) })
    end
    if o.text then
        kids[#kids + 1] = Label:new({ text = o.text, kind = "body", lines = 9, align = centred and "center" or "left" })
    end
    kids[#kids + 1] = Layout.Row:new({ gap = th.space.m, children = {
        Button:new({ label = o.cancel or _("Cancel"), grow = true, on_tap = closing(close) }),
        Button:new({ label = o.ok or _("OK"), variant = "primary", grow = true, on_tap = closing(close, o.on_ok) }),
    } })
    return Panel:new({ shape = "chamfer", corners = "tb", fill = "bg", pad = th.space.xl, width = width(screen_w),
        child = Layout.Column:new({ gap = th.space.m, align = centred and "center" or "stretch", children = kids }) })
end

-- Lay `items` out `cols` to a row, each made into a button by make(item),
-- appending the rows to `kids`. An odd last row keeps its tiles the width
-- of the others.
local function tiles(kids, items, cols, make)
    local th = Theme.get()
    local row
    for i, item in ipairs(items) do
        if cols == 1 then
            kids[#kids + 1] = make(item)
        else
            if (i - 1) % cols == 0 then
                row = Layout.Row:new({ gap = th.space.s, children = {} })
                kids[#kids + 1] = row
            end
            local b = make(item)
            b.grow = true
            row.children[#row.children + 1] = b
        end
    end
    if row and #row.children < cols then
        for _i = #row.children + 1, cols do row.children[#row.children + 1] = Layout.Spacer:new({ grow = true }) end
    end
end

-- A list of choices; options are { label, sub, icon, on_tap, checked },
-- `cols` to a row (1 by default).
function Dialog.choose(o, close, screen_w)
    local th = Theme.get()
    local kids = { Label:new({ text = o.title, kind = "title" }) }
    tiles(kids, o.options, o.cols or 1, function(opt)
        return Button:new({
            label = opt.label, sub = opt.sub, align = "left", icon = opt.checked and "check" or opt.icon,
            height = (o.cols or 1) > 1 and opt.sub and Theme.px(58) or nil,
            variant = opt.checked and "chip_on" or "soft", on_tap = closing(close, opt.on_tap),
        })
    end)
    kids[#kids + 1] = Button:new({ label = o.cancel or _("Close"), variant = "ghost", on_tap = closing(close) })
    return Panel:new({ shape = "chamfer", corners = "tb", fill = "bg", pad = th.space.xl, width = width(screen_w),
        child = Layout.Column:new({ gap = th.space.s, children = kids }) })
end

-- An action sheet: a title (and a line under it) over a grid of actions,
-- each { icon, label, sub, on_tap, danger }, `cols` to a row (2 by default).
function Dialog.sheet(o, close, screen_w)
    local th = Theme.get()
    local kids = { Label:new({ text = o.title, kind = "title", lines = 2 }) }
    if o.sub then kids[#kids + 1] = Label:new({ text = o.sub, kind = "small", color = "muted" }) end
    tiles(kids, o.actions, o.cols or 2, function(a)
        return Button:new({
            icon = a.icon, label = a.label, sub = a.sub, align = "left",
            height = a.sub and Theme.px(58) or nil,
            variant = a.danger and "danger" or "soft", on_tap = closing(close, a.on_tap),
        })
    end)
    kids[#kids + 1] = Button:new({ label = o.cancel or _("Close"), variant = "ghost", on_tap = closing(close) })
    return Panel:new({ shape = "chamfer", corners = "tb", fill = "bg", pad = th.space.xl, width = width(screen_w),
        child = Layout.Column:new({ gap = th.space.s, children = kids }) })
end

-- A step of a longer task (no buttons): a title, the step and a striped bar.
function Dialog.progress(o, screen_w)
    local th = Theme.get()
    return Panel:new({ shape = "chamfer", corners = "tb", fill = "bg", pad = th.space.xl, width = width(screen_w),
        child = Layout.Column:new({ gap = th.space.m, children = {
            Label:new({ text = o.title, kind = "title" }),
            Label:new({ text = o.text, kind = "mono", lines = 2 }),
            Deco.Stripes:new({ dir = "d", height = Theme.px(14), color = "ink" }),
        } }) })
end

-- A short notice shown near the bottom of the screen.
function Dialog.toast(text)
    local th = Theme.get()
    return Panel:new({ shape = "chamfer", corners = "trbl", cut = "cut_small", fill = "ink", line = "ink",
        pad = { th.space.s, th.space.xl },
        child = Label:new({ text = text, kind = "mono", color = "on_ink" }) })
end

return Dialog
