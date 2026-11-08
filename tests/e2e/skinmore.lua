-- The windows KOReader opens beyond notices and questions (note viewer, number and time pickers, forms,
-- information lists, sorting, folder picker, progress...), each shown once and photographed. Run with
-- CYBERUI_SKINMODE=old (KOReader's own look) and again with new to put the two side by side; in new
-- mode every scene marked styled must be in CyberUI's style.
local H = ...
local UIManager = require("ui/uimanager")
local mode = os.getenv("CYBERUI_SKINMODE") or "new"
require("cyberui/settings").set("styled_widgets", mode == "new")
G_reader_settings:saveSetting("virtual_keyboard_enabled", true)

local cb = function() end
local current
local n = 0
-- One scene: make() builds a widget, which is shown, photographed and closed. `styled`: it must be CyberUI's.
-- `extra(widget)` runs before the photo (taps, scrolling...).
local function scene(name, styled, make, extra)
    n = n + 1
    local label = string.format("%02d-%s", n, name)
    H.step(0.8, function()
        local ok, w = pcall(make)
        if not ok then H.check(false, name .. " builds: " .. tostring(w)); current = nil; return end
        current = w
        UIManager:show(w)
    end)
    H.step(0.8, function()
        local w = current
        if not w then return end
        if mode == "new" and styled then H.check(w._cyber_popup ~= nil, name .. " is in CyberUI's style") end
        if extra then extra(w) end
    end)
    H.step(0.6, function()
        if not current then return end
        H.shot(label)
        UIManager:close(current)
        current = nil
    end)
end

local dlg
scene("input-five-buttons", true, function()
    dlg = require("ui/widget/inputdialog"):new({ title = "Edit note", description = "2026-11-06 01:14:44 · Page 3", allow_newline = true,
        input = "NAKAMURA İNGİLİZCE BASKI © 2000, 2005 KOSEI PUBLISHING CO. LTD. TÜRKÇE ÇEVİRİ HAKLARI JAPAN FOREIGN-RIGHTS CENTRE ARACILIĞIYLA KOSEI PUBLISHING CO. LTD.’ DEN ALINMIŞTIR",
        buttons = { { { text = "Cancel", callback = cb }, { text = "Paste", callback = cb }, { text = "Save", is_enter_default = true, callback = cb },
            { text = "▲", callback = cb }, { text = "▼", callback = cb } } } })
    dlg:onShowKeyboard()
    return dlg
end)
