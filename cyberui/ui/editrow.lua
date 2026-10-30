-- The line of an editing screen (top bar, launcher): what it is on the left,
-- small icon buttons for its moves on the right, a divider underneath.

local Button = require("cyberui/ui/button")
local Deco = require("cyberui/ui/deco")
local Layout = require("cyberui/ui/layout")
local Theme = require("cyberui/theme")

local EditRow = {}

-- A small icon button for a row; `enabled` false greys it out.
function EditRow.button(icon, on_tap, enabled)
    return Button:new({ icon = icon, variant = "icon", width = Theme.get().size.touch, height = Theme.px(40),
        disabled = enabled == false, on_tap = enabled ~= false and on_tap or nil })
end

-- One line: the `kids` (elements) then the `buttons`.
function EditRow.line(kids, buttons)
    local th = Theme.get()
    local all = {}
    for _i, k in ipairs(kids) do all[#all + 1] = k end
    for _i, b in ipairs(buttons or {}) do all[#all + 1] = b end
    return Layout.Column:new({ children = {
        Layout.Row:new({ gap = th.space.m, pad = { Theme.px(3), 0 }, children = all }),
        Deco.Divider:new({}),
    } })
end

return EditRow
