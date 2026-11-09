-- CyberUI's own typing panel (rename, search): a tap beside the keyboard puts the keyboard away and keeps the text, a tap
-- on the field brings it back, a tap beside the bare field leaves; OK hands the text on. And KOReader's keyboard in the
-- same style has a HIDE handle that puts it away.
local H = ...
local UIManager = require("ui/uimanager")
G_reader_settings:saveSetting("virtual_keyboard_enabled", true)
local got
local function keyboardShown() return H.find("space") ~= nil or H.findWhere(function(e) return e.label == "// space //" end) ~= nil end

H.step(1, function() H.app().input("Name it", "ab", function(t) got = t end, "Save") end)
H.step(0.8, function()
    H.check(keyboardShown(), "the panel opens with its keyboard")
    H.shot("ok1-open")
    H.tapAt(8, 8)
end)
H.step(0.8, function()
    H.check(not keyboardShown(), "a tap beside the keyboard puts it away")
    H.check(H.app().overlay() ~= nil and H.find("Save") ~= nil, "the panel stays, with its Save button")
    H.shot("ok2-collapsed")
    local field = H.findWhere(function(e) return e.chars and e.get end)
    if field then H.tapAt(field.x + field.w / 2, field.y + field.h / 2) end
end)
H.step(0.8, function()
    H.check(keyboardShown(), "a tap on the field brings the keyboard back")
    H.tap("c")
    H.tapAt(8, 8)
end)
H.step(0.8, function()
    H.tap("Save")
end)
H.step(0.8, function() H.check(got == "abc", "the text typed before putting the keyboard away is kept: " .. tostring(got)) end)

-- KOReader's keyboard, in the same style: its HIDE handle
local d
H.step(0.8, function()
    d = require("ui/widget/inputdialog"):new({ title = "Search", input = "", buttons = { { { text = "Cancel", callback = function() UIManager:close(d) end } } } })
    UIManager:show(d); d:onShowKeyboard()
end)
H.step(1, function()
    H.check(d._input_widget:isKeyboardVisible() and H.find("HIDE") ~= nil, "KOReader's keyboard shows a HIDE handle")
    H.shot("ok3-koreader")
    H.tap("HIDE")
end)
H.step(1, function()
    H.check(not d._input_widget:isKeyboardVisible(), "and it puts the keyboard away")
    UIManager:close(d)
end)
