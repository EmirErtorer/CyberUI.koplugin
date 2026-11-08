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

scene("spin-page", true, function()
    return require("ui/widget/spinwidget"):new({ title_text = "Go to page", info_text = "Page numbers run from 1 to 300.", value = 120, value_min = 1, value_max = 300, value_step = 1,
        value_hold_step = 10, ok_text = "Go", callback = function(w) ran.spin = w.value end })
end)
scene("spin-defaults", true, function()
    return require("ui/widget/spinwidget"):new({ title_text = "Font size", value = 22, value_min = 12, value_max = 40, value_step = 1, value_hold_step = 4, unit = "pt",
        default_value = 20, extra_text = "Reset to book", extra_callback = cb, ok_text = "Apply", callback = cb })
end)
scene("doublespin", true, function()
    return require("ui/widget/doublespinwidget"):new({ title_text = "Page margins", info_text = "In millimetres.", left_text = "Left", left_value = 8, left_min = 0, left_max = 40, left_step = 1, left_hold_step = 5,
        right_text = "Right", right_value = 12, right_min = 0, right_max = 40, right_step = 1, right_hold_step = 5, ok_text = "Apply", callback = function(l, r) ran.dbl = { l, r } end })
end)
scene("datetime-time", true, function()
    return require("ui/widget/datetimewidget"):new({ title_text = "Set time", info_text = "Night mode starts at this hour.", hour = 22, min = 30, ok_text = "Set time",
        callback = function(t) ran.time = t end })
end)
scene("datetime-date", true, function()
    return require("ui/widget/datetimewidget"):new({ title_text = "Set date", year = 2026, month = 11, day = 8, ok_text = "Set date", callback = function(t) ran.date = t end })
end)
scene("radio", true, function()
    return require("ui/widget/radiobuttonwidget"):new({ title_text = "Sort by", info_text = "How the list is ordered.", radio_buttons = {
        { { text = "Title", checked = true, provider = "title" } }, { { text = "Author", provider = "author" } }, { { text = "Date added", provider = "date" } },
        { { text = "Last read", provider = "read" } } }, ok_text = "Apply", callback = function(w) ran.radio = w.provider end })
end)

local multi
scene("multi-input", true, function()
    multi = require("ui/widget/multiinputdialog"):new({ title = "Set margins", fields = {
        { description = "Left margin", text = "10", hint = "mm" }, { description = "Right margin", text = "12", hint = "mm" }, { description = "Top margin, a number", text = "", hint = "mm", input_type = "number" } },
        buttons = { { { text = "Cancel", callback = function() UIManager:close(multi) end }, { text = "Apply", callback = function() ran.multi = multi:getFields(); UIManager:close(multi) end } } } })
    return multi
end)

local kvpage
scene("keyvalue-info", true, function()
    kvpage = require("ui/widget/keyvaluepage"):new({ title = "Book information", kv_pairs = {
        { "Title", "Dune" }, { "Authors", "Frank Herbert" }, { "Series", "Dune #1" }, { "Pages", "612" }, { "Language", "en" }, { "File size", "1.4 MB", separator = true },
        { "Description", "Set on the desert planet Arrakis, Dune is the story of the boy Paul Atreides, heir to a noble family tasked with ruling an inhospitable world where the only thing of value is the spice melange, a drug capable of extending life and enhancing consciousness. Coveted across the known universe, melange is a prize worth killing for." },
        { "Open file", "tap to open", callback = function() ran.kvopen = true end },
        { "Remove me", "hold to remove", hold_callback = function(page, item) page:removeKeyValueItem(item) end } } })
    return kvpage
end)

