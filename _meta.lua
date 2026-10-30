-- Plugin description shown in KOReader's plugin manager.

local _ = require("cyberui/gettext")
return {
    fullname = _("CyberUI"),
    description = _([[A fast, cyberpunk-styled home screen for KOReader with a library browser, collections, reading stats and switchable colour themes.]]),
    version = require("cyberui/version"),
}
