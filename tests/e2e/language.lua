-- CyberUI in the language KOReader is set to (setup_language.py): the home screen
-- and the log in that language, days and months in it too, and a translated text
-- reaching the real screen. CYBERUI_LANG says which.
local H = ...
local lang = os.getenv("CYBERUI_LANG") or "de"
local I18n = require("cyberui/gettext")

H.step(3, function()
    H.check(I18n.language() == lang, "CyberUI took KOReader's language: " .. tostring(I18n.language()))
    H.check(H.find(I18n("COLLECTIONS")) ~= nil, "the home screen has the translated Collections button")
    H.check(H.find("COLLECTIONS") == nil or I18n("COLLECTIONS") == "COLLECTIONS", "and not the English one")
    H.shot("home-" .. lang)
    H.app().go("history")
end)
H.step(1, function()
    H.shot("log-" .. lang)
    H.app().go("settings")
    H.app().current().section = "about"
    H.app().update()
end)
H.step(1, function()
    H.check(H.find(I18n("Language")) ~= nil, "the About page names the language")
    H.shot("about-" .. lang)
end)
