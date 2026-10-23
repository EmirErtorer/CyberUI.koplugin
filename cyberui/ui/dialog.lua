-- Dialogs and toasts drawn in the style. The host shows the element these
-- build as an overlay; every action calls `close` before it runs.

local Button = require("cyberui/ui/button")
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

-- A question with cancel and confirm; `danger` adds the warning look.
-- o: { title, text, detail, ok, cancel, danger, on_ok }
function Dialog.confirm(o, close, screen_w)
    local th = Theme.get()
    local kids = {}
    if o.danger then
        kids[#kids + 1] = Icon:new({ name = "warning", size = 44, color = "accent", width = width(screen_w) - 2 * th.space.xl })
        kids[#kids + 1] = Label:new({ text = o.title or _("Attention"), kind = "display", color = "accent", align = "center" })
    else
        kids[#kids + 1] = Label:new({ text = o.title, kind = "title" })
    end
    if o.detail then
        kids[#kids + 1] = Panel:new({ shape = "frame", pad = { th.space.xs, th.space.m }, child =
            Label:new({ text = o.detail, kind = "mono", align = "center" }) })
    end
    if o.text then
        kids[#kids + 1] = Label:new({ text = o.text, kind = "body", lines = 5, align = o.danger and "center" or "left" })
    end
    kids[#kids + 1] = Layout.Row:new({ gap = th.space.m, children = {
        Button:new({ label = o.cancel or _("Cancel"), grow = true, on_tap = closing(close) }),
        Button:new({ label = o.ok or _("OK"), variant = "primary", grow = true, on_tap = closing(close, o.on_ok) }),
    } })
    return Panel:new({ shape = "chamfer", corners = "tb", fill = "bg", pad = th.space.xl, width = width(screen_w),
        child = Layout.Column:new({ gap = th.space.m, align = o.danger and "center" or "stretch", children = kids }) })
end

-- A list of choices; options are { label, sub, on_tap, checked }.
function Dialog.choose(o, close, screen_w)
    local th = Theme.get()
    local kids = { Label:new({ text = o.title, kind = "title" }) }
    for _i, opt in ipairs(o.options) do
        kids[#kids + 1] = Button:new({
            label = opt.label, sub = opt.sub, align = "left", icon = opt.checked and "check" or opt.icon,
            variant = opt.checked and "chip_on" or "soft", on_tap = closing(close, opt.on_tap),
        })
    end
    kids[#kids + 1] = Button:new({ label = o.cancel or _("Close"), variant = "ghost", on_tap = closing(close) })
    return Panel:new({ shape = "chamfer", corners = "tb", fill = "bg", pad = th.space.xl, width = width(screen_w),
        child = Layout.Column:new({ gap = th.space.s, children = kids }) })
end

-- A short notice for the top of the screen.
function Dialog.toast(text)
    local th = Theme.get()
    return Panel:new({ shape = "chamfer", corners = "trbl", cut = "cut_small", fill = "ink", line = "ink",
        pad = { th.space.s, th.space.xl },
        child = Label:new({ text = text, kind = "mono", color = "on_ink" }) })
end

return Dialog
