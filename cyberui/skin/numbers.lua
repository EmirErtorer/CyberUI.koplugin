-- KOReader's windows for choosing a number, two numbers, or a date and time
-- (go to page, font size, margins, brightness, a clock) in CyberUI's style: the
-- values big, with steps either side and a slider along the range, or in columns
-- for a date and a time. KOReader's own pickers keep the values and run their own
-- callbacks; the buttons under them (default value, extra choices, Close and
-- Apply) are read from the dialog, as are its title and its note.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Pickers = require("cyberui/skin/pickers")
local Specs = require("cyberui/skin/specs")

local Screen = Device.screen

local Skin = {}

-- The card: the title, KOReader's note under it, `body` (elements) and the dialog's buttons.
local function card(widget, body)
    local Dialog = require("cyberui/ui/dialog")
    local Label = require("cyberui/ui/label")
    local _ = require("cyberui/gettext")
    local rows = {}
    if type(widget.info_text) == "string" and widget.info_text ~= "" then
        rows[#rows + 1] = Label:new({ text = widget.info_text, kind = "small", color = "muted", lines = 3 })
    end
    for _i, el in ipairs(body) do rows[#rows + 1] = el end
    local buttons = Anatomy.buttons(widget)
    for _i, row in ipairs(Specs.rows(buttons, Specs.outcome(buttons))) do rows[#rows + 1] = row end
    return Dialog.card({ tag = _("// SET"), title = widget.title_text, rows = rows }, Screen:getWidth())
end

-- A skin for a picker dialog: `body(widget, redraw, popup_of)` gives the elements
-- between the title and the buttons; the dialog is drawn again after each change.
local function register(name, class, body, more)
    Core.register({
        name = name,
        matches = function(widget) return Anatomy.is(widget, class) and not widget._added_widgets and (not more or more(widget)) end,
        present = function(widget)
            local function popup_of() return widget._cyber_popup end
            local redraw
            redraw = function() Core.redraw(widget, card(widget, body(widget, redraw, popup_of))) end
            return {
                element = card(widget, body(widget, redraw, popup_of)),
                place = Core.centered,
                on_outside = function() Core.dismiss(widget) end,
                on_back = function() Core.dismiss(widget); return true end,
            }
        end,
    })
end

-- One number: the big value, its steps and slider.
register("spin", "ui/widget/spinwidget", function(widget, redraw, popup_of)
    return Pickers.line(function() return widget.value_widget end, redraw, popup_of)
end, function(widget) return widget.value_widget ~= nil end)

-- Two numbers (margins, a range), each under its own name.
register("doublespin", "ui/widget/doublespinwidget", function(widget, redraw, popup_of)
    local Label = require("cyberui/ui/label")
    local out = {}
    for _i, side in ipairs({ { "left_widget", widget.left_text }, { "right_widget", widget.right_text } }) do
        if side[2] and side[2] ~= "" then out[#out + 1] = Label:new({ text = side[2], kind = "micro", color = "muted" }) end
        for _j, el in ipairs(Pickers.line(function() return widget[side[1]] end, redraw, popup_of)) do out[#out + 1] = el end
    end
    return out
end, function(widget) return widget.left_widget ~= nil and widget.right_widget ~= nil end)

-- A date and a time: one column per part that is there.
local PARTS = { "year_widget", "month_widget", "day_widget", "hour_widget", "min_widget", "sec_widget" }
register("datetime", "ui/widget/datetimewidget", function(widget, redraw)
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    local names = { year_widget = _("YEAR"), month_widget = _("MONTH"), day_widget = _("DAY"),
        hour_widget = _("HOUR"), min_widget = _("MIN"), sec_widget = _("SEC") }
    local cols = {}
    for _i, key in ipairs(PARTS) do
        if widget[key] and widget[key].value ~= nil then
            cols[#cols + 1] = Pickers.column(function() return widget[key] end, redraw, names[key])
        end
    end
    return { Layout.Row:new({ gap = Theme.get().space.m, children = cols }) }
end, function(widget) return widget.nb_pickers ~= nil end)

return Skin
