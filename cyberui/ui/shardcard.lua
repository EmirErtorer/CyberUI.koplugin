-- A data shard: one highlight with the shard icon (the small data chip) beside
-- it. The words sit in an ordinary panel; the shard says what it is (DATA
-- SHARD, its code, RECOVERED) and which fragment of how many it is, with the
-- book's title.

local Books = require("cyberui/data/books")
local Icon = require("cyberui/ui/icon")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

local ShardCard = {}

-- The lines of the highlight that fit a fixed height, at most `lines`.
local function fitLines(o, pad)
    local th = Theme.get()
    if not o.height then return o.lines end
    local room = o.height - 2 * Text.height("micro") - 2 * pad - 2 * th.space.xs
    return math.max(1, math.min(o.lines, math.floor(room / Text.height(o.text_kind))))
end

-- The card. o: { shard, number, of, lines (3), text_kind ("small"), icon (size
-- of the shard icon), height (fixed), on_tap, on_hold }.
function ShardCard.build(o)
    local th = Theme.get()
    local s = o.shard
    o.lines, o.text_kind = o.lines or 3, o.text_kind or "small"
    local pad = th.space.m
    local from = string.format(_("FRAGMENT %d/%d // %s"), o.number or 1, o.of or 1, Books.info(s.path).title)
    local panel = Panel:new({ shape = "chamfer", corners = "tb", cut = "cut_small", pad = pad, height = o.height,
        on_tap = o.on_tap, on_hold = o.on_hold,
        child = Layout.Row:new({ gap = th.space.m, children = {
            Layout.Column:new({ children = { Icon:new({ name = "shard", size = o.icon or 34 }) } }),
            Layout.Column:new({ grow = true, gap = th.space.xs, children = {
                Layout.Row:new({ children = {
                    Label:new({ text = string.format(_("DATA SHARD // 0x%s"), s.id:sub(1, 4)), kind = "micro", grow = true }),
                    Label:new({ text = _("RECOVERED"), kind = "micro", color = "accent" }),
                } }),
                Label:new({ text = "\u{201C}" .. s.text .. "\u{201D}", kind = o.text_kind, lines = fitLines(o, pad) }),
                Label:new({ text = from, kind = "micro", color = "muted" }),
            } }),
        } }) })
    panel.shard = s
    return panel
end

return ShardCard
