-- KOReader's dialog for a highlight already on the page (tap it): what it
-- offers is sorted by what it does. Change how it looks (style, colour), add
-- or read about it (note, details) as icon tiles; move where it starts and ends
-- with KOReader's own symbols for it (they show the highlight growing or
-- shrinking at an end, which says it better than words) under START and END;
-- delete as a button in the warning colour with its name, "more" beside it.
-- The buttons are recognised by KOReader's own words for them, so an action
-- not recognised is still shown, plainly, under these.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Semantics = require("cyberui/skin/semantics")
local Specs = require("cyberui/skin/specs")
local Tiles = require("cyberui/skin/tiles")

local Screen = Device.screen

local Skin = {}

local pending   -- the highlight while KOReader builds the dialog for it: { text }

-- Sort the dialog's buttons: { tools, edges, delete, more, rest }, each button with what it is.
local function sort(dialog)
    local out = { tools = {}, edges = {}, rest = {} }
    for _i, line in ipairs(Anatomy.buttons(dialog)) do
        for _j, b in ipairs(line) do
            local sem = Semantics.edit(Specs.read(b).label)
            if not sem then out.rest[#out.rest + 1] = b
            elseif sem.edge then out.edges[#out.edges + 1] = { b, sem }
            elseif sem.id == "delete" then out.delete = { b, sem }
            elseif sem.id == "more" then out.more = { b, sem }
            else out.tools[#out.tools + 1] = { b, sem } end
        end
    end
    return out
end

-- Is this the dialog of a saved highlight? (It has KOReader's trash button and its four edge buttons.)
local function isEditDialog(dialog)
    local sorted = sort(dialog)
    return sorted.delete ~= nil and #sorted.edges == 4
end

-- The button with the name of what it does in place of KOReader's symbol (a trash can).
local function named(b, sem)
    return setmetatable({ text = sem.label, text_func = false }, { __index = b })
end

local function card(dialog, highlight)
    local Dialog = require("cyberui/ui/dialog")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    local sorted = sort(dialog)
    local rows = {}
    if #sorted.tools > 0 then rows[#rows + 1] = Tiles.row(sorted.tools) end
    -- the highlight's edges: START over the first two symbols, END over the last two
    local symbols = {}
    for _i, p in ipairs(sorted.edges) do symbols[#symbols + 1] = Tiles.symbol(p[1], p[2]) end
    rows[#rows + 1] = Layout.Row:new({ gap = Theme.get().space.s, children = {
        Label:new({ text = _("START"), kind = "micro", color = "muted", align = "center", grow = true }),
        Label:new({ text = _("END"), kind = "micro", color = "muted", align = "center", grow = true }),
    } })
    rows[#rows + 1] = Layout.Row:new({ gap = Theme.get().space.s, children = symbols })
    -- delete in the warning look, more beside it
    local last = { Specs.button(named(sorted.delete[1], sorted.delete[2]), "danger", "trash") }
    if sorted.more then last[#last + 1] = Specs.button(named(sorted.more[1], sorted.more[2]), nil, "menu") end
    rows[#rows + 1] = Layout.Row:new({ gap = Theme.get().space.s, children = last })
    local plain = {}
    for i = 1, #sorted.rest, 2 do plain[#plain + 1] = { sorted.rest[i], sorted.rest[i + 1] } end
    for _i, r in ipairs(Specs.rows(plain)) do rows[#rows + 1] = r end
    local words = highlight and highlight.text and highlight.text:gsub("%s+", " ") or ""
    if #words > 70 then words = words:sub(1, 70):gsub("[\128-\191]*$", "") .. "..." end
    return Dialog.card({ tag = _("// HIGHLIGHT"), text = words ~= "" and ("\u{201C}" .. words .. "\u{201D}") or nil, lines = 1, rows = rows }, Screen:getWidth())
end

Core.register({
    name = "edithighlight",
    -- tell the skin which highlight KOReader is building the dialog for
    install = function()
        local ReaderHighlight = require("apps/reader/modules/readerhighlight")
        local show = ReaderHighlight.showHighlightDialog
        ReaderHighlight.showHighlightDialog = function(self, index, ...)
            local item = self.ui and self.ui.annotation and self.ui.annotation.annotations[index]
            pending = { text = item and item.text }
            local ok, result = pcall(show, self, index, ...)
            pending = nil
            if not ok then error(result, 0) end
            return result
        end
    end,
    matches = function(widget)
        return type(widget.buttons) == "table" and widget.buttontable ~= nil and not widget._added_widgets and isEditDialog(widget)
    end,
    present = function(dialog)
        return {
            element = card(dialog, pending),
            place = require("cyberui/skin/buttondialog").placer(dialog),
            on_outside = function() Core.dismiss(dialog) end,
        }
    end,
})

return Skin
