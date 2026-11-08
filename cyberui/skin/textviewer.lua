-- KOReader's text viewer in CyberUI's style: the note on a highlight, a book's
-- description, a licence, a help text. A wide card with the title, the text a
-- page at a time (a swipe or the arrows turn it) and every button the viewer
-- has, KOReader's own callbacks included. The buttons that only scrolled the
-- original (top, bottom, find) are left out, and a Close is always there. A
-- viewer of a file, or of HTML, is left as KOReader draws it.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Specs = require("cyberui/skin/specs")

local Screen = Device.screen

local Skin = {}

-- The ids of the buttons that scroll the original, which has no use here.
local SCROLLING = { top = true, bottom = true, find = true, go_to_pin = true }

-- The viewer's rows of buttons without the ones that scroll.
local function rows(viewer)
    local out = {}
    for _i, row in ipairs(Anatomy.buttons(viewer)) do
        local keep = {}
        for _j, b in ipairs(row) do
            if not SCROLLING[b.id] then keep[#keep + 1] = b end
        end
        if #keep > 0 then out[#out + 1] = keep end
    end
    return out
end

-- The card for the page of the text now showing.
local function card(viewer, state)
    local Dialog = require("cyberui/ui/dialog")
    local Label = require("cyberui/ui/label")
    local Panel = require("cyberui/ui/panel")
    local Text = require("cyberui/gfx/text")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    local th = Theme.get()
    local kind = viewer.monospace_font and "mono" or "body"
    local wrap_w = Dialog.inner(Screen:getWidth(), true) - 2 * (th.space.m + th.size.stroke) - Theme.px(4)
    local lines = Text.wrap(kind, tostring(viewer.text or ""), wrap_w, math.huge)
    local per = math.max(4, math.min(12, math.floor(Screen:getHeight() * 0.36 / Text.height(kind))))
    local pages = math.max(1, math.ceil(#lines / per))
    state.page = math.max(1, math.min(state.page or 1, pages))
    local shown = {}
    for i = (state.page - 1) * per + 1, math.min(state.page * per, #lines) do shown[#shown + 1] = lines[i] end
    local body = { Panel:new({ shape = "frame", pad = { th.space.s, th.space.m }, child = Label:new({
        text = table.concat(shown, "\n"), kind = kind, width = wrap_w, lines = per }) }) }
    if pages > 1 then
        body[#body + 1] = Dialog.pager(state.page, pages, function(p)
            state.page = p
            state.redraw()
        end)
    end
    local built = Specs.rows(rows(viewer), Specs.verbs)
    built[#built + 1] = Specs.wide({ text = _("Close"), callback = function() Core.dismiss(viewer) end }, "ghost", "close")
    for _i, el in ipairs(built) do body[#body + 1] = el end
    return Dialog.card({ tag = _("// TEXT"), title = viewer.title, rows = body, wide = true }, Screen:getWidth()), pages
end

Core.register({
    name = "textviewer",
    matches = function(widget)
        return Anatomy.is(widget, "ui/widget/textviewer") and widget.is_txt and not widget.file and type(widget.text) == "string"
    end,
    present = function(viewer)
        local state = {}
        state.redraw = function() Core.redraw(viewer, (card(viewer, state))) end
        local element, pages = card(viewer, state)
        return {
            element = element,
            place = Core.centered,
            on_outside = function() Core.dismiss(viewer) end,
            on_back = function() Core.dismiss(viewer); return true end,
            on_swipe = function(dir)
                if pages < 2 then return end
                if dir == "west" then state.page = (state.page or 1) + 1 elseif dir == "east" then state.page = (state.page or 1) - 1 else return end
                state.redraw()
            end,
        }
    end,
})

return Skin
