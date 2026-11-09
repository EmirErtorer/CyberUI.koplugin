-- The switch for KOReader's widgets in CyberUI's style (System > Home > KOReader dialogs): on from the start,
-- tapped in the real settings screen, it takes effect on the next widget at once, and it leaves the menu's own switch alone.
local H = ...
local UIManager = require("ui/uimanager")
local Settings = require("cyberui/settings")
local S = 1

local function styled(widget) return widget._cyber_popup ~= nil end
local function gone(widget)
    for _i, e in ipairs(UIManager._window_stack) do if e.widget == widget or e.widget == widget._cyber_popup then return false end end
    return true
end

-- Page through the settings screen until the row with this title is shown.
local function reveal(title)
    local screen = H.app().current()
    for page = 1, 6 do
        screen.page = page
        H.app().update()
        UIManager:forceRePaint()   -- the tree gets its places when it is painted
        if H.find(title) then return true end
    end
end

-- Tap the switch in the row with this title.
local function tapSwitch(title)
    local row = reveal(title) and H.find(title)
    if not row then H.check(false, "found the '" .. title .. "' row"); return end
    local mid = row.y + row.h / 2
    local best, gap
    local seen = {}
    H.findWhere(function(el)
        if not seen[el] and el.on ~= nil and el.on_tap and el.naturalWidth then
            seen[el] = true
            local d = math.abs(el.y + el.h / 2 - mid)
            if not gap or d < gap then best, gap = el, d end
        end
        return false
    end)
    if best and gap < 80 then H.tapAt(best.x + best.w / 2, best.y + best.h / 2) else H.check(false, "found the switch next to '" .. title .. "'") end
end

local info, note, dialog

-- by default the styled look is on
H.step(S, function()
    H.check(Settings.get("styled_widgets", true) == true, "on by default")
    info = require("ui/widget/infomessage"):new({ text = "Saved to your library.", timeout = 60 })
    UIManager:show(info)
end)
H.step(S, function()
    H.check(styled(info), "a notice is in CyberUI's style")
    UIManager:close(info)
    H.app().go("settings")
    H.app().current().section = "home"
    H.app().update()
end)

-- off, in the settings screen
H.step(S, function()
    H.check(reveal("KOReader dialogs"), "the settings list the switch")
    H.shot("tg1-settings")
    tapSwitch("KOReader dialogs")
end)
H.step(S, function()
    H.check(Settings.get("styled_widgets", true) == false, "tapping it turns it off")
    H.check(Settings.get("styled_menu", true) == true, "the menu's own switch is untouched")
    info = require("ui/widget/infomessage"):new({ text = "Saved to your library.", timeout = 60 })
    UIManager:show(info)
    dialog = require("ui/widget/buttondialog"):new({ title = "Book options", buttons = { { { text = "Open", callback = function() end } } } })
    UIManager:show(dialog)
    note = require("ui/widget/confirmbox"):new({ text = "Delete this highlight?", ok_text = "Delete it" })
    UIManager:show(note)
end)
H.step(S, function()
    H.check(not styled(info) and not styled(dialog) and not styled(note), "a notice, a dialog and a question are now KOReader's own")
    H.check(H.find("// INFO") == nil and H.find("// CONFIRM") == nil, "none of CyberUI's tags is on screen")
    H.shot("tg2-off")
    UIManager:close(note); UIManager:close(dialog); UIManager:close(info)
end)
H.step(S, function()
    H.check(gone(info) and gone(dialog) and gone(note), "the stock ones close as usual")
end)

-- on again; one shown while on still closes cleanly when it is switched off meanwhile
H.step(S, function() tapSwitch("KOReader dialogs") end)
H.step(S, function()
    H.check(Settings.get("styled_widgets", true) == true, "tapping it again turns it back on")
    note = require("ui/widget/confirmbox"):new({ text = "Leave without saving?", ok_text = "Leave" })
    UIManager:show(note)
end)
H.step(S, function()
    H.check(styled(note) and H.find("// CONFIRM") ~= nil, "a question is in CyberUI's style again")
    Settings.set("styled_widgets", false)
    UIManager:close(note)
end)
H.step(S, function()
    H.check(gone(note), "one shown styled and closed after switching off closes both")
    local after = require("ui/widget/infomessage"):new({ text = "Plain again.", timeout = 60 })
    UIManager:show(after)
    H.check(not styled(after), "and the next one is plain")
    UIManager:close(after)
    Settings.set("styled_widgets", true)
end)

-- one kind switched off alone: its windows are KOReader's own and the other kinds stay in CyberUI's style
local a, b
H.step(S, function()
    Settings.set("styled_notices", false)
    a = require("ui/widget/infomessage"):new({ text = "A notice.", timeout = 60 })
    UIManager:show(a)
    b = require("ui/widget/buttondialog"):new({ title = "Menu", buttons = { { { text = "Open", callback = function() end } } } })
    UIManager:show(b)
end)
H.step(S, function()
    H.check(not styled(a), "with Notices and questions off, a notice is KOReader's own")
    H.check(styled(b), "and a button menu is still in CyberUI's style")
    UIManager:close(a); UIManager:close(b)
    Settings.set("styled_notices", true)
    Settings.set("styled_buttons", false)
    a = require("ui/widget/infomessage"):new({ text = "A notice.", timeout = 60 })
    UIManager:show(a)
    b = require("ui/widget/buttondialog"):new({ title = "Menu", buttons = { { { text = "Open", callback = function() end } } } })
    UIManager:show(b)
end)
H.step(S, function()
    H.check(styled(a) and not styled(b), "and the other way round: Button menus off alone")
    UIManager:close(a); UIManager:close(b)
    Settings.set("styled_buttons", true)
    H.app().go("settings")
    H.app().current().section = "home"
    H.app().push("dialogs")
end)
H.step(S, function()
    H.check(H.find("All KOReader dialogs") ~= nil and H.find("Notices and questions") ~= nil and H.find("Selected text menu") ~= nil, "the dialogs page lists the main switch and every kind")
    H.shot("tg3-dialogs")
end)
