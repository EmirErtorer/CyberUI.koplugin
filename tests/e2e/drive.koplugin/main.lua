-- Test driver for CyberUI (development only, never shipped): runs the scenario
-- named by CYBERUI_DRIVE_SCRIPT step by step on KOReader's event loop. Steps
-- send real gestures, look up CyberUI elements by their text, check state and
-- save screenshots; results go to <CYBERUI_DRIVE_OUT>/drive.log.

local Device = require("device")
local Event = require("ui/event")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local time = require("ui/time")

local Drive = WidgetContainer:extend({ name = "cyberuidrive", is_doc_only = false })

-- Set up the helpers and start the scenario once per session.
function Drive:init()
    local script = os.getenv("CYBERUI_DRIVE_SCRIPT")
    if not script or Drive.ran then return end
    Drive.ran = true
    local out = os.getenv("CYBERUI_DRIVE_OUT")
    local log = io.open(out .. "/drive.log", "w")
    local H = { pass = 0, fail = 0, out = out }

    -- Write a line to the log.
    function H.say(...)
        local t = {}
        for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
        log:write(table.concat(t, " "), "\n")
        log:flush()
    end
    -- Record a check.
    function H.check(c, what)
        if c then H.pass = H.pass + 1 else H.fail = H.fail + 1 end
        H.say(c and "PASS" or "FAIL", what)
    end
    -- Save the screen as <out>/<name>.png.
    function H.shot(name) Device.screen:shot(out .. "/" .. name .. ".png") end
    -- The widget on top of the window stack.
    function H.top()
        local s = UIManager._window_stack
        return s[#s] and s[#s].widget
    end
    -- CyberUI's app controller.
    function H.app() return require("cyberui/app") end
    -- Id of the CyberUI screen shown, or nil.
    function H.screen()
        local s = H.app().current()
        return s and s.id
    end
    -- Is CyberUI's window on top?
    function H.cyberTop()
        local t = H.top()
        return t ~= nil and t.name == "cyberui"
    end

    -- The first element (dialog first, then screen) for which pred(el) is true.
    function H.findWhere(pred)
        local host
        for _i, e in ipairs(UIManager._window_stack) do if e.widget.name == "cyberui" then host = e.widget end end
        if not host then return nil end
        local function walk(el)
            if type(el) ~= "table" then return nil end
            if el.x and pred(el) then return el end
            for _i, c in ipairs(el.children or {}) do
                local f = walk(c)
                if f then return f end
            end
            if el.child then return walk(el.child) end
        end
        return (host.overlay and walk(host.overlay)) or walk(host.root)
    end

    -- Find the first element in the shown tree (dialog first) whose label,
    -- text, sub line or title equals `text`, or whose icon is `icon`. With
    -- `tappable`, the nearest element around it that answers a tap or hold.
    function H.find(text, icon, tappable)
        local function matches(el)
            return (text and (el.label == text or el.text == text or el.sub == text or el.title == text))
                or (icon and el.icon == icon)
        end
        if not tappable then return H.findWhere(matches) end
        -- the nearest element around the match that answers a tap or hold
        local found
        local function walk(el, around)
            if found or type(el) ~= "table" then return end
            if el.on_tap or el.on_hold then around = el end
            if el.x and matches(el) and around then found = around return end
            for _i, c in ipairs(el.children or {}) do walk(c, around) end
            if el.child then walk(el.child, around) end
        end
        for _i, e in ipairs(UIManager._window_stack) do
            if e.widget.name == "cyberui" then
                if e.widget.overlay then walk(e.widget.overlay) end
                if not found then walk(e.widget.root) end
            end
        end
        return found
    end

    -- Send a gesture to KOReader.
    local function send(ges)
        ges.time = time.now()
        UIManager:sendEvent(Event:new("Gesture", ges))
    end
    local function at(x, y) return Geom:new({ x = math.floor(x), y = math.floor(y), w = 0, h = 0 }) end
    -- Tap a point.
    function H.tapAt(x, y) send({ ges = "tap", pos = at(x, y) }) end
    -- Tap the middle of the element with this text (or icon); false when missing.
    function H.tap(text, icon)
        local el = H.find(text, icon, true)
        if not el then H.check(false, "found '" .. tostring(text or icon) .. "' to tap"); return false end
        H.tapAt(el.x + el.w / 2, el.y + el.h / 2)
        return true
    end
    -- Hold on a point, then lift.
    function H.holdAt(x, y)
        send({ ges = "hold", pos = at(x, y) })
        send({ ges = "hold_release", pos = at(x, y) })
    end
    -- Hold on the element with this text.
    function H.hold(text)
        local el = H.find(text, nil, true)
        if not el then H.check(false, "found '" .. tostring(text) .. "' to hold"); return false end
        H.holdAt(el.x + el.w / 2, el.y + el.h / 2)
        return true
    end
    -- Swipe in a direction ("west", "east", "north", "south") from a point.
    function H.swipe(dir, x, y)
        send({ ges = "swipe", direction = dir, distance = 200, pos = at(x, y) })
    end
    -- The text being typed in CyberUI's input panel, or nil when none is open.
    function H.typed()
        local field = H.findWhere(function(el) return el.state ~= nil and el.state.text ~= nil end)
        return field and field.state.text
    end
    -- Type `text` by tapping the keys of CyberUI's keyboard (space taps the
    -- space bar, capitals use shift), then tap `ok` when given.
    function H.typeKeys(text, ok)
        for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            if ch == " " then H.tap("space")
            elseif ch:match("%u") then H.tap("⇧"); H.tap(ch)
            else H.tap(ch) end
        end
        if ok then H.tap(ok) end
    end
    -- Send a KOReader event (as a gesture action would).
    function H.event(name, ...) UIManager:sendEvent(Event:new(name, ...)) end

    local steps = {}
    -- Add a step to run `delay` seconds after the previous one.
    function H.step(delay, fn) steps[#steps + 1] = { delay, fn } end
    local chunk, err = loadfile(script)
    if not chunk then H.say("ERROR loading scenario: " .. tostring(err)) else chunk(H) end
    local function run(i)
        if i > #steps then
            H.say(string.format("DONE %d passed, %d failed", H.pass, H.fail))
            log:close()
            UIManager:scheduleIn(0.5, function() UIManager:quit() end)
            return
        end
        UIManager:scheduleIn(steps[i][1], function()
            local ok, e = xpcall(steps[i][2], debug.traceback)
            if not ok then H.fail = H.fail + 1; H.say("ERROR step " .. i .. ": " .. tostring(e)) end
            run(i + 1)
        end)
    end
    UIManager:scheduleIn(2, function() run(1) end)
end

return Drive
