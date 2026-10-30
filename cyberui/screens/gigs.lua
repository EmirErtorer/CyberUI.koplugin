-- Gigs: the backlog as paid work. Three tabs: the open gigs (books waiting
-- for a week or more, the oldest as a poster, with a note on how gigs pay),
-- the gigs taken and how far each has paid, and the payouts so far. The
-- balance is in the header; it only ever goes up by reading.

local Actions = require("cyberui/actions")
local App = require("cyberui/app")
local Books = require("cyberui/data/books")
local Button = require("cyberui/ui/button")
local Controls = require("cyberui/ui/controls")
local Cover = require("cyberui/ui/cover")
local Format = require("cyberui/format")
local Frame = require("cyberui/screens/frame")
local Gigs = require("cyberui/data/gigs")
local Ledger = require("cyberui/data/ledger")
local Grid = require("cyberui/ui/grid")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local ListRow = require("cyberui/ui/listrow")
local Panel = require("cyberui/ui/panel")
local Progress = require("cyberui/ui/progress")
local Screen = require("cyberui/screens/screen")
local StatTile = require("cyberui/ui/stattile")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

local GigsScreen = Screen:extend()

-- Start on the open gigs, first page.
function GigsScreen:init()
    self.tab, self.page = "open", 1
end

-- What holding a gig offers: take it, see the book, or say it is not wanted.
local function holdSheet(g)
    local info = Books.info(g.path)
    App.sheet({ title = info.title, sub = string.format(_("PAYS %s"), Format.credits(g.price)), cols = 1, actions = {
        { icon = "forward", label = _("Take the gig"), sub = _("Open the book"), on_tap = function() Actions.open(g.path) end },
        { icon = "eye", label = _("Details"), on_tap = function() Actions.details(g.path) end },
        { icon = "close", label = _("Not wanted"), sub = _("Take it off the board"), on_tap = function()
            Gigs.skip(g.path)
            App.update()
        end },
    } })
end

-- How the gigs pay, in a note.
local function explainer()
    local th = Theme.get()
    return Panel:new({ shape = "brackets", label = _("HOW_GIGS_WORK"), pad = th.space.m,
        child = Label:new({ kind = "small", color = "muted", lines = 6,
            text = _("A book that sits unread for a week becomes a gig. Open it to take the gig and fix its price. Every 10% you read pays a twentieth of the price, and finishing pays the other half. Longer books and longer waits pay more.") }) })
end

-- The poster of the oldest open gig.
local function poster(g)
    local th = Theme.get()
    local info = Books.info(g.path)
    local step, finish = Gigs.split(g.price)
    return Panel:new({ shape = "brackets", label = _("TOP_GIG"), pad = th.space.l, on_hold = function() holdSheet(g) end,
        child = Layout.Row:new({ gap = th.space.l, valign = "stretch", children = {
            Cover:new({ path = g.path, width = Theme.px(96), height = Theme.px(140), on_tap = function() Actions.details(g.path) end }),
            Layout.Column:new({ grow = true, gap = th.space.xs, children = {
                Label:new({ text = info.title, kind = "display", lines = 2 }),
                Label:new({ text = info.author or "", kind = "body", color = "muted" }),
                Label:new({ kind = "mono_small", color = "muted",
                    text = string.format(_.n("AT LARGE %d DAY", "AT LARGE %d DAYS", g.days), g.days) .. " // "
                        .. string.format(_.n("~%d PAGE", "~%d PAGES", g.pages), g.pages) }), -- i18n: keep
                Label:new({ text = string.format(_("%s PER 10%% // %s ON FINISH"), Format.credits(step), Format.credits(finish)),
                    kind = "mono_small", color = "muted" }),
                Layout.Row:new({ valign = "center", children = {
                    Label:new({ text = Format.credits(g.price), kind = "hero", grow = true }),
                    Button:new({ label = _("TAKE GIG"), icon = "forward", variant = "primary", on_tap = function() Actions.open(g.path) end }),
                } }),
            } }),
        } }) })
end

-- A paged list of `items` made by `make`.
local function paged(self, items, make)
    return Grid:new({
        grow = true, items = items, page = self.page, cols = 1, cell_h = Theme.px(56), gap = 0, row_gap = 0, make = make,
        on_layout = function(_cap, pages, page) self.pages, self.page = pages, page end,
    })
end

-- A message for a tab with nothing in it.
local function empty(title, text)
    local th = Theme.get()
    return Layout.Column:new({ gap = th.space.m, children = {
        Label:new({ text = title, kind = "display", lines = 2 }),
        Label:new({ text = text, kind = "body", color = "muted", lines = 4 }),
    } })
end

