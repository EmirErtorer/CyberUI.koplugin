-- KOReader describes a button as a table ({ text or text_func, callback,
-- hold_callback, enabled or enabled_func, checked_func, icon... }); this turns
-- such tables, and the rows of them a dialog holds, into CyberUI's buttons.

local Button = require("cyberui/ui/button")
local Layout = require("cyberui/ui/layout")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

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
function Specs.wide(b, variant)
    return Layout.Row:new({ children = { Specs.button(b, variant) } })
end

-- The rows of described buttons as rows of CyberUI buttons; `pick(row, i, b)`
-- may name another variant for a button, and an icon after it.
function Specs.rows(rows, pick)
    local out = {}
    for _i, row in ipairs(rows) do
        local cells = {}
        for j, b in ipairs(row) do
            local variant, icon
            if pick then variant, icon = pick(row, j, b) end
            cells[#cells + 1] = Specs.button(b, variant, icon)
        end
        out[#out + 1] = Layout.Row:new({ gap = Theme.get().space.s, children = cells })
    end
    return out
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
