-- The operator ID card (face, handle, rank with its progress, the reading
-- totals, a barcode made from the ID code), and the rank tag and barcode the
-- home masthead borrows from it.

local Avatar = require("cyberui/ui/avatar")
local Button = require("cyberui/ui/button")
local Deco = require("cyberui/ui/deco")
local Format = require("cyberui/format")
local Gigs = require("cyberui/data/gigs")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Paint = require("cyberui/gfx/paint")
local Panel = require("cyberui/ui/panel")
local Profile = require("cyberui/data/profile")
local Progress = require("cyberui/ui/progress")
local StatTile = require("cyberui/ui/stattile")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

local IdCard = {}

-- The rank as a filled tag; `small` for a tag that sits in a line of text.
function IdCard.rankTag(rank, small)
    local th = Theme.get()
    return Panel:new({ shape = "chamfer", corners = "l", cut = "cut_small", fill = "accent", line = false,
        pad = { Theme.px(small and 1 or 3), small and th.space.s or th.space.m },
        child = Label:new({ text = rank.name, kind = small and "micro" or "label", color = "on_accent" }) })
end

-- A barcode that belongs to the ID code, `height` base pixels tall (and
-- `width` wide when given).
function IdCard.codeBars(height, width)
    return Deco.Barcode:new({ bars = Paint.barsFrom(Profile.rng(Profile.id())), height = Theme.px(height),
        width = width and Theme.px(width) or nil })
end

-- "2025-03" from a time, or a dash.
local function monthOf(t)
    return t and os.date("%Y-%m", t) or "-"
end

-- The full card. o: { on_photo (tap the face), on_handle (tap the handle),
-- width (floating: a narrow card, everything stacked), footer (an element
-- under the rest) }.
function IdCard.full(o)
    local th = Theme.get()
    local handle = Profile.handle()
    local stats = Profile.stats()
    local rank = Profile.rank(stats.hours)
    local face = Layout.Column:new({ gap = th.space.s, width = Theme.px(96), children = {
        Avatar:new({ seed = handle, size = 96, on_tap = o.on_photo }),
        Button:new({ icon = "image", label = _("PHOTO"), variant = "chip", height = Theme.px(34), on_tap = o.on_photo }),
    } })
    local who = Layout.Column:new({ grow = true, gap = th.space.xs, children = {
        Label:new({ text = _("HANDLE"), kind = "micro", color = "muted" }),
        Panel:new({ shape = "none", child = Label:new({ text = handle, kind = "display" }), on_tap = o.on_handle }),
        Label:new({ text = _("RANK"), kind = "micro", color = "muted" }),
        Layout.Row:new({ gap = th.space.m, children = {
            IdCard.rankTag(rank),
            Label:new({ text = string.format(_("LVL %d / %d"), rank.index, rank.count), kind = "mono_small", color = "muted" }),
        } }),
    } })
    local next_line = rank.next
        and { string.format(_("NEXT: %s"), rank.next), string.format(_("%.0f / %d H"), stats.hours, rank.need) }
        or { _("TOP RANK REACHED"), string.format(_("%.0f H"), stats.hours) }
    local tiles = Layout.Column:new({ gap = th.space.s, children = {
        Layout.Row:new({ gap = th.space.s, children = {
            StatTile(_("HOURS"), string.format("%.1f", stats.hours)),
            StatTile(_("PAGES"), Format.number(stats.pages)),
            StatTile(_("BOOKS"), tostring(stats.books)),
        } }),
        Layout.Row:new({ gap = th.space.s, children = {
            StatTile(_("BEST RUN"), string.format(_("%dD"), stats.best_run)),
            StatTile(_("DAYS READ"), tostring(stats.days)),
            StatTile(_("SINCE"), monthOf(stats.since)),
        } }),
        Layout.Row:new({ gap = th.space.s, children = {
            StatTile(_("EDDIES"), Format.credits(Gigs.balance())),
            StatTile(_("GIGS DONE"), tostring(select(2, Gigs.totals()))),
        } }),
    } })
    local progress = Layout.Column:new({ children = {
        Layout.Row:new({ children = {
            Label:new({ text = next_line[1], kind = "mono_small", grow = true }),
            Label:new({ text = next_line[2], kind = "mono_small", color = "muted" }),
        } }),
        Progress:new({ value = rank.value }),
    } })
    local code = Layout.Row:new({ gap = th.space.m, children = {
        Layout.Column:new({ width = Theme.px(150), children = { IdCard.codeBars(26) } }),
        Label:new({ text = "ID " .. Profile.id(), kind = "mono_small", grow = true, align = "right" }), -- i18n: keep
    } })
    -- a wide, short screen puts the totals beside the identity
    local screen = require("device").screen
    local body
    if not o.width and screen:getWidth() > screen:getHeight() then
        body = Layout.Row:new({ gap = th.space.l, valign = "stretch", children = {
            Layout.Column:new({ grow = true, gap = th.space.m, children = { Layout.Row:new({ gap = th.space.l, valign = "stretch", children = { face, who } }), progress, code } }),
            (function() tiles.grow = true; return tiles end)(),
        } })
    else
        body = Layout.Column:new({ gap = th.space.m, children = {
            Layout.Row:new({ gap = th.space.l, valign = "stretch", children = { face, who } }), progress, tiles, code } })
    end
    if o.footer then table.insert(body.children, o.footer) end
    return Panel:new({ shape = "header", title = _("OPERATOR // ID-CARD"), title_right = _("AUTH OK"), pad = th.space.l, width = o.width,
        fill = o.width and "bg" or nil, child = body })
end

return IdCard
