-- KOReader describes a button as a table ({ text or text_func, callback,
-- hold_callback, enabled or enabled_func, checked_func, icon... }); this turns
-- such tables, and the rows of them a dialog holds, into CyberUI's buttons.

local Button = require("cyberui/ui/button")
local Layout = require("cyberui/ui/layout")
local Semantics = require("cyberui/skin/semantics")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

local Screen = require("device").screen

local Specs = {}

-- Run a function KOReader gave, without letting it break the drawing.
local function call(fn)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn)
    if ok then return value end
end

-- The label, state and handlers of one described button.
function Specs.read(b)
    local label = b.text
    if b.text_func then label = call(b.text_func) or label end
    local enabled = b.enabled ~= false
    if enabled and b.enabled_func then enabled = call(b.enabled_func) ~= false end
    return {
        label = label or "",
        enabled = enabled,
        checked = b.checked_func and call(b.checked_func) or false,
        callback = b.callback,
        hold_callback = b.hold_callback,
        primary = b.is_enter_default == true,
    }
end

-- A CyberUI button for a described one. `variant` is the look when it is
-- neither primary nor disabled, `icon` one to show beside the label (a button
-- KOReader marks checked shows a check instead).
function Specs.button(b, variant, icon)
    local s = Specs.read(b)
    local usable = s.enabled and s.callback ~= nil
    return Button:new({
        label = s.label, icon = s.checked and "check" or icon, grow = true,
        variant = s.primary and "primary" or variant or "soft",
        disabled = not usable, on_tap = usable and s.callback or nil,
        on_hold = s.enabled and s.hold_callback or nil,
    })
end

-- A described button alone on its line, the whole width.
function Specs.wide(b, variant, icon)
    return Layout.Row:new({ children = { Specs.button(b, variant, icon) } })
end

-- Share a line of buttons out: equal widths when every label fits in its share,
-- else each by what its label needs, so a short button ("▲") does not take
-- room a long one ("Cancel") needs. `room` is the width the line has.
local function share(cells, room, gap)
    local widest, total = 0, gap * (#cells - 1)
    for _i, c in ipairs(cells) do
        local w = c:naturalWidth()
        c.need = w
        widest = math.max(widest, w)
        total = total + w
    end
    if widest * #cells + gap * (#cells - 1) <= room then return end
    for _i, c in ipairs(cells) do c.grow = c.need end
end

-- Cells that cannot share one line of `room` go on as many lines as they need,
-- in order, each line as full as it can be.
local function lines(cells, room, gap)
    local out, line, used = {}, {}, 0
    for _i, c in ipairs(cells) do
        local w = c:naturalWidth()
        if #line > 0 and used + gap + w > room then
            out[#out + 1] = line
            line, used = {}, 0
        end
        used = used + (#line > 0 and gap or 0) + w
        line[#line + 1] = c
    end
    if #line > 0 then out[#out + 1] = line end
    return out
end

-- The rows of described buttons as rows of CyberUI buttons; `pick(row, i, b)`
-- may name another variant for a button, and an icon after it. A row too
-- long for `room` (the inside of the card, by default) goes on to a second line.
function Specs.rows(rows, pick, room)
    local gap = Theme.get().space.s
    room = room or require("cyberui/ui/dialog").inner(Screen:getWidth())
    local out = {}
    for _i, row in ipairs(rows) do
        local cells = {}
        for j, b in ipairs(row) do
            local variant, icon
            if pick then variant, icon = pick(row, j, b) end
            cells[#cells + 1] = Specs.button(b, variant, icon)
        end
        for _j, line in ipairs(lines(cells, room, gap)) do
            share(line, room, gap)
            out[#out + 1] = Layout.Row:new({ gap = gap, children = line })
        end
    end
    return out
end

-- For Specs.rows: the look a button of a dialog has from what it says (see
-- Semantics.verb): an icon, the warning look for what deletes, the main look
-- for what the dialog is mostly for. Buttons it does not know stay plain.
function Specs.verbs(_row, _i, b)
    local verb = Semantics.verb(Specs.read(b).label)
    if verb then return (verb.danger and "danger") or (verb.main and "primary") or nil, verb.icon end
end

-- A question's buttons: the first is the way out (a quiet button with a cross), and in
-- a pair the second is the one that goes ahead (the main button, with a tick).
function Specs.ways(row, i)
    if i == 1 then return "ghost", "close" end
    if #row == 2 then return "primary", "check" end
end

-- For Specs.rows of a dialog whose last row is the way out and the way ahead (a
-- picker: Close, Apply): that row looks so, the others by what their buttons say.
function Specs.outcome(rows)
    local last = rows[#rows]
    return function(row, i, b)
        if row == last then return Specs.ways(row, i) end
        return Specs.verbs(row, i, b)
    end
end

-- What a message says about itself from the icon KOReader gave it: the tag over
-- its text, and whether it warns. Icons it does not know are plain messages.
local KINDS = {
    { "warning", { tag = _("// WARNING"), icon = "warning", danger = true } },
    { "question", { tag = _("// CONFIRM") } },
    { "info", { tag = _("// INFO") } },
}
function Specs.kind(icon_name)
    for _i, k in ipairs(KINDS) do
        if icon_name and icon_name:find(k[1], 1, true) then return k[2] end
    end
    return { tag = _("// MESSAGE") }
end

return Specs