local sorter
scene("sort", true, function()
    local items = { { text = "Wi-Fi", checked_func = function() return true end, callback = cb }, { text = "Bookmarks" }, { text = "Statistics", checked_func = function() return false end, callback = cb },
        { text = "Reading goals" }, { text = "Calendar" } }
    sorter = require("ui/widget/sortwidget"):new({ title = "Arrange menu", item_table = items, callback = cb })
    return sorter
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

    -- the number picker steps, follows the slider and applies what KOReader's picker holds
    local spin
    H.step(0.8, function()
        spin = require("ui/widget/spinwidget"):new({ title_text = "Go to page", value = 120, value_min = 1, value_max = 300, value_step = 1, value_hold_step = 10,
            ok_text = "Go", callback = function(w) ran.spin = w.value end })
        UIManager:show(spin)
    end)
    H.step(0.8, function()
        H.check(H.find("120") ~= nil or H.findWhere(function(el) return el.text_fn and el.text_fn() == "120" end) ~= nil, "the picker shows its value")
        H.tap("+")
    end)
    H.step(0.8, function()
        H.check(spin.value_widget.value == 121, "a tap on + steps KOReader's picker: " .. tostring(spin.value_widget.value))
        H.tap("\u{2212}10")
    end)
    H.step(0.8, function()
        H.check(spin.value_widget.value == 111, "the small button takes the long step: " .. tostring(spin.value_widget.value))
        H.tap("Go")
    end)
    H.step(0.8, function()
        H.check(ran.spin == 111, "Apply runs KOReader's callback with the value: " .. tostring(ran.spin))
        UIManager:close(spin)
        spin = require("ui/widget/spinwidget"):new({ title_text = "Go to page", value = 10, value_min = 1, value_max = 300, value_step = 1, value_hold_step = 10,
            ok_text = "Go", callback = function(w) ran.spin = w.value end })
        UIManager:show(spin)
    end)
    H.step(0.8, function()
        local slider = H.findWhere(function(el) return el.trackWidth and el.on_tap end)
        H.check(slider ~= nil, "a wide range has a slider")
        if slider then H.tapAt(slider.x + slider:trackWidth() / 2, slider.y + slider.h / 2) end
    end)
    H.step(0.8, function()
        local v = spin.value_widget.value
        H.check(v > 120 and v < 180, "a tap in the middle of the slider sets KOReader's picker to about half the range: " .. tostring(v))
        H.tap("Go")
    end)
    H.step(0.8, function()
        H.check(ran.spin and ran.spin > 120 and ran.spin < 180, "and Apply is enabled and applies it: " .. tostring(ran.spin))
        UIManager:close(spin)
    end)
    -- a time: the hour steps up and rolls over
    local clock
    H.step(0.8, function()
        clock = require("ui/widget/datetimewidget"):new({ title_text = "Set time", hour = 23, min = 5, ok_text = "Set time", callback = function(t) ran.clock = t end })
        UIManager:show(clock)
    end)
    H.step(0.8, function()
        local up = H.find(nil, "up", true)
        H.check(up ~= nil, "the time has step-up arrows")
        if up then H.tapAt(up.x + up.w / 2, up.y + up.h / 2) end
    end)
    H.step(0.8, function()
        H.check(clock.hour_widget.value == 0, "the hour rolled over to midnight: " .. tostring(clock.hour_widget.value))
        H.tap("Set time")
    end)
    H.step(0.8, function()
        H.check(ran.clock ~= nil and ran.clock.hour == 0 and ran.clock.min == 5, "Set time hands KOReader's callback the time")
        UIManager:close(clock)
    end)
    -- a choice
    local radio
    H.step(0.8, function()
        radio = require("ui/widget/radiobuttonwidget"):new({ title_text = "Sort by", radio_buttons = { { { text = "Title", checked = true, provider = "t" } },
            { { text = "Author", provider = "a" } } }, ok_text = "Apply", callback = function(w) ran.radio = w.provider end })
        UIManager:show(radio)
    end)
    H.step(0.8, function() H.check(H.tap("Author"), "the choices are tappable") end)
    H.step(0.8, function() H.tap("Apply") end)
    H.step(0.8, function()
        H.check(ran.radio == "a", "the choice chosen is the one KOReader's callback gets: " .. tostring(ran.radio))
        UIManager:close(radio)
    end)

    -- a form: a tap on another field moves the typing there, and Apply gets every field
    H.step(0.8, function()
        multi = require("ui/widget/multiinputdialog"):new({ title = "Set margins", fields = { { description = "Left", text = "10", hint = "mm" }, { description = "Right", text = "12", hint = "mm" } },
            buttons = { { { text = "Cancel", callback = function() UIManager:close(multi) end }, { text = "Apply", callback = function() ran.multi = multi:getFields(); UIManager:close(multi) end } } } })
        UIManager:show(multi)
    end)
    H.step(0.8, function()
        H.check(multi._input_widget == multi.input_fields[1], "the first field has the typing")
        -- the second field: the input fields in the shown tree, in order
        local seen, fields = {}, {}
        H.findWhere(function(el)
            if el.chars and el.get and not seen[el] then seen[el] = true; fields[#fields + 1] = el end
            return false
        end)
        H.check(#fields == 2, "both fields are drawn: " .. #fields)
        if fields[2] then H.tapAt(fields[2].x + fields[2].w - 12, fields[2].y + fields[2].h / 2) end
    end)
    H.step(1, function()
        H.check(multi._input_widget == multi.input_fields[2], "a tap on the second field moves KOReader's typing there")
        multi._input_widget:addChars("5")
    end)
    H.step(0.8, function() H.tap("Apply") end)
    H.step(0.8, function()
        H.check(ran.multi and ran.multi[1] == "10" and ran.multi[2] == "125", "Apply gets both fields as typed: " .. tostring(ran.multi and (ran.multi[1] .. "," .. ran.multi[2])))
    end)

    -- an information list: callbacks get the page and an item, a hold can remove a pair, a long value shows in full
    H.step(0.8, function()
        kvpage = require("ui/widget/keyvaluepage"):new({ title = "Info", kv_pairs = { { "Open file", "tap", callback = function(p, item) ran.kvopen = item.key end },
            { "Gone soon", "x", hold_callback = function(p, item) p:removeKeyValueItem(item) end }, { "Long", string.rep("long words ", 60) } } })
        UIManager:show(kvpage)
    end)
    H.step(0.8, function()
        H.check(H.find("Open file") ~= nil, "the pairs are listed")
        H.tap("Open file")
    end)
    H.step(0.8, function()
        H.check(ran.kvopen == "Open file", "a tap runs the pair's callback with the item: " .. tostring(ran.kvopen))
        H.hold("Gone soon")
    end)
    H.step(0.8, function()
        H.check(#kvpage.kv_pairs == 2 and H.find("Gone soon") == nil, "a hold callback may remove the pair and the list follows")
        H.tap("Long")
    end)
    H.step(0.8, function()
        H.check(H.find("// TEXT") ~= nil, "a tap on a cut value shows all of it in the viewer")
        H.tap("Close")
    end)
    H.step(0.8, function()
        H.tap("Open file")   -- (still the list on top)
        H.tap(nil, "back")
    end)
    H.step(0.8, function() H.check(gone(kvpage), "the back button closes the list and its popup") end)

    -- a sorting window: a step moves an item in KOReader's own list, Done passes it on, Cancel puts it back
    local order = { { text = "One" }, { text = "Two" }, { text = "Three" } }
    H.step(0.8, function()
        sorter = require("ui/widget/sortwidget"):new({ title = "Arrange", item_table = order, callback = function() ran.sorted = order[1].text .. order[2].text .. order[3].text end })
        UIManager:show(sorter)
    end)
    H.step(0.8, function()
        local downs, seen = {}, {}
        H.findWhere(function(el)
            if el.icon == "down" and el.on_tap and not seen[el] then seen[el] = true; downs[#downs + 1] = el end
            return false
        end)
        H.check(#downs >= 1, "each row has a step down")
        if downs[1] then H.tapAt(downs[1].x + downs[1].w / 2, downs[1].y + downs[1].h / 2) end
    end)
    H.step(0.8, function()
        H.check(order[1].text == "Two" and order[2].text == "One", "a step moves the item in KOReader's own list: " .. order[1].text .. order[2].text)
        H.tap("Done")
    end)
    H.step(0.8, function()
        H.check(ran.sorted == "TwoOneThree", "Done passes the new order on: " .. tostring(ran.sorted))
        H.check(gone(sorter), "and closes the window")
    end)
    H.step(0.8, function()
        sorter = require("ui/widget/sortwidget"):new({ title = "Arrange", item_table = order, callback = function() ran.sorted = "no" end })
        UIManager:show(sorter)
    end)
    H.step(0.8, function()
        local down = H.find(nil, "down", true)
        if down then H.tapAt(down.x + down.w / 2, down.y + down.h / 2) end
    end)
    H.step(0.8, function()
        H.check(order[1].text == "One", "another step moved the first item: " .. order[1].text)
        H.tap("Cancel")
    end)
    H.step(0.8, function()
        H.check(order[1].text == "Two" and ran.sorted == "TwoOneThree" and gone(sorter), "Cancel puts the order back and closes without passing it on")
    end)

end
if mode == "new" then behaviour() end
