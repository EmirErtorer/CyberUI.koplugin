-- KOReader's own widgets in CyberUI's style, all at once: loads every skin
-- (each registers itself with the core) and switches them on. A skin that is
-- not listed here is not loaded: add its name to SKINS.

local Skin = {}

-- The skins, in the order they are asked about a widget.
local SKINS = { "message", "confirm", "highlightmenu", "edithighlight", "buttondialog", "keyboard", "inputdialog", "list", "dictionary", "textviewer", "numbers", "choice", "keyvalue" }

-- Style everything. Safe to call every time KOReader starts a reader.
function Skin.install()
    local Core = require("cyberui/skin/core")
    for _i, name in ipairs(SKINS) do require("cyberui/skin/" .. name) end
    Core.install()
    require("cyberui/skin/frontlight").install()
    require("cyberui/skin/configdialog").install()
end

return Skin
