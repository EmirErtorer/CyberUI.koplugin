-- The menu that appears after selecting text, drawn as a small toolbar rather
-- than a list: what you do with the selection (highlight, note, copy, extend)
-- as one row of icon tiles, what you look it up in (dictionary, Wikipedia,
-- translate, search) as another, and every other action a plain button under
-- them. The selected words are shown on top, so it is clear what the menu is
-- about. KOReader builds the buttons and runs them; actions this skin does not
-- know about are drawn plainly, so nothing KOReader or a plugin adds is lost.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Semantics = require("cyberui/skin/semantics")
local Specs = require("cyberui/skin/specs")
local Tiles = require("cyberui/skin/tiles")

local Screen = Device.screen

local Skin = {}

local pending   -- the selection while KOReader builds the menu for it: { text }
local tagged = setmetatable({}, { __mode = "k" })   -- slot functions already wrapped

-- The reader's highlight module, when a book is open.
local function highlighter()
    local ReaderUI = _G.package.loaded["apps/reader/readerui"]
    local ui = type(ReaderUI) == "table" and ReaderUI.instance
    return ui and ui.highlight
end

-- Is this the menu KOReader made for the selection? Asked by what KOReader keeps, so the menu is
-- drawn so even when this KOReader builds it by another path than the one hooked below.
function Skin.isHighlightDialog(widget)
    local h = highlighter()
    return h ~= nil and h.highlight_dialog == widget
end

-- The selection the menu is for, when it was not noted as the menu was built.
function Skin.selection()
    local h = highlighter()
    return { text = h and h.selected_text and h.selected_text.text }
end

-- The card for the menu `dialog` made for `selection`.
local function card(dialog, selection)
    local Dialog = require("cyberui/ui/dialog")
    local _ = require("cyberui/gettext")
    local groups, rest = { act = {}, lookup = {} }, {}
    for _i, line in ipairs(Anatomy.buttons(dialog)) do
        for _j, b in ipairs(line) do
            local sem = Semantics.highlight(b.sem) or (b.text and Semantics.highlightByText(b.text))
            if sem then
                local g = groups[sem.group]
                g[#g + 1] = { b, sem }
            else
                rest[#rest + 1] = b
            end
        end
    end
    local rows = {}
    if #groups.act > 0 then rows[#rows + 1] = Tiles.row(groups.act) end
    if #groups.lookup > 0 then rows[#rows + 1] = Tiles.row(groups.lookup) end
    -- anything else: plain buttons, two to a line
    local lines = {}
    for i = 1, #rest, 2 do lines[#lines + 1] = { rest[i], rest[i + 1] } end
    for _i, r in ipairs(Specs.rows(lines)) do rows[#rows + 1] = r end
    local words = selection and selection.text and selection.text:gsub("%s+", " ") or ""
    if #words > 90 then words = words:sub(1, 90):gsub("[\128-\191]*$", "") .. "..." end
    return Dialog.card({ tag = _("// SELECTION"), text = words ~= "" and ("\u{201C}" .. words .. "\u{201D}") or nil, lines = 2, rows = rows }, Screen:getWidth())
end

Core.register({
    name = "highlightmenu",
    -- tell each slot's button where it came from, and the skin which selection the menu is for
    install = function()
        local ReaderHighlight = require("apps/reader/modules/readerhighlight")
        local show = ReaderHighlight.onShowHighlightMenu
        ReaderHighlight.onShowHighlightMenu = function(self, ...)
            for slot, fn in pairs(self._highlight_buttons or {}) do
                if not tagged[fn] then
                    local wrapped = function(...)
                        local b = fn(...)
                        if type(b) == "table" then b.sem = slot end
                        return b
                    end
                    tagged[wrapped] = true
                    self._highlight_buttons[slot] = wrapped
                end
            end
            pending = { text = self.selected_text and self.selected_text.text }
            local ok, result = pcall(show, self, ...)
            pending = nil
            if not ok then error(result, 0) end
            return result
        end
    end,
    matches = function(widget)
        return (pending ~= nil or Skin.isHighlightDialog(widget)) and type(widget.buttons) == "table" and widget.buttontable ~= nil and not widget._added_widgets
    end,
    present = function(dialog)
        local selection = pending or Skin.selection()
        return {
            element = card(dialog, selection),
            place = require("cyberui/skin/buttondialog").placer(dialog),
            on_outside = function() Core.dismiss(dialog) end,
        }
    end,
})

return Skin
