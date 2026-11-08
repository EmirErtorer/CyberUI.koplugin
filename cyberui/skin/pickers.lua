-- The parts of the number, time and date pickers: KOReader keeps a value in a
-- NumberPickerWidget (asked through `get`, since some pickers build a new one
-- at every change) and these draw it as a big value with steps either side and
-- a slider along the range, or as a column to step up and down. Changing a value
-- goes through KOReader's picker (its own update runs, so whatever KOReader does
-- on a change, a linked day count for one, still happens); nothing here knows
-- which dialog it is for.

local Core = require("cyberui/skin/core")
local UIManager = require("ui/uimanager")

local Pickers = {}

-- The shown text of the picker's value, in KOReader's own format and unit.
function Pickers.text(vw)
    local text
    if vw.value_table then text = tostring(vw.value_table[vw.value_index]) else text = string.format(vw.precision or "%02d", vw.value) end
    if vw.unit and vw.unit ~= "" then text = text .. (vw.unit == "\u{B0}" and "" or "\u{202F}") .. vw.unit end
    return text
end

-- Go through KOReader's picker update (it asks for refreshes and calls the
-- dialog's own change hook) without those refreshes: the popup draws.
local function sync(vw)
    Core.quietly(vw.update, vw)
end

-- Step the picker `by` times its step (or hold step), then redraw.
function Pickers.step(get, by, hold, redraw)
    local vw = get()
    Core.quietly(function()
        vw.value = vw:changeValue(by * ((hold and vw.value_hold_step) or vw.value_step or 1))
        vw:update()
    end)
    redraw()
end

-- A number of steps along the picker's range as a position (table pickers
-- go by their index), and back: what a slider sets and shows.
local function span(vw)
    if vw.value_table then return 1, #vw.value_table, vw.value_index or 1 end
    return vw.value_min, vw.value_max, vw.value
end

-- Put a value on the picker's step grid and in its range, without KOReader's update.
local function place(vw, v)
    if vw.value_table then
        vw.value_index = math.max(1, math.min(#vw.value_table, math.floor(v + 0.5)))
        vw.value = vw.value_table[vw.value_index]
        return
    end
    local lo, step = vw.value_min, vw.value_step or 1
    v = lo + math.floor((v - lo) / step + 0.5) * step
    vw.value = math.max(lo, math.min(vw.value_max, v))
end

-- A picker as a line: a step down and a step up either side of the big value
-- (a longer step in a small button beyond each), and a slider under it when
-- the range is wide enough. `redraw` shows the whole dialog again, `popup_of()` is
-- the popup to repaint while a slider is dragged.
function Pickers.line(get, redraw, popup_of)
    local Button = require("cyberui/ui/button")
    local Host = require("cyberui/host")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Slider = require("cyberui/ui/slider")
    local Theme = require("cyberui/theme")
    local th = Theme.get()
    local vw = get()
    local side = th.size.touch
    local function stepper(label, by, hold, variant)
        return Button:new({ label = label, kind = hold and "label" or "title", variant = variant, width = hold and Theme.px(64) or side + Theme.px(12),
            on_tap = function() Pickers.step(get, by, hold, redraw) end,
            on_hold = (not hold) and function() Pickers.step(get, by, true, redraw) end or nil })
    end
    local value = Label:new({ text_fn = function() return Pickers.text(get()) end, kind = "display", align = "center", grow = true })
    local hold = (vw.value_hold_step or 0) > (vw.value_step or 1) and not vw.value_table
    local row = { stepper("\u{2212}", -1, false, "soft"), value, stepper("+", 1, false, "soft") }
    if hold then
        table.insert(row, 1, stepper("\u{2212}" .. vw.value_hold_step, -1, true, "chip"))
        row[#row + 1] = stepper("+" .. vw.value_hold_step, 1, true, "chip")
    end
    local out = { Layout.Row:new({ gap = th.space.s, children = row }) }
    local lo, hi, at = span(vw)
    if hi - lo >= 4 then
        local slider, finish
        finish = function()
            sync(get())
            redraw()
        end
        slider = Slider:new({ min = lo, max = hi, value = at, segments = 24,
            on_change = function(v) place(get(), v) end,
            on_redraw = function(el)
                local popup = popup_of()
                if popup then UIManager:setDirty(popup, "ui", Host.box(el):combine(Host.box(value))) end
            end })
        local tap, drag = slider.on_tap, slider.on_drag
        slider.on_tap = function(s) tap(s); finish() end
        slider.on_drag = function(s, dx, dy, phase)
            drag(s, dx, dy, phase)
            if phase == "end" then finish() end
        end
        out[#out + 1] = slider
    end
    return out
end

-- A picker as a column: the label, a step up, the value, a step down (a
-- hold takes the longer step).
function Pickers.column(get, redraw, label)
    local Button = require("cyberui/ui/button")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Panel = require("cyberui/ui/panel")
    local Theme = require("cyberui/theme")
    local th = Theme.get()
    local function arrow(icon, by)
        -- in a row of its own, so that it keeps its height in the column
        return Layout.Row:new({ children = { Button:new({ icon = icon, variant = "soft", grow = true,
            on_tap = function() Pickers.step(get, by, false, redraw) end,
            on_hold = function() Pickers.step(get, by, true, redraw) end }) } })
    end
    return Layout.Column:new({ gap = th.space.s, grow = true, children = {
        Label:new({ text = label, kind = "micro", color = "muted", align = "center" }),
        arrow("up", 1),
        Panel:new({ shape = "frame", pad = { th.space.m, th.space.xs }, child =
            Label:new({ text = Pickers.text(get()), kind = "display", align = "center" }) }),
        arrow("down", -1),
    } })
end

return Pickers
