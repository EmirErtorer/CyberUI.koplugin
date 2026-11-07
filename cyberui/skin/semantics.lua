-- What KOReader's own actions mean, where a skin can use it. A button in the
-- highlight menu comes from a named slot ("03_copy"); the name says what it is,
-- and this table gives it an icon and a group. A slot that is not listed (one a
-- plugin adds, or one KOReader adds later) simply has no entry: it is drawn
-- plainly, as any other button, so nothing here has to keep up.

local Semantics = {}

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

return Semantics
