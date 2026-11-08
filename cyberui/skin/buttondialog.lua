-- KOReader's button dialogs in CyberUI's style: the highlight menu, the hold
-- menus of lists, gesture and dispatcher menus, and the dialogs plugins make
-- with ButtonDialog. The rows of buttons are read from the dialog itself
-- (see Specs), so what KOReader or a plugin puts in them is drawn without a
-- word about it here. A dialog that holds more than buttons and a title (it
-- was given extra widgets) is left as KOReader draws it.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Specs = require("cyberui/skin/specs")

local Screen = Device.screen

local Skin = {}

-- Where a floating dialog sits: centred across, and down the screen where
-- KOReader's own dialog would be (its `anchor`: the middle by default, near the
-- top or bottom, or by the selected text). The anchor asks the dialog for its
-- height, which the unpainted original cannot give, so it is told the card's.
function Skin.placer(dialog)
    return function(el)
        local x, y = Core.centered(el)
        if type(dialog.anchor) == "function" then
            dialog.getContentSize = function() return { w = el.w, h = el.h } end
            local ok, anchor, pop_down = pcall(dialog.anchor)
            if ok and type(anchor) == "table" and anchor.y then
                y = pop_down and anchor.y or anchor.y - el.h
                y = math.max(0, math.min(y, Screen:getHeight() - el.h))
            end
        end
        return x, y
    end
end

-- The card for one page of the dialog's buttons (all of them when they fit).
local function card(dialog, page)
    local Dialog = require("cyberui/ui/dialog")
    local rows = Anatomy.buttons(dialog)
    local per = Dialog.rowsPerPage(Screen:getHeight())
    local pages = math.max(1, math.ceil(#rows / per))
    page = math.max(1, math.min(page or 1, pages))
    local shown = {}
    for i = (page - 1) * per + 1, math.min(page * per, #rows) do shown[#shown + 1] = rows[i] end
    local built = Specs.rows(shown, Specs.verbs)
    if pages > 1 then
        built[#built + 1] = Dialog.pager(page, pages, function(p) Core.redraw(dialog, card(dialog, p)) end)
    end
    return Dialog.card({ title = dialog.title, rows = built }, Screen:getWidth())
end

Core.register({
    name = "buttondialog",
    matches = function(widget)
        return type(widget.buttons) == "table" and widget.buttontable ~= nil and not widget._added_widgets
    end,
    present = function(dialog)
        return {
            element = card(dialog),
            place = Skin.placer(dialog),
            on_outside = function() Core.dismiss(dialog) end,
        }
    end,
})

return Skin
