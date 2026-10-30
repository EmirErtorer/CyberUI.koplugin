-- The bounty board: the books never opened, oldest first, each with a bounty
-- that grows by the day. The oldest has a wanted poster of its own; the rest
-- are a paged list. A tap opens the book's details, holding offers the rest.

local Actions = require("cyberui/actions")
local App = require("cyberui/app")
local Bounty = require("cyberui/data/bounty")
local Books = require("cyberui/data/books")
local Button = require("cyberui/ui/button")
local Cover = require("cyberui/ui/cover")
local Format = require("cyberui/format")
local Frame = require("cyberui/screens/frame")
local Grid = require("cyberui/ui/grid")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local ListRow = require("cyberui/ui/listrow")
local Panel = require("cyberui/ui/panel")
local Screen = require("cyberui/screens/screen")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local BountyScreen = Screen:extend()

-- Start on the first page.
function BountyScreen:init()
    self.page = 1
end

-- What holding a row offers: open it, see it, or say it is not wanted.
local function holdSheet(b)
    local info = Books.info(b.path)
    App.sheet({ title = info.title, sub = string.format(_("%s ON ITS HEAD"), Format.credits(b.reward)), cols = 1, actions = {
        { icon = "forward", label = _("Claim it"), sub = _("Open the book"), on_tap = function() Actions.open(b.path) end },
        { icon = "eye", label = _("Details"), on_tap = function() Actions.details(b.path) end },
        { icon = "close", label = _("Not wanted"), sub = _("Take it off the board"), on_tap = function()
            Bounty.skip(b.path)
            App.update()
        end },
    } })
end

-- The poster of the most wanted book.
local function poster(b)
    local th = Theme.get()
    local info = Books.info(b.path)
    return Panel:new({ shape = "brackets", label = _("MOST_WANTED"), pad = th.space.l, on_hold = function() holdSheet(b) end,
        child = Layout.Row:new({ gap = th.space.l, valign = "stretch", children = {
            Cover:new({ path = b.path, width = Theme.px(96), height = Theme.px(140), on_tap = function() Actions.details(b.path) end }),
            Layout.Column:new({ grow = true, gap = th.space.xs, children = {
                Label:new({ text = _("WANTED"), kind = "micro", color = "muted" }),
                Label:new({ text = info.title, kind = "display", lines = 2 }),
                Label:new({ text = info.author or "", kind = "body", color = "muted" }),
                Label:new({ text = string.format(_("AT LARGE %d DAYS"), b.days), kind = "mono_small", color = "muted" }),
                Layout.Row:new({ valign = "center", children = {
                    Label:new({ text = Format.credits(b.reward), kind = "hero", grow = true }),
                    Button:new({ label = _("CLAIM"), icon = "forward", variant = "primary", on_tap = function() Actions.open(b.path) end }),
                } }),
            } }),
        } }) })
end

-- Build the board.
function BountyScreen:build()
    local th = Theme.get()
    local list = Bounty.list()
    local body
    if #list == 0 then
        body = Layout.Column:new({ gap = th.space.m, children = {
            Label:new({ text = _("NO OUTSTANDING TARGETS"), kind = "display", lines = 2 }),
            Label:new({ text = _("Every book in the library has been opened, or is still new. Books that sit unread for a week appear here with a bounty on them."),
                kind = "body", color = "muted", lines = 4 }),
        } })
    else
        local rest = {}
        for i = 2, #list do rest[#rest + 1] = list[i] end
        local grid = Grid:new({
            grow = true, items = rest, page = self.page, cols = 1, cell_h = Theme.px(56), gap = 0, row_gap = 0,
            make = function(b)
                return ListRow.build({ path = b.path, title = Books.info(b.path).title, title_kind = "body",
                    meta = string.format(_("AT LARGE %d DAYS"), b.days), value = Format.credits(b.reward),
                    on_tap = function() Actions.details(b.path) end, on_hold = function() holdSheet(b) end })
            end,
            on_layout = function(_cap, pages, page) self.pages, self.page = pages, page end,
        })
        body = Layout.Column:new({ gap = th.space.m, children = {
            poster(list[1]), grid, Frame.pager(self, _("WANTED"), function(p) self:setPage(p) end),
        } })
    end
    return Frame.page({ screen = self, title = _("Bounties"), path = string.format(_("MOST WANTED // %s ON THE BOARD"), Format.credits(Bounty.total())),
        tab = "library", body = body })
end

return BountyScreen
