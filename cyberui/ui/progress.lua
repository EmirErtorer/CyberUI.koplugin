-- Progress bars. The plain one is a row of cells filled up to `value` (0 to
-- 1), used for gauges. A book's progress (book = true) is drawn in the
-- reader's chosen style: cells, an ASCII bar, a heart monitor trace, a scan
-- line or an equalizer, each marking clearly how far along the book is.

local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Settings = require("cyberui/settings")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local Progress = Element:extend({ value = 0, segments = 20, cell_h = 12, color = "ink" })

-- The styles a book's progress can be drawn in, and their heights (base px).
Progress.STYLES = {
    { id = "segments", name = _("Segments"), h = 12 },
    { id = "ascii", name = _("ASCII"), h = 16 },
    { id = "heartbeat", name = _("Heartbeat"), h = 36 },
    { id = "scanline", name = _("Scanline"), h = 18 },
    { id = "equalizer", name = _("Equalizer"), h = 24 },
}
local by_id = {}
for _i, s in ipairs(Progress.STYLES) do by_id[s.id] = s end

-- The style of a book's progress.
function Progress.bookStyle()
    return by_id[Settings.get("progress_style", "segments")] or Progress.STYLES[1]
end

-- The style this bar is drawn in.
function Progress:style()
    return self.book and Progress.bookStyle() or by_id.segments
end

-- One cell tall, or the style's height.
function Progress:naturalHeight()
    if self.book then return Theme.px(Progress.bookStyle().h) end
    return Theme.px(self.cell_h)
end

-- Cells filled up to the value, outlined after it.
local function segments(self, bb, x, y, c)
    local th = Theme.get()
    local n = self.segments
    local gap = th.size.segment_gap
    local cell = math.floor((self.w - gap * (n - 1)) / n)
    if cell < 2 then n, cell = math.max(1, math.floor(self.w / 4)), 2 end
    local filled = math.floor(self.v * n + 0.5)
    local hair = th.size.hair
    -- the last cell takes the rounding left over so the bar ends flush
    local cx = x
    for i = 1, n do
        local cw = (i == n) and (x + self.w - cx) or cell
        if i <= filled then Paint.fill(bb, cx, y, cw, self.h, c)
        else Paint.frame(bb, cx, y, cw, self.h, hair, c) end
        cx = cx + cell + gap
    end
end

-- "[#######.......]" in the monospaced face, filled part in the accent.
local function ascii(_self, bb, x, y, c, w, v)
    local kind = "mono"
    local cw = Text.width(kind, "#")
    local n = math.max(4, math.floor(w / cw) - 2)
    local filled = math.floor(v * n + 0.5)
    local cx = x + Text.draw(bb, x, y, kind, "[", c)
    cx = cx + Text.draw(bb, cx, y, kind, string.rep("#", filled), Theme.color("accent"))
    cx = cx + Text.draw(bb, cx, y, kind, string.rep(".", n - filled), Theme.color("muted"))
    Text.draw(bb, cx, y, kind, "]", c)
end

-- A steady pseudo-random number in [0, 1) for beat `i` (the same every draw).
local function jitter(i, salt)
    local v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
    return v - math.floor(v)
end

-- One heartbeat as (fraction through the beat, height) points: P wave,
-- the sharp Q-R-S spike, T wave; heights in between are interpolated.
local WAVE = {
    { 0, 0 }, { 0.28, 0 }, { 0.31, 0.10 }, { 0.34, 0.14 }, { 0.37, 0 },
    { 0.41, 0 }, { 0.43, -0.22 }, { 0.47, 1 }, { 0.51, -0.42 }, { 0.54, 0 },
    { 0.60, 0 }, { 0.65, 0.20 }, { 0.70, 0.26 }, { 0.76, 0 }, { 1, 0 },
}

-- The height of a heartbeat at fraction p (0 to 1) through one beat.
local function beat(p, amp)
    for k = 2, #WAVE do
        local a, b = WAVE[k - 1], WAVE[k]
        if p <= b[1] then
            local t = (p - a[1]) / (b[1] - a[1])
            return amp * (a[2] + (b[2] - a[2]) * t)
        end
    end
    return 0
end

