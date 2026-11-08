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

local TEXT = "A note I wrote on a highlight. It is a long one, so that it wraps over several lines of the viewer and shows how the text is laid out and how the pages turn when there is more of it than fits. "
    .. "Second sentence of the same note, which keeps going for a while: the quick brown fox jumps over the lazy dog and then does it all over again. "
    .. "Third: highlights are for remembering what mattered, and notes for remembering why it did. Fourth, fifth and sixth sentences follow so that a page is not enough."
local ran = {}
scene("textviewer-note", true, function()
    return require("ui/widget/textviewer"):new({ title = "Note", text = TEXT,
        buttons_table = { { { text = "Delete note", callback = function() ran.dn = true end }, { text = "Edit note", callback = function() ran.en = true end } },
            { { text = "Delete highlight", callback = cb }, { text = "Highlight menu", callback = cb } } } })
end)
scene("textviewer-plain", true, function()
    return require("ui/widget/textviewer"):new({ title = "About", text = "Plain long text.\n\nSecond paragraph of the text viewer, used for book descriptions, help and licences." })
end)

-- behaviour, in the styled mode only
local function behaviour()
    -- the text viewer pages a long text, runs KOReader's callbacks and closes with Back or Close
    local viewer
    local function gone(w) for _i, e in ipairs(UIManager._window_stack) do if e.widget == w or e.widget == w._cyber_popup then return false end end return true end
    H.step(0.8, function()
        viewer = require("ui/widget/textviewer"):new({ title = "Licence", text = string.rep("Words that go on and on and on, line after line. ", 80),
            buttons_table = { { { text = "Edit note", callback = function() ran.en = true end } } } })
        UIManager:show(viewer)
    end)
    H.step(0.8, function()
        H.check(H.findWhere(function(el) return type(el.text) == "string" and el.text:match("^1 / %d+$") end) ~= nil, "a long text has a page counter")
        H.shot("tv-pages-1")
        H.tap(">")
    end)
    H.step(0.8, function()
        H.check(H.findWhere(function(el) return type(el.text) == "string" and el.text:match("^2 / %d+$") end) ~= nil, "the arrow turns the page")
        H.tap("Edit note")
    end)
    H.step(0.8, function()
        H.check(ran.en, "a button runs KOReader's own callback")
        H.tap("Close")
    end)
    H.step(0.8, function() H.check(gone(viewer), "Close closes the viewer and its popup") end)

end
if mode == "new" then behaviour() end
