-- KOReader's window for choosing one of several things (sort by, a mode, the
-- keyboard's language) in CyberUI's style: a list of choices with the chosen one ticked, a
-- tap on one chooses it through KOReader's own radio table, and the dialog's
-- buttons (Close, Apply, and any extra) under it. A long list is paged.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Specs = require("cyberui/skin/specs")

local Screen = Device.screen

local Skin = {}

-- The windows that choose one of a list, by KOReader's class.
local CLASSES = { "ui/widget/radiobuttonwidget", "ui/widget/keyboardlayoutdialog" }

local function takes(widget)
    for _i, class in ipairs(CLASSES) do
        if Anatomy.is(widget, class) then return true end
    end
    return false
end

-- KOReader's table of radio buttons inside the dialog, or nil.
local function radios(widget)
    if widget.radio_button_table then return widget.radio_button_table end
    return Anatomy.find(widget, function(t) return t.radio_buttons_layout ~= nil and t.checkButton ~= nil end)
end

-- What the window is called: the title it was given, else the one in its title bar.
local function titleOf(widget)
    return widget.title_text or (widget.title_bar and widget.title_bar.title) or ""
end

-- The card for one page of the choices.
local function card(widget, state)
    local Dialog = require("cyberui/ui/dialog")
    local Label = require("cyberui/ui/label")
    local _ = require("cyberui/gettext")
    local table_ = radios(widget)
    local choices = {}
    for _i, row in ipairs(table_.radio_buttons_layout) do
        for _j, button in ipairs(row) do choices[#choices + 1] = button end
    end
    local per = Dialog.rowsPerPage(Screen:getHeight()) - 1
    local pages = math.max(1, math.ceil(#choices / per))
    if not state.page then
        -- open on the page that has the chosen one
        for i, button in ipairs(choices) do
            if button.checked then state.page = math.ceil(i / per); break end
        end
    end
    state.page = math.max(1, math.min(state.page or 1, pages))
    local rows = {}
    if type(widget.info_text) == "string" and widget.info_text ~= "" then
        rows[#rows + 1] = Label:new({ text = widget.info_text, kind = "small", color = "muted", lines = 3 })
    end
    for i = (state.page - 1) * per + 1, math.min(state.page * per, #choices) do
        local button = choices[i]
        rows[#rows + 1] = Dialog.option({ label = tostring(button.text or ""), checked = button.checked }, false, function()
            table_:checkButton(button)
            state.redraw()
        end)
    end
    if pages > 1 then
        rows[#rows + 1] = Dialog.pager(state.page, pages, function(p)
            state.page = p
            state.redraw()
        end)
    end
    local buttons = Anatomy.buttons(widget)
    for _i, row in ipairs(Specs.rows(buttons, Specs.outcome(buttons))) do rows[#rows + 1] = row end
    return Dialog.card({ tag = _("// CHOOSE"), title = titleOf(widget), rows = rows }, Screen:getWidth())
end

Core.register({
    name = "choice",
    matches = function(widget)
        return takes(widget) and not widget._added_widgets and radios(widget) ~= nil
    end,
    present = function(widget)
        local state = {}
        state.redraw = function() Core.redraw(widget, card(widget, state)) end
        return {
            element = card(widget, state),
            place = Core.centered,
            on_outside = function() Core.dismiss(widget) end,
            on_back = function() Core.dismiss(widget); return true end,
        }
    end,
})

return Skin
