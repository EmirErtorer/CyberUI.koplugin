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

local Screen = Device.screen

local Skin = {}

local pending   -- the selection while KOReader builds the menu for it: { text }
local tagged = setmetatable({}, { __mode = "k" })   -- slot functions already wrapped

-- One action as a tile: its icon over its name; a tile that cannot be used is plain and takes no taps.
local function tile(b)
    local Icon = require("cyberui/ui/icon")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Panel = require("cyberui/ui/panel")
    local Theme = require("cyberui/theme")
    local th = Theme.get()
    local s = Specs.read(b)
    local usable = s.enabled and s.callback ~= nil
    return Panel:new({
        shape = usable and "chamfer" or "frame", corners = "r", cut = "cut_small", fill = usable and "soft" or nil, line = usable and "soft" or "line",
        pad = { th.space.m, th.space.xs }, grow = true,
        on_tap = usable and s.callback or nil, on_hold = s.enabled and s.hold_callback or nil,
        child = Layout.Column:new({ gap = th.space.xs, align = "center", children = {
            Icon:new({ name = b.sem.icon, size = 26, color = usable and "ink" or "muted", width = Theme.px(40) }),
            Label:new({ text = s.label, kind = "micro", color = usable and "ink" or "muted", align = "center", lines = 2 }),
        } }),
    })
end

-- The buttons of one group as a row of tiles.
local function row(buttons)
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    local tiles = {}
    for _i, b in ipairs(buttons) do tiles[#tiles + 1] = tile(b) end
    return Layout.Row:new({ gap = Theme.get().space.s, children = tiles })
end

-- The card for the menu `dialog` made for `selection`.
local function card(dialog, selection)
    local Dialog = require("cyberui/ui/dialog")
    local _ = require("cyberui/gettext")
    local groups, rest = { act = {}, lookup = {} }, {}
    for _i, line in ipairs(Anatomy.buttons(dialog)) do
        for _j, b in ipairs(line) do
            local sem = Semantics.highlight(b.sem)
            if sem then
                b.sem = sem
                local g = groups[sem.group]
                g[#g + 1] = b
            else
                rest[#rest + 1] = b
            end
        end
    end
    local rows = {}
    if #groups.act > 0 then rows[#rows + 1] = row(groups.act) end
    if #groups.lookup > 0 then rows[#rows + 1] = row(groups.lookup) end
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
        return pending ~= nil and type(widget.buttons) == "table" and widget.buttontable ~= nil and not widget._added_widgets
    end,
    present = function(dialog)
        local selection = pending
        return {
            element = card(dialog, selection),
            place = require("cyberui/skin/buttondialog").placer(dialog),
            on_outside = function() Core.dismiss(dialog) end,
        }
    end,
})

return Skin
