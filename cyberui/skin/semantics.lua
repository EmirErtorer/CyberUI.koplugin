-- What KOReader's own actions mean, where a skin can use it. A button in the
-- highlight menu comes from a named slot ("03_copy"); the name says what it is,
-- and this table gives it an icon and a group. A slot that is not listed (one a
-- plugin adds, or one KOReader adds later) simply has no entry: it is drawn
-- plainly, as any other button, so nothing here has to keep up.

local gettext = require("gettext")
local _ = require("cyberui/gettext")

local Semantics = {}

-- A button's text as KOReader writes it in the reader's language: its own
-- catalogue is asked for the English text (and context), so the match holds
-- in every language, and simply fails when KOReader words something differently.
local function koreader(msgid, ctx)
    return ctx and gettext.pgettext(ctx, msgid) or gettext(msgid)
end

-- By the name of a highlight-menu slot (without its number): the icon and the
-- group it belongs to ("act": what you do with the selection, "lookup": what
-- you look it up in).
local HIGHLIGHT = {
    select = { icon = "move", group = "act" },
    highlight = { icon = "pen", group = "act" },
    add_note = { icon = "notes", group = "act" },
    copy = { icon = "files", group = "act" },
    dictionary = { icon = "book", group = "lookup" },
    wikipedia = { icon = "library", group = "lookup" },
    translate = { icon = "network", group = "lookup" },
    search = { icon = "search", group = "lookup" },
}

-- The entry for a slot such as "03_copy", or nil when it is not known.
function Semantics.highlight(slot)
    local name = type(slot) == "string" and slot:match("^%d+_(.+)$")
    return name and HIGHLIGHT[name] or nil
end

-- Verbs that appear on KOReader's button dialogs (the hold menu of a book, its
-- gesture and settings menus): what each looks like. They are matched by KOReader's own
-- English word, in the reader's language through KOReader's catalogue, so an
-- unlisted or reworded button is simply plain.
local VERBS = {
    { msgid = "Open", icon = "forward" },
    { msgid = "Rename", icon = "edit" },
    { msgid = "Move", icon = "move" },
    { msgid = "Book information", icon = "eye" },
    { msgid = "Collections", icon = "collections" },
    { msgid = "Search", icon = "search" },
    { msgid = "Settings", icon = "settings" },
    { msgid = "Delete", icon = "trash", danger = true },
    { msgid = "Remove", icon = "trash", danger = true },
    { msgid = "Reset settings", icon = "restore", danger = true },
    { msgid = "Clear", icon = "trash", danger = true },
    { msgid = "Edit note", icon = "edit", main = true },
    { msgid = "Delete note", icon = "trash", danger = true },
    { msgid = "Delete highlight", icon = "trash", danger = true },
    { msgid = "Highlight menu", icon = "menu" },
    { msgid = "Close", icon = "close" },
}

-- What a button of a dialog looks like from its text: { icon, danger }, or nil when unknown.
function Semantics.verb(text)
    for _i, v in ipairs(VERBS) do
        if text == koreader(v.msgid, v.ctx) then return v end
    end
    return nil
end

-- The buttons of KOReader's dialog for a saved highlight (tapped on the page),
-- found by their text as KOReader writes it: { text or glyph, context, then
-- what they are }. The ones drawn as symbols are matched by the symbol; the four
-- that move the highlight's edges keep that symbol (it shows the highlight
-- growing or shrinking at one end), which is why they carry no icon.
local EDIT = {
    { glyph = "\u{F48E}", id = "delete", icon = "trash", danger = true, label = _("Delete") },
    { msgid = "Style", ctx = "Highlight", id = "style", icon = "edit" },
    { msgid = "Color", ctx = "Highlight", id = "color", icon = "wheel" },
    { msgid = "Note", id = "note", icon = "notes" },
    { msgid = "Details", id = "details", icon = "eye" },
    { glyph = "\u{2026}", id = "more", icon = "menu", label = _("MORE") },
    { glyph = "\u{25C1}\u{2592}\u{2592}", symbol = "\u{25C1}\u{2592}\u{2592}", id = "start_earlier", edge = true },
    { glyph = "\u{25B7}\u{2613}\u{2592}", symbol = "\u{25B7}\u{2613}\u{2592}", id = "start_later", edge = true },
    { glyph = "\u{2592}\u{2613}\u{25C1}", symbol = "\u{2592}\u{2613}\u{25C1}", id = "end_earlier", edge = true },
    { glyph = "\u{2592}\u{2592}\u{25B7}", symbol = "\u{2592}\u{2592}\u{25B7}", id = "end_later", edge = true },
}

-- What a button of that dialog is, from its text, or nil when it is not one KOReader names.
function Semantics.edit(text)
    for _i, e in ipairs(EDIT) do
        if (e.glyph and text == e.glyph) or (e.msgid and text == koreader(e.msgid, e.ctx)) then return e end
    end
    return nil
end

return Semantics
