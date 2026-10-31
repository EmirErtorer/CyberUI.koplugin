--[[
Frames for an animated README picture, taken in the emulator.

A scenario makes a recorder and runs its script as a coroutine on KOReader's
own event loop, so what a tap or a gesture schedules happens between frames as
it would on a reader:

    local G = dofile(KIT .. "/gifkit.lua")(H, "annotate")
    G.run(function()
        G:hold(1000)
        G:tap(x, y)
        ...
    end)

Each frame is the screen saved as <out>/<name>/fNNNN.png and a line in
<out>/<name>/frames.txt: its number, how long it shows (ms) and the touches on
it, which gif.py draws on top (a fingertip with a fading trail, or a pen):

    n ms kind:x:y:alpha:trail_x1,trail_y1,...   (one per touch)

Taps, holds and swipes go to KOReader as gestures (UIManager:sendEvent), so
buttons flash and gestures do what they are set to (a frame is taken while a
button flashes); pen strokes go through the view's touch handlers, as the
pen's input does.
]]

local UIManager = require("ui/uimanager")
local Event = require("ui/event")
local Geom = require("ui/geometry")
local time_ok, time = pcall(require, "ui/time")

return function(H, name)
    local dir = H.out .. "/" .. name
    os.execute("mkdir -p '" .. dir .. "'")
    local log = io.open(dir .. "/frames.txt", "w")
    local G = { n = 0, touches = {} }
    local co

    local function finish(err)
        if err then H.say("ERROR scene " .. name .. ": " .. tostring(err)) end
        log:close()
        H.say("SCENE " .. name .. " DONE " .. G.n .. " frames")
        UIManager:scheduleIn(0.5, function() UIManager:quit() end)
    end
    local function resume()
        local ok, err = coroutine.resume(co, G)
        if not ok then finish(debug.traceback(co, err))
        elseif coroutine.status(co) == "dead" then finish() end
    end

    -- Run fn(G) as the scene; the driver's steps only keep it alive meanwhile.
    function G.run(fn)
        H.step(0, function() co = coroutine.create(fn); resume() end)
        for _i = 1, 4000 do H.step(0.5, function() end) end
    end

    -- Let KOReader run for s seconds (its scheduled work, refreshes).
    function G:wait(s)
        UIManager:scheduleIn(s or 0, resume)
        coroutine.yield()
    end

    -- the touches shown on the next frames: { x, y, kind = "finger" | "pen",
    -- alpha = 0..1, trail = { x1, y1, ... } (older first) }
    function G:show(list) self.touches = list or {} end

    -- A line of text shown on the next frames (nil for none).
    function G:say(text) self.caption = text end

    -- While muted, frames are not kept (a scene making its starting point).
    function G:mute(on) self.muted = on end

    function G:frame(ms)
        UIManager:forceRePaint()
        if self.muted then return end
        self.n = self.n + 1
        H.shot(string.format("%s/f%04d", name, self.n))
        local parts = {}
        for _i, t in ipairs(self.touches) do
            local trail = {}
            for k, v in ipairs(t.trail or {}) do trail[k] = string.format("%d", v) end
            parts[#parts + 1] = string.format("%s:%d:%d:%.2f:%s", t.kind or "finger", t.x, t.y, t.alpha or 1,
                table.concat(trail, ","))
        end
        if self.caption then parts[#parts + 1] = "cap=" .. self.caption:gsub(" ", "_") end
        log:write(string.format("%d %d %s\n", self.n, ms, table.concat(parts, " ")))
        log:flush()
    end

    -- The screen as it is, for ms.
    function G:hold(ms) self:show({}); self:frame(ms) end

    local function now() return time_ok and time.now() or os.time() end
    local function send(ges)
        ges.time = now()
        UIManager:sendEvent(Event:new("Gesture", ges))
    end
    local function at(x, y) return Geom:new{ x = math.floor(x), y = math.floor(y), w = 0, h = 0 } end

    -- Send a gesture; a button or menu item flashing for it is a frame.
    local function sendFlashing(ges, flash_ms)
        local yield_epdc = UIManager.yieldToEPDC
        local flashed = false
        UIManager.yieldToEPDC = function(...)
            if not flashed then flashed = true; G:frame(flash_ms) end
            return yield_epdc(...)
        end
        local ok, err = pcall(send, ges)
        UIManager.yieldToEPDC = yield_epdc
        if not ok then error(err) end
        return flashed
    end

    -- A tap: the finger comes down (with the flash, when there is one), then lifts.
    -- With `touch` the touch that starts it is sent first, as the panel reports
    -- it (Ink Away's floating controls act on the two together).
    function G:tap(x, y, after_ms, touch)
        self:show({ { x = x, y = y } })
        self:frame(120)
        if touch then send({ ges = "touch", pos = at(x, y) }) end
        if not sendFlashing({ ges = "tap", pos = at(x, y) }, 110) then self:frame(90) end
        self:wait(0.05)
        self:show({ { x = x, y = y, alpha = 0.45 } })
        self:frame(after_ms or 240)
        self:show({})
    end

    -- A long press, then the lift.
    function G:press(x, y, after_ms)
        self:show({ { x = x, y = y } })
        self:frame(300)
        self:frame(300)
        if not sendFlashing({ ges = "hold", pos = at(x, y) }, 110) then self:frame(90) end
        send({ ges = "hold_release", pos = at(x, y) })
        self:wait(0.05)
        self:show({ { x = x, y = y, alpha = 0.45 } })
        self:frame(after_ms or 240)
        self:show({})
    end

    -- The middle of a painted widget (its dimen).
    function G.middle(w)
        local d = w and w.dimen
        assert(d and d.w and d.w > 0, "widget not painted")
        return d.x + math.floor(d.w / 2), d.y + math.floor(d.h / 2)
    end
    function G:tapWidget(w, after_ms)
        local x, y = G.middle(w)
        self:tap(x, y, after_ms)
    end

    -- A point along a polyline pts ({x1, y1, x2, y2, ...}) at f in 0..1, by length.
    local function along(pts, f)
        local n, len = #pts / 2, 0
        local seg = {}
        for i = 1, n - 1 do
            local dx, dy = pts[2 * i + 1] - pts[2 * i - 1], pts[2 * i + 2] - pts[2 * i]
            seg[i] = math.sqrt(dx * dx + dy * dy)
            len = len + seg[i]
        end
        local want = f * len
        for i = 1, n - 1 do
            if want <= seg[i] or i == n - 1 then
                local u = seg[i] > 0 and math.min(1, want / seg[i]) or 0
                return pts[2 * i - 1] + (pts[2 * i + 1] - pts[2 * i - 1]) * u,
                    pts[2 * i] + (pts[2 * i + 2] - pts[2 * i]) * u
            end
            want = want - seg[i]
        end
        return pts[#pts - 1], pts[#pts]
    end

    -- A one-finger swipe along pts in `steps` frames, then the gesture (as
    -- KOReader reports a swipe: at the lift). after(G) runs once the gesture
    -- is handled, before the frame showing what it did.
    function G:swipe(pts, steps, direction, o)
        o = o or {}
        local trail = {}
        for s = 0, steps do
            local x, y = along(pts, s / steps)
            self:show({ { x = x, y = y, trail = { unpack(trail) } } })
            self:frame(o.step_ms or 40)
            trail[#trail + 1] = math.floor(x); trail[#trail + 1] = math.floor(y)
            if #trail > 16 then table.remove(trail, 1); table.remove(trail, 1) end
        end
        local x0, y0, x1, y1 = pts[1], pts[2], pts[#pts - 1], pts[#pts]
        send({ ges = "swipe", direction = direction, pos = at(x0, y0), end_pos = at(x1, y1),
            distance = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) })
        self:wait(o.wait or 0.3)
        if o.after then o.after(self) end
        self:show({ { x = x1, y = y1, alpha = 0.4, trail = trail } })
        self:frame(o.after_ms or 200)
        self:show({})
    end

    -- Two fingers on a diagonal through (cx, cy), from r0 to r1 px from it
    -- in `steps` frames, then KOReader's pinch (closer) or spread (apart).
    function G:pinch(cx, cy, r0, r1, steps, o)
        o = o or {}
        local ux, uy = math.cos(math.rad(40)), -math.sin(math.rad(40))
        local function fingers(r, alpha, trail)
            return { { x = cx + ux * r, y = cy + uy * r, alpha = alpha, trail = trail and trail[1] },
                { x = cx - ux * r, y = cy - uy * r, alpha = alpha, trail = trail and trail[2] } }
        end
        local trails = { {}, {} }
        for s = 0, steps do
            local f = s / steps
            local r = r0 + (r1 - r0) * f * f * (3 - 2 * f)
            self:show(fingers(r, 1, { { unpack(trails[1]) }, { unpack(trails[2]) } }))
            self:frame(o.step_ms or 45)
            for k, sign in ipairs({ 1, -1 }) do
                local t = trails[k]
                t[#t + 1] = math.floor(cx + sign * ux * r); t[#t + 1] = math.floor(cy + sign * uy * r)
                if #t > 10 then table.remove(t, 1); table.remove(t, 1) end
            end
        end
        send({ ges = r1 > r0 and "spread" or "pinch", direction = "diagonal", pos = at(cx, cy),
            distance = 2 * math.abs(r1 - r0) })
        self:wait(o.wait or 1.5)
        self:show(fingers(r1, 0.4))
        self:frame(o.after_ms or 200)
        self:show({})
    end

    -- A stroke through the view's touch handlers along pts ({x1, y1, ...},
    -- screen px), a frame every `o.every` points; o.kind "pen" (default) shows
    -- a pen, "finger" a fingertip. Ends with the lift and the stroke finished.
    function G:stroke(view, pts, o)
        o = o or {}
        local every, kind = o.every or 3, o.kind or "pen"
        local function ges(i) return { pos = at(pts[i], pts[i + 1]) } end
        view:onIaTouch(nil, ges(1))
        local k = 0
        for i = 3, #pts - 1, 2 do
            view:onIaPan(nil, ges(i))
            k = k + 1
            if k % every == 0 or i >= #pts - 1 then
                self:show({ { x = pts[i], y = pts[i + 1], kind = kind } })
                self:frame(o.ms or 40)
            end
        end
        view:onIaPanRelease(nil, ges(#pts - 1))
        if o.flush ~= false then view:flushPending() end
        self:show({})
    end

    -- Widgets under w (painted, with a callback) for which pick(widget) is true,
    -- in reading order.
    function G.find(w, pick, out, seen)
        out, seen = out or {}, seen or {}
        if type(w) ~= "table" or seen[w] then return out end
        seen[w] = true
        if pick(w) then out[#out + 1] = w end
        for k, v in pairs(w) do
            if k ~= "show_parent" and k ~= "parent" and k ~= "ui" and k ~= "menu" and type(v) == "table" then
                G.find(v, pick, out, seen)
            end
        end
        return out
    end
    function G.sorted(list)
        table.sort(list, function(a, b)
            if a.dimen.y ~= b.dimen.y then return a.dimen.y < b.dimen.y end
            return a.dimen.x < b.dimen.x
        end)
        return list
    end

    -- The top widget on the screen.
    function G.top()
        local st = UIManager._window_stack
        return st[#st] and st[#st].widget
    end

    return G
end
