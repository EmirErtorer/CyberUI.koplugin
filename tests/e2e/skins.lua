-- KOReader's own notices, questions and button dialogs drawn in CyberUI's style, over home: each shows
-- as a popup right above the widget KOReader built, does what KOReader's callbacks do, and closes both.
local H = ...
local UIManager = require("ui/uimanager")
local S = 1

-- Where a widget is in KOReader's window stack (nil when it is not there).
local function index(widget)
    for i, e in ipairs(UIManager._window_stack) do if e.widget == widget then return i end end
end
local function gone(widget)
    local p = widget._cyber_popup
    return index(widget) == nil and p == nil
end
local function above(widget)
    local p = widget._cyber_popup
    return p ~= nil and index(p) == (index(widget) or -2) + 1
end

local info, confirm, multi, dialog
local ran = {}

-- a message box that closes by itself
H.step(S, function()
    info = require("ui/widget/infomessage"):new({ text = "Saved to your library.", timeout = 3 })
    UIManager:show(info)
end)
H.step(S, function()
    H.check(above(info), "the message box has its popup right above it")
    H.check(H.find("// INFO") ~= nil and H.find("Saved to your library.") ~= nil, "it shows its text under an info tag")
    H.shot("1-message")
end)
H.step(3.5, function() H.check(gone(info), "it closes by itself when KOReader's timeout says so, popup too") end)

-- a question
H.step(S, function()
    confirm = require("ui/widget/confirmbox"):new({
        text = "Delete this highlight? This can't be undone.", ok_text = "Delete it",
        ok_callback = function() ran.ok = true end, cancel_callback = function() ran.cancel = true end,
    })
    UIManager:show(confirm)
end)
H.step(S, function()
    H.check(above(confirm), "the question has its popup right above it")
    H.check(H.find("// CONFIRM") ~= nil and H.find("Delete it", nil, true) ~= nil and H.find("Cancel", nil, true) ~= nil, "it shows the text and both buttons")
    H.shot("2-confirm")
    H.tap("Delete it")
end)
H.step(S, function()
    H.check(ran.ok and gone(confirm), "OK runs KOReader's callback and closes both")
    confirm = require("ui/widget/confirmbox"):new({ text = "Leave without saving?", cancel_callback = function() ran.cancel = true end })
    UIManager:show(confirm)
end)
H.step(S, function() H.tapAt(8, 8) end)
H.step(S, function()
    H.check(ran.cancel and gone(confirm), "a tap outside cancels, as in KOReader")
end)

-- two choices and more rows
H.step(S, function()
    multi = require("ui/widget/multiconfirmbox"):new({
        text = "Which copy do you want to keep?", choice1_text = "This device", choice2_text = "The cloud",
        choice1_callback = function() ran.one = true end, choice2_callback = function() ran.two = true end,
    })
    UIManager:show(multi)
end)
H.step(S, function()
    H.check(above(multi) and H.find("This device", nil, true) and H.find("The cloud", nil, true), "the three-button question shows all its buttons")
    H.shot("3-multiconfirm")
    H.tap("The cloud")
end)
H.step(S, function() H.check(ran.two and not ran.one and gone(multi), "the chosen button's callback ran") end)

-- layers: whatever KOReader shows later stays above
H.step(S, function()
    info = require("ui/widget/infomessage"):new({ text = "First, below.", dismissable = false })
    confirm = require("ui/widget/confirmbox"):new({ text = "Second, above." })
    UIManager:show(info)
    UIManager:show(confirm)
end)
H.step(S, function()
    H.check(index(info) < index(info._cyber_popup) and index(info._cyber_popup) < index(confirm) and index(confirm) < index(confirm._cyber_popup),
        "popups keep KOReader's order: first, its popup, second, its popup")
    H.shot("4-layers")
    UIManager:close(confirm)
    UIManager:close(info)
end)
H.step(S, function() H.check(gone(info) and gone(confirm), "closing KOReader's widgets closes the popups") end)

-- a button dialog: checked, disabled and held buttons, and a long list that pages
H.step(S, function()
    local rows = { { { text = "Open", callback = function() ran.open = true; UIManager:close(dialog) end },
        { text = "Sort by title", checked_func = function() return true end, callback = function() end } },
        { { text = "Locked", enabled = false, callback = function() end },
        { text_func = function() return "Held " .. 3 end, callback = function() end, hold_callback = function() ran.held = true end } } }
    for i = 1, 14 do rows[#rows + 1] = { { text = "Row " .. i, callback = function() end } } end
    dialog = require("ui/widget/buttondialog"):new({ title = "A KOReader dialog", buttons = rows })
    UIManager:show(dialog)
end)
H.step(S, function()
    H.check(above(dialog), "the button dialog has its popup right above it")
    H.check(H.find("A KOReader dialog") ~= nil and H.find("Held 3", nil, true) ~= nil, "it shows its title and a button made by text_func")
    H.check(H.find(nil, "check") ~= nil, "a checked button shows a check")
    local locked = H.find("Locked")
    H.check(locked ~= nil and locked.disabled == true, "a disabled button is shown disabled")
    H.shot("5-buttondialog")
    H.hold("Held 3")
end)
H.step(S, function()
    H.check(ran.held, "holding runs the hold callback")
    H.check(H.find("Row 14", nil, true) == nil and H.find(">", nil, true) ~= nil, "a long list is paged")
    H.tap(">")
end)
H.step(S, function()
    H.check(H.find("Row 14", nil, true) ~= nil, "the next page shows the later rows")
    H.shot("6-buttondialog-page2")
    H.tap("<")
end)
H.step(S, function()
    H.tap("Open")
end)
H.step(S, function() H.check(ran.open and gone(dialog), "a button runs KOReader's callback, which closes both") end)

-- a notification: stacks at the top, takes no touches
H.step(S, function()
    UIManager:show(require("ui/widget/notification"):new({ text = "Brightness 40%" }))
end)
H.step(0.5, function()
    local shown
    for _i, e in ipairs(UIManager._window_stack) do
        if e.widget._cyber_popup and e.widget.toast then shown = e.widget end
    end
    H.check(shown ~= nil and shown._cyber_popup.passive == true, "the notification is a passive popup")
    H.shot("7-notification")
end)
H.step(3, function()
    local left
    for _i, e in ipairs(UIManager._window_stack) do if e.widget.toast then left = true end end
    H.check(not left, "the notification went away when its time was up")
end)
