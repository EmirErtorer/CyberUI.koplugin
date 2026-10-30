-- The data shards: every highlight in the library as a fragment, all of them
-- or book by book. A tap opens a shard whole.

local App = require("cyberui/app")
local Books = require("cyberui/data/books")
local Button = require("cyberui/ui/button")
local Controls = require("cyberui/ui/controls")
local Frame = require("cyberui/screens/frame")
local Grid = require("cyberui/ui/grid")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local ListRow = require("cyberui/ui/listrow")
local Screen = require("cyberui/screens/screen")
local ShardCard = require("cyberui/ui/shardcard")
local Shards = require("cyberui/data/shards")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local ShardsScreen = Screen:extend()

-- Start with all the shards on the first page; params.book shows one book's.
function ShardsScreen:init(params)
    self.page = 1
    self.tab = params.book and "book" or "all"
    self.book = params.book
end

-- Back from one book's shards to the list of books.
function ShardsScreen:onBack()
    if self.tab == "book" and not self.params.book then
        self.tab, self.book, self.page = "books", nil, 1
        App.update()
        return true
    end
    return false
end

-- What the grid lists: shards ({ shard, number }) or books.
function ShardsScreen:items()
    if self.tab == "books" then return Shards.booksWith() end
    local out, source = {}, self.tab == "book" and Shards.ofBook(self.book) or Shards.all()
    for i, s in ipairs(source) do out[i] = { shard = s, number = i, of = #source } end
    return out
end

-- Build one cell: a shard card, or a book with its count.
function ShardsScreen:cell(item, h)
    if self.tab == "books" then
        return ListRow.build({ path = item.path, title = Books.info(item.path).title, title_kind = "body",
            meta = string.format(_("%d SHARDS"), item.count),
            on_tap = function() self.tab, self.book, self.page = "book", item.path, 1; App.update() end })
    end
    return ShardCard:new({ shard = item.shard, number = item.number, of = item.of, height = h, lines = 3,
        on_tap = function() App.push("shard", { shard = item.shard, number = item.number, of = item.of }) end })
end

-- Build the screen.
function ShardsScreen:build()
    local th = Theme.get()
    local items = self:items()
    local tabs = Controls.Segmented({ options = { { _("ALL"), "all" }, { _("BY BOOK"), "books" } },
        value = self.tab == "all" and "all" or "books", kind = "label",
        on_change = function(v) self.tab, self.book, self.page = v, nil, 1; App.update() end })
    local body = { tabs }
    if #items == 0 then
        body[#body + 1] = Label:new({ text = _("NO SHARDS YET"), kind = "display" })
        body[#body + 1] = Label:new({ text = _("Highlight text while reading and each highlight is recovered here as a data shard. Books already highlighted are collected in the background."),
            kind = "body", color = "muted", lines = 4 })
    else
        body[#body + 1] = Grid:new({
            grow = true, items = items, page = self.page, cols = 1, cell_h = self.tab == "books" and Theme.px(56) or Theme.px(104), gap = 0,
            row_gap = self.tab == "books" and 0 or th.space.s,
            make = function(item, _w, h) return self:cell(item, h) end,
            on_layout = function(_cap, pages, page) self.pages, self.page = pages, page end,
        })
        body[#body + 1] = Frame.pager(self, _("SHARDS"), function(p) self:setPage(p) end)
    end
    local random = Button:new({ icon = "shard", variant = "icon", width = th.size.touch, on_tap = function()
        local pick = Shards.another()
        if pick then App.push("shard", { shard = pick.shard, number = pick.number, of = pick.of }) end
    end })
    return Frame.page({ screen = self, title = _("Data shards"), path = string.format(_("RECOVERED // %d FRAGMENTS"), Shards.count()),
        tab = "history", actions = { random }, body = Layout.Column:new({ gap = th.space.m, children = body }) })
end

return ShardsScreen
