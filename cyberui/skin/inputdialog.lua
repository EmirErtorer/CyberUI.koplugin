-- KOReader's input dialogs in CyberUI's style (editing a note, naming a
-- bookmark, "go to page", searching in a book, the dictionary lookup, a
-- password): a card with the title, the text in a field, and every button the
-- dialog has. The text stays in KOReader's own input box, which the keyboard
-- (see the keyboard skin) types into; the field only shows it and the cursor,
-- and a tap on it moves the cursor through KOReader. The card sits in the
-- room the keyboard leaves, as KOReader's does. A dialog with several fields
-- or extra widgets is left as KOReader draws it.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Specs = require("cyberui/skin/specs")
local UIManager = require("ui/uimanager")
local _ = require("cyberui/gettext")

local Screen = Device.screen

local Skin = {}

-- How tall the keyboard drawn for the dialog is (0 when there is none).
local function keyboardHeight(inp)
    local kb = inp and inp.keyboard
    local popup = kb and kb._cyber_popup
    return popup and popup:box().h or 0
end

-- The card for the dialog as it is now.
local function card(dialog, field_state)
    local Dialog = require("cyberui/ui/dialog")
    local Button = require("cyberui/ui/button")
    local Host = require("cyberui/host")
    local InputField = require("cyberui/ui/inputfield")
    local Text = require("cyberui/gfx/text")
    local Theme = require("cyberui/theme")
    local inp = dialog._input_widget
    local free = Screen:getHeight() - keyboardHeight(inp)
    local rows = {}
    local lines = 1
    if dialog.allow_newline or dialog.fullscreen then
        -- a text of several lines: as many as the room allows, a few by default
        local room = math.floor((free - Theme.px(330)) / Text.height("mono"))
        lines = dialog.fullscreen and math.max(3, room) or math.max(2, math.min(5, room))
    end
    local field
    field = InputField:new({
        state = field_state, lines = lines, hint = inp.hint, readonly = dialog.readonly,
        get = function() return inp.charlist or {}, inp.charpos, inp.text_type == "password" end,
        on_caret = function(at)
            if inp.moveCursorToCharPos then inp:moveCursorToCharPos(at) end
            if inp.onShowKeyboard and not (inp.isKeyboardVisible and inp:isKeyboardVisible()) then inp:onShowKeyboard() end
            local popup = dialog._cyber_popup
            if popup then UIManager:setDirty(popup, "ui", Host.box(field)) end
        end,
    })
    dialog._cyber_field = field
    rows[#rows + 1] = field
    local toggle = inp._password_toggle
    if toggle then
        rows[#rows + 1] = Button:new({ label = toggle.text, icon = toggle.checked and "check" or nil, variant = "chip",
            on_tap = function() toggle:onTapCheckButton(); Core.redraw(dialog, card(dialog, field_state)) end })
    end
    for _i, row in ipairs(Specs.rows(Anatomy.buttons(dialog))) do rows[#rows + 1] = row end
    local screen_w = Screen:getWidth()
    return Dialog.card({ tag = _("// INPUT"), title = dialog.title, text = dialog.description,
        lines = 3, rows = rows }, screen_w)
end

-- A tap outside the card hides the keyboard, as in KOReader (the dialog stays).
local function hideKeyboard(dialog)
    local inp = dialog._input_widget
    if inp and inp.isKeyboardVisible and inp:isKeyboardVisible() and dialog.onCloseKeyboard and not dialog.deny_keyboard_hiding then
        dialog:onCloseKeyboard()
    end
end

Core.register({
    name = "inputdialog",
    -- KOReader's input box says when its text changed (typing, deleting, moving the cursor)
    install = function()
        local InputText = require("ui/widget/inputtext")
        local init_text_box = InputText.initTextBox
        InputText.initTextBox = function(self, ...)
            local r = init_text_box(self, ...)
            if self._cyber_changed then self._cyber_changed() end
            return r
        end
    end,
    matches = function(widget)
        return Anatomy.is(widget, "ui/widget/inputdialog") and widget._input_widget ~= nil
            and not widget._added_widgets and not widget.input_fields
    end,
    present = function(dialog)
        local state = {}
        local function redraw() Core.redraw(dialog, card(dialog, state)) end
        dialog._cyber_relayout = redraw
        -- every change KOReader makes to the text shows in the field
        local inp = dialog._input_widget
        inp._cyber_changed = function()
            local popup, field = dialog._cyber_popup, dialog._cyber_field
            if popup and field and field.x then
                UIManager:setDirty(popup, "ui", require("cyberui/host").box(field))
            end
        end
        return {
            element = card(dialog, state),
            place = function(el)
                local free = Screen:getHeight() - keyboardHeight(dialog._input_widget)
                return math.floor((Screen:getWidth() - el.w) / 2), math.max(0, math.floor((free - el.h) / 2))
            end,
            on_outside = function() hideKeyboard(dialog) end,
            on_back = function() if dialog.onCloseDialog then dialog:onCloseDialog() else Core.dismiss(dialog) end return true end,
            on_close = function() dialog._cyber_relayout, dialog._cyber_field = nil, nil end,
        }
    end,
})

return Skin