-- The open gigs.
function GigsScreen:openTab()
    local th = Theme.get()
    local list = Gigs.board()
    if #list == 0 then
        return Layout.Column:new({ gap = th.space.m, children = { explainer(),
            empty(_("NO OPEN GIGS"), _("Every book in the library has been opened, or is still new. Books that sit unread for a week become gigs here.")) } })
    end
    local rest = {}
    for i = 2, #list do rest[#rest + 1] = list[i] end
    local grid = paged(self, rest, function(g)
        return ListRow.build({ path = g.path, title = Books.info(g.path).title, title_kind = "body",
            meta = string.format(_.n("AT LARGE %d DAY", "AT LARGE %d DAYS", g.days), g.days), value = Format.credits(g.price),
            on_tap = function() Actions.details(g.path) end, on_hold = function() holdSheet(g) end })
    end)
    return Layout.Column:new({ gap = th.space.m, grow = true, children = {
        self.page == 1 and explainer() or Layout.Spacer:new({ height = 0 }), poster(list[1]), grid,
        Frame.pager(self, _("GIGS"), function(p) self:setPage(p) end),
    } })
end

-- The gigs taken, each with a bar of its ten payouts.
function GigsScreen:activeTab()
    local th = Theme.get()
    local list = Gigs.active()
    if #list == 0 then
        return empty(_("NO GIGS TAKEN"), _("Take an open gig and start reading. It shows up here and pays as you read."))
    end
    local grid = Grid:new({
        grow = true, items = list, page = self.page, cols = 1, cell_h = Theme.px(84), gap = 0, row_gap = 0,
        make = function(g)
            local step = Gigs.split(g.price)
            return Panel:new({ shape = "none", pad = th.space.s, on_tap = function() Actions.open(g.path) end,
                child = Layout.Row:new({ gap = th.space.m, valign = "center", children = {
                    Cover:new({ path = g.path, width = Theme.px(40), height = Theme.px(60) }),
                    Layout.Column:new({ grow = true, gap = th.space.xs, children = {
                        Label:new({ text = Books.info(g.path).title, kind = "body" }),
                        Progress:new({ value = g.milestones / 10, segments = 10 }),
                        Label:new({ text = string.format(_("%s OF %s PAID"), Format.credits(g.milestones * step), Format.credits(g.price)),
                            kind = "mono_small", color = "muted" }),
                    } }),
                } }) })
        end,
        on_layout = function(_cap, pages, page) self.pages, self.page = pages, page end,
    })
    return Layout.Column:new({ gap = th.space.m, grow = true, children = { grid,
        Frame.pager(self, _("GIGS"), function(p) self:setPage(p) end) } })
end

-- The payouts so far, newest first, under the totals.
function GigsScreen:payoutsTab()
    local th = Theme.get()
    local earned, done = Ledger.totals()
    local tiles = Layout.Row:new({ gap = th.space.s, children = {
        StatTile(_("BALANCE"), Format.credits(Ledger.balance())), StatTile(_("EARNED"), Format.credits(earned)),
        StatTile(_("GIGS DONE"), tostring(done)),
    } })
    local list = Gigs.recent(60)
    if #list == 0 then
        return Layout.Column:new({ gap = th.space.m, children = { tiles,
            empty(_("NO PAYOUTS YET"), _("Read a gig to earn eddies. Each payout is listed here.")) } })
    end
    local grid = paged(self, list, function(p)
        return ListRow.build({ path = p.path, title = Books.info(p.path).title, title_kind = "body",
            meta = p.kind == "f" and _("GIG FINISHED") or string.format(_("%d%% READ"), p.n * 10), value = "+" .. Format.credits(p.amount) })
    end)
    return Layout.Column:new({ gap = th.space.m, grow = true, children = { tiles, grid,
        Frame.pager(self, _("PAYOUTS"), function(p) self:setPage(p) end) } })
end

-- Build the screen.
function GigsScreen:build()
    local th = Theme.get()
    local tabs = Controls.Segmented({ options = { { _.c("gigs tab", "Open"), "open" }, { _("Active"), "active" }, { _("Payouts"), "payouts" } },
        value = self.tab, kind = "label", on_change = function(v) self.tab, self.page = v, 1; App.update() end })
    local kids = { tabs, self[self.tab .. "Tab"](self) }
    local bad = Ledger.rejected()
    if bad > 0 then
        kids[#kids + 1] = Label:new({ text = string.format(_.n("%d LEDGER ENTRY FAILED THE CHECK", "%d LEDGER ENTRIES FAILED THE CHECK", bad), bad),
            kind = "micro", color = "muted" })
    end
    local shop = Button:new({ icon = "shop", label = _("SHOP"), variant = "secondary", height = th.size.touch,
        on_tap = function() App.push("shop") end })
    return Frame.page({ screen = self, title = _("GIGS"), actions = { shop }, path = string.format(_("GIGS // BALANCE %s"), Format.credits(Ledger.balance())),
        tab = "library", body = Layout.Column:new({ gap = th.space.m, children = kids }) })
end

return GigsScreen
