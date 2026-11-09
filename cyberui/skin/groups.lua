-- The skins as a reader meets them: a few groups, each with its own switch in
-- System > Dialogs, so a problem with one kind of window can be switched off
-- without losing the rest. A skin that is in no group follows the main switch only.

local _ = require("cyberui/gettext")

local Groups = {}

-- { id, name, what it covers, the skins in it }
Groups.LIST = {
    { id = "notices", name = _("Notices and questions"), sub = _("Messages, questions and the small notices at the bottom"),
        skins = { "infomessage", "notification", "confirm" } },
    { id = "selection", name = _("Selected text menu"), sub = _("The menu after selecting words, and the one for a saved highlight"),
        skins = { "highlightmenu", "edithighlight" } },
    { id = "buttons", name = _("Button menus"), sub = _("The menus of buttons (long-press menus, gestures, plugins)"),
        skins = { "buttondialog" } },
    { id = "typing", name = _("Keyboard and text entry"), sub = _("The on-screen keyboard and the windows you type into"),
        skins = { "keyboard", "keypopup", "inputdialog" } },
    { id = "lists", name = _("Lists"), sub = _("Contents, bookmarks, history, details lists, sorting and the folder chooser"),
        skins = { "list", "keyvalue", "sort" } },
    { id = "dictionary", name = _("Dictionary"), sub = _("The pop-up with a word's meaning"), skins = { "dictionary" } },
    { id = "pickers", name = _("Pickers"), sub = _("Choosing a number, a date, a time or one of several"),
        skins = { "spin", "doublespin", "datetime", "choice" } },
    { id = "viewers", name = _("Viewers"), sub = _("Notes, texts, QR codes, progress and the book status page"),
        skins = { "textviewer", "qr", "progress", "bookstatus" } },
    { id = "network", name = _("Wi-Fi list"), sub = _("The list of networks"), skins = { "network" } },
    { id = "panels", name = _("Reader panels"), sub = _("The settings panel at the bottom of a book and the frontlight window"),
        skins = { "configdialog", "frontlight" } },
}

local by_skin = {}
for _i, g in ipairs(Groups.LIST) do
    for _j, name in ipairs(g.skins) do by_skin[name] = g end
end

-- The group a skin is in, or nil.
function Groups.of(skin_name)
    return by_skin[skin_name]
end

-- The setting that switches a group.
function Groups.key(group)
    return "styled_" .. group.id
end

return Groups
