-- KOReader's own widgets in CyberUI's style, all at once: loads every skin
-- (each registers itself with the core) and switches them on. A skin that is
-- not listed here is not loaded: add its name to SKINS.

local Skin = {}

-- The skins, in the order they are asked about a widget.
local SKINS = { "message", "confirm", "highlightmenu", "edithighlight", "buttondialog", "keyboard", "inputdialog", "list", "dictionary", "textviewer", "numbers", "choice", "keyvalue", "sort", "progress", "qr", "network", "bookstatus" }

-- Load every skin (each registers itself with the core).
local function load()
    for _i, name in ipairs(SKINS) do require("cyberui/skin/" .. name) end
end

-- Style everything. Safe to call every time KOReader starts a reader. The
-- skins load right away in a book (one patches the reader's highlight menu),
-- and in the file browser just before the first widget is shown, so a start
-- to the home screen does not load them.
function Skin.install(now)
    local Core = require("cyberui/skin/core")
    if now then load() end
    Core.install(load)
    require("cyberui/skin/frontlight").install()
    if now then require("cyberui/skin/configdialog").install() end
end

return Skin
