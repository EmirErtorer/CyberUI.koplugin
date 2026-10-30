-- Everything the shop sells, in one table: the categories in the order the
-- shop shows them, each with its styles. A style is { id, name, price, and
-- its drawing: draw (frames, backgrounds, flairs) or build (jack-in cards) }.
-- The one that costs nothing is the default. To add a style, add an entry to
-- its category's file in cyberui/styles; nothing else changes.

local _ = require("cyberui/gettext")

return {
    { id = "frame", name = _("Frames"), styles = require("cyberui/styles/frames") },
    { id = "background", name = _("Backdrops"), styles = require("cyberui/styles/backgrounds") },
    { id = "flair", name = _("Flairs"), styles = require("cyberui/styles/flairs") },
    { id = "jackin", name = _("Jack-ins"), styles = require("cyberui/styles/jackins") },
}
