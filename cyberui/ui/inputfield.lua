-- A text field in the style: an outlined box with a prompt, the text wrapped
-- over as many lines as it is given, and a block cursor. It owns no text: the
-- owner says what the text is and where the cursor is (`get`), and what a tap
-- on a spot of the text means (`on_caret`). With `active` (a function) the
-- field is drawn lit while it is the one being typed into. Used for typing on CyberUI's own
-- keyboard and for KOReader's input dialogs.

local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local InputField = Element:extend({ kind = "mono", lines = 1, prompt = "> " })


-- The inner padding of the box.
local function padding()
    return Theme.get().space.m
end

-- One character's width (cached per kind by Text).
local function charWidth(kind, ch)
    return Text.width(kind, ch)
end

-- Cut `chars` into lines that fit `max_w`: a list of { first, last } character
-- positions. A line breaks at the last space that fits when there is one, else
-- inside the word; a newline always breaks and belongs to the line it ends.
local function wrap(kind, chars, max_w)
    local lines, first, width, space = {}, 1, 0, nil
    local i, n = 1, #chars
    while i <= n do
        local ch = chars[i]
        if ch == "\n" then
            lines[#lines + 1] = { first = first, last = i }
            first, width, space = i + 1, 0, nil
        else
            local w = charWidth(kind, ch)
            if width + w > max_w and i > first then
                local cut = (space and space > first) and space or (i - 1)
                lines[#lines + 1] = { first = first, last = cut }
                first, width, space = cut + 1, 0, nil
                i = cut   -- start over from the char after the cut
            else
                width = width + w
                if ch == " " then space = i end
            end
        end
        i = i + 1
    end
    lines[#lines + 1] = { first = first, last = n }   -- the last line (empty when the text ends in a newline)
    return lines
end

-- The characters of the text shown (masked for a password).
local function shownChars(chars, mask)
    if not mask then return chars end
    local out = {}
    for i, ch in ipairs(chars) do out[i] = ch == "\n" and ch or "*" end
    return out
end

-- Height: a prompt line's worth per visible line, plus the padding.
function InputField:naturalHeight()
    return Text.height(self.kind) * self.lines + 2 * padding()
end

-- Read the text and the cursor again and wrap it for the width: the owner may
-- have changed them since the field was laid out (typing repaints the field alone).
function InputField:refresh()
    local chars, caret, mask = self.get()
    self.chars, self.caret = shownChars(chars, mask), caret
    self.rows = wrap(self.kind, self.chars, self.avail)
    -- keep the line with the cursor in view
    local at = #self.rows
    if self.caret then
        for r, line in ipairs(self.rows) do
            if self.caret >= line.first and self.caret <= line.last + 1 and (r == #self.rows or self.caret <= line.last) then at = r; break end
        end
    end
    local top = self.state.top or 1
    if at < top then top = at elseif at > top + self.visible - 1 then top = at - self.visible + 1 end
    self.state.top = math.max(1, math.min(top, math.max(1, #self.rows - self.visible + 1)))
    self.caret_row = at
end

-- Lay the box out for the width given.
function InputField:layout(w, h)
    self.w = self.width or w or 0
    local lh = Text.height(self.kind)
    self.h = self.height or h or self:naturalHeight()
    self.visible = math.max(1, math.floor((self.h - 2 * padding()) / lh))
    self.state = self.state or {}
    self.text_x = padding() + (self.prompt and Text.width(self.kind, self.prompt) or 0)
    self.avail = math.max(1, self.w - self.text_x - padding() - Theme.px(9))
    self:refresh()
    if self.on_caret then self.on_tap = function() self:place() end end
end

-- The text of a line (a trailing newline is not drawn).
local function lineText(chars, line)
    local parts = {}
    for i = line.first, line.last do
        if chars[i] ~= "\n" then parts[#parts + 1] = chars[i] end
    end
    return table.concat(parts)
end

-- Draw the box, the visible lines and the cursor.
function InputField:draw(bb, x, y)
    self:refresh()
    local th = Theme.get()
    local lh = Text.height(self.kind)
    Paint.fill(bb, x, y, self.w, self.h, th.c.bg)
    local lit = self.active and self.active()   -- the field the keyboard types into, among several
    Paint.frame(bb, x, y, self.w, self.h, th.size.stroke * (lit and 2 or 1), self.readonly and th.c.muted or (lit and th.c.accent or th.c.ink))
    local tx, ty = x + self.text_x, y + padding()
    if self.prompt then Text.draw(bb, x + padding(), ty, self.kind, self.prompt, th.c.muted) end
    local cursor_w = Theme.px(9)
    if #self.chars == 0 then
        if self.hint and self.hint ~= "" then
            Text.draw(bb, tx + cursor_w + Theme.px(4), ty, self.kind, Text.fit(self.kind, self.hint, self.avail - cursor_w), th.c.muted)
        end
        if not self.readonly then Paint.fill(bb, tx, ty, cursor_w, lh, th.c.ink) end
        return
    end
    for r = 0, self.visible - 1 do
        local line = self.rows[self.state.top + r]
        if not line then break end
        local ly = ty + r * lh
        Text.draw(bb, tx, ly, self.kind, lineText(self.chars, line), th.c.ink)
        if self.caret and not self.readonly and self.state.top + r == self.caret_row then
            local before = lineText(self.chars, { first = line.first, last = math.min(self.caret - 1, line.last) })
            local cx = tx + Text.width(self.kind, before)
            Paint.fill(bb, cx, ly, cursor_w, lh, th.c.ink)
            local under = self.chars[self.caret]
            if under and under ~= "\n" then Text.draw(bb, cx, ly, self.kind, under, th.c.bg) end
        end
    end
end

-- A tap on the text: the character under it (or the end of the line) becomes the cursor.
function InputField:place()
    local pos = self.touch
    if not pos or not self.on_caret then return end
    local lh = Text.height(self.kind)
    local r = math.max(0, math.min(self.visible - 1, math.floor((pos.y - self.y - padding()) / lh)))
    local line = self.rows[self.state.top + r] or self.rows[#self.rows]
    local x = pos.x - (self.x + self.text_x)
    local at, width = line.first, 0
    while at <= line.last and self.chars[at] ~= "\n" do
        local w = charWidth(self.kind, self.chars[at])
        if width + w / 2 > x then break end
        width = width + w
        at = at + 1
    end
    self.on_caret(at)
end

return InputField