-- A heart monitor trace across the whole bar, each beat with its own length
-- and strength like a real one: solid in the accent up to the reader's
-- place, a thin dotted outline after it, and a bright cursor at the place.
local function heartbeat(_self, bb, x, y, c, w, v, h)
    local mid = y + math.floor(h * 0.62)   -- the spike rises higher than it dips
    local amp = math.floor(h * 0.58)
    local base = Theme.px(52)
    local stroke = math.max(1, Theme.px(2))
    local at = math.floor(w * v)
    local accent, muted = Theme.color("accent"), Theme.color("muted")
    -- the trace's height at every column, beat by beat
    local ys = {}
    local i, start = 0, 0
    while start < w do
        local len = math.floor(base * (0.75 + 0.55 * jitter(i, 1)))
        local a = amp * (0.7 + 0.3 * jitter(i, 2))
        for t = 0, len - 1 do
            if start + t >= w then break end
            ys[start + t] = mid - math.floor(beat(t / len, a))
        end
        start, i = start + len, i + 1
    end
    local prev = mid
    for col = 0, w - 1 do
        local yy = ys[col] or mid
        local top, bottom = math.min(prev, yy), math.max(prev, yy)
        if col < at then
            Paint.fill(bb, x + col, top, stroke, bottom - top + stroke, accent)
        elseif col % 2 == 0 then
            Paint.fill(bb, x + col, top, 1, bottom - top + 1, muted)
        end
        prev = yy
    end
    -- the cursor at the reader's place
    Paint.fill(bb, x + math.min(at, w - stroke), y, stroke, h, c)
    Paint.fill(bb, x + math.min(at, w - 4 * stroke) - stroke, mid - 2 * stroke, 4 * stroke, 4 * stroke, c)
end

-- A thin track with ticks every tenth, a thick bar up to the reader's place
-- and a marker standing on it.
local function scanline(_self, bb, x, y, c, w, v, h)
    local track_y = y + h - Theme.px(6)
    local hair = math.max(1, Theme.get().size.hair)
    local muted = Theme.color("muted")
    Paint.fill(bb, x, track_y + Theme.px(2), w, hair, muted)
    for i = 0, 10 do
        Paint.fill(bb, x + math.min(w - hair, math.floor(w * i / 10)), track_y + Theme.px(4) - Theme.px(2), hair, Theme.px(4), muted)
    end
    local at = math.floor(w * v)
    Paint.fill(bb, x, track_y, at, Theme.px(5), Theme.color("accent"))
    -- the marker: a small block on a stem
    local mw = Theme.px(8)
    local mx = x + math.max(0, math.min(w - mw, at - math.floor(mw / 2)))
    Paint.fill(bb, mx, y, mw, Theme.px(7), c)
    Paint.fill(bb, mx + math.floor(mw / 2) - hair, y, 2 * hair, h - Theme.px(4), c)
end

-- Level-meter bars of varying height, lit up to the reader's place.
local function equalizer(_self, bb, x, y, c, w, v, h)
    local bar, gap = Theme.px(4), Theme.px(2)
    local n = math.max(1, math.floor((w + gap) / (bar + gap)))
    local lit = math.floor(v * n + 0.5)
    local muted = Theme.color("line")
    for i = 0, n - 1 do
        local level = 0.35 + 0.65 * math.abs(math.sin(i * 0.9) * math.cos(i * 0.37))
        local bh = math.max(Theme.px(3), math.floor(h * level))
        local bx = x + i * (bar + gap)
        Paint.fill(bb, bx, y + h - bh, bar, bh, i < lit and (i == lit - 1 and c or Theme.color("accent")) or muted)
    end
end

local DRAW = { segments = segments, ascii = ascii, heartbeat = heartbeat, scanline = scanline, equalizer = equalizer }

-- Draw in the bar's style.
function Progress:draw(bb, x, y)
    self.v = math.max(0, math.min(1, self.value or 0))
    DRAW[self:style().id](self, bb, x, y, Theme.color(self.color), self.w, self.v, self.h)
end

-- Let the reader pick the style of a book's progress.
function Progress.pickStyle()
    local App = require("cyberui/app")
    local cur = Progress.bookStyle().id
    local options = {}
    for _i, s in ipairs(Progress.STYLES) do
        options[#options + 1] = { label = s.name, checked = s.id == cur, on_tap = function()
            Settings.save("progress_style", s.id)
            App.update()
        end }
    end
    App.choose({ title = _("Book progress"), cols = 2, options = options })
end

return Progress
