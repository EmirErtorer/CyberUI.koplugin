-- KOReader's dictionary and Wikipedia window in CyberUI's style: the looked-up
-- word over the definition, which pages with a tap; the dictionary's name between
-- arrows that go to the one before and after; the lookups and highlight as icon
-- tiles, the main action (add to the vocabulary builder) as the main button and
-- every other button the window has plainly (they are told apart by the ids
-- KOReader gives them). KOReader still does the looking up,
-- changing dictionary, highlighting, searching and closing. Results made of
-- HTML (some dictionaries) are drawn by KOReader, as they need its renderer.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Specs = require("cyberui/skin/specs")
local Tiles = require("cyberui/skin/tiles")

local Screen = Device.screen

local Skin = {}

-- Does every result of the window come as plain text?
local function plain(dict)
    if dict.is_html then return false end
    for _i, r in ipairs(dict.results or {}) do
        if r.is_html then return false end
    end
    return type(dict.definition) == "string"
end

-- The buttons of the window as KOReader has them now: a button it has
-- switched off (no next dictionary) is off here too.
local function liveRows(dict)
    local rows = {}
    for _i, row in ipairs(Anatomy.buttons(dict)) do
        local copy = {}
        for _j, b in ipairs(row) do
            local c = {}
            for k, v in pairs(b) do c[k] = v end
            local widget = b.id and dict.button_table and dict.button_table:getButtonById(b.id)
            if widget and widget.enabled ~= nil then c.enabled = widget.enabled end
            copy[#copy + 1] = c
        end
        rows[#rows + 1] = copy
    end
    return rows
end

-- The icon tiles of the window, by the id KOReader gives the button, in this order.
local TOOLS = {
    { id = "highlight", icon = "pen" },
    { id = "wikipedia", icon = "library" },
    { id = "translate", icon = "network" },
    { id = "search", icon = "search" },
}
-- The buttons that are the point of the window (adding the word to a list).
local MAIN = { vocabulary = true, save = true }

-- Sort the window's buttons by id: { prev, next, tools, main, close, rest } (each button as KOReader has it now).
local function sort(dict)
    local out = { tools = {}, main = {}, rest = {} }
    local by_id = {}
    for _i, row in ipairs(liveRows(dict)) do
        for _j, b in ipairs(row) do
            if b.id then by_id[b.id] = b end
            if b.id == "prev_dict" then out.prev = b
            elseif b.id == "next_dict" then out.next = b
            elseif b.id == "close" then out.close = b
            elseif MAIN[b.id] then out.main[#out.main + 1] = b
            else out.rest[#out.rest + 1] = b end
        end
    end
    for _i, t in ipairs(TOOLS) do
        local b = by_id[t.id]
        if b then
            out.tools[#out.tools + 1] = { b, { icon = t.icon } }
            for k, r in ipairs(out.rest) do if r == b then table.remove(out.rest, k) break end end
        end
    end
    return out
end

-- The dictionary's name between the arrows that go to the one before and after.
local function dictionaryRow(dict, sorted)
    local Button = require("cyberui/ui/button")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    local function arrow(b, icon)
        if not b then return Layout.Spacer:new({ width = Theme.get().size.touch }) end
        local s = Specs.read(b)
        local usable = s.enabled and s.callback ~= nil
        return Button:new({ icon = icon, variant = "icon", width = Theme.get().size.touch, disabled = not usable, on_tap = usable and s.callback or nil })
    end
    return Layout.Row:new({ gap = Theme.get().space.s, children = {
        arrow(sorted.prev, "back"),
        Label:new({ text = tostring(dict.displaydictname or ""), kind = "mono_small", color = "muted", align = "center", grow = true, lines = 2 }),
        arrow(sorted.next, "forward"),
    } })
end

-- The word at a spot of the definition's current page, or nil.
local function wordAt(body, pos)
    local Text = require("cyberui/gfx/text")
    local lh = Text.height(body.kind)
    local r = math.floor((pos.y - body.y) / lh) + 1
    local line = body.all[(body.state.page - 1) * body.per + r]
    if not line then return nil end
    local chars, at, width = {}, nil, 0
    for ch in line:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        chars[#chars + 1] = ch
        local w = Text.width(body.kind, ch)
        if not at and pos.x - body.x < width + w then at = #chars end
        width = width + w
    end
    if not at then return nil end
    local function letter(ch) return ch:find("^[%w\128-\255'-]") ~= nil end
    if not letter(chars[at]) then return nil end
    local first, last = at, at
    while first > 1 and letter(chars[first - 1]) do first = first - 1 end
    while last < #chars and letter(chars[last + 1]) do last = last + 1 end
    return table.concat(chars, "", first, last)
end

-- The window as it is now.
local function card(dict, state)
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Panel = require("cyberui/ui/panel")
    local ScrollText = require("cyberui/ui/scrolltext")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    local th = Theme.get()
    local large = dict.is_wiki_fullpage or G_reader_settings:isTrue("dict_largewindow") or dict.temp_large_window
    local body = ScrollText:new({
        text = dict.definition, kind = "body", state = state, height = math.floor(Screen:getHeight() * (large and 0.5 or 0.3)),
        on_turn = function() Core.redraw(dict, card(dict, state)) end,
    })
    -- a tap pages the definition; at its end it goes to the next result, as in KOReader
    body.on_tap = function()
        local left = body.touch and body.touch.x < Screen:getWidth() / 2
        if left then
            if not body:turn(-1) then dict:onReadPrevResult() end
        elseif not body:turn(1) then
            dict:onReadNextResult()
        end
    end
    body.on_hold = function()
        local word = body.touch and wordAt(body, body.touch)
        if word then dict:lookupDictionaryOrWikipedia(word) end
    end
    local head = Layout.Row:new({ gap = th.space.m, children = {
        Label:new({ text = tostring(dict.displayword or ""), kind = "display", grow = true, lines = 2 }),
        dict.displaynb and Label:new({ text = tostring(dict.displaynb), kind = "mono_small", color = "muted" }) or nil,
    } })
    local sorted = sort(dict)
    local kids = {
        Label:new({ text = _("// LOOKUP"), kind = "micro", color = "muted" }),
        head,
        dictionaryRow(dict, sorted),
        body,
    }
    if #sorted.tools > 0 then kids[#kids + 1] = Tiles.row(sorted.tools) end
    for _i, b in ipairs(sorted.main) do kids[#kids + 1] = Specs.wide(b, "primary") end
    local lines = {}
    for i = 1, #sorted.rest, 2 do lines[#lines + 1] = { sorted.rest[i], sorted.rest[i + 1] } end
    for _i, r in ipairs(Specs.rows(lines)) do kids[#kids + 1] = r end
    if sorted.close then kids[#kids + 1] = Specs.wide(sorted.close, "ghost") end
    local width = math.min(Screen:getWidth() - 2 * th.space.m, Theme.px(large and 760 or 620))
    return Panel:new({ shape = "chamfer", corners = "tb", fill = "bg", pad = th.space.xl, width = width,
        child = Layout.Column:new({ gap = th.space.s, children = kids }) })
end

Core.register({
    name = "dictionary",
    matches = function(widget)
        return Anatomy.is(widget, "ui/widget/dictquicklookup") and plain(widget)
    end,
    present = function(dict)
        local state = {}
        local function redraw() Core.redraw(dict, card(dict, state)) end
        -- KOReader changes the entry (another dictionary, a new word): the window follows
        local update = dict.update
        dict.update = function(self, ...)
            local r = update(self, ...)
            state.page = 1
            if dict._cyber_popup then redraw() end
            return r
        end
        return {
            element = card(dict, state),
            -- where KOReader puts its window: in the middle, or above or below the word looked up
            place = function(el)
                local region = dict.region or { y = 0, h = Screen:getHeight() }
                local y = region.y + math.floor((region.h - el.h) / 2)
                if dict.align == "top" then y = region.y elseif dict.align == "bottom" then y = region.y + region.h - el.h end
                return math.floor((Screen:getWidth() - el.w) / 2), math.max(0, y)
            end,
            on_outside = function() dict:onClose() end,
            on_back = function() dict:onClose(); return true end,
            on_swipe = function(direction)
                if direction == "west" then dict:onChangeToNextDict() elseif direction == "east" then dict:onChangeToPrevDict() end
            end,
        }
    end,
})

return Skin
