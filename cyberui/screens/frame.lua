-- The frame every screen but home shares: status bar, header, the screen's
-- body and the tab bar, with the page margins in one place.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Header = require("cyberui/ui/header")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local PagedColumn = require("cyberui/ui/pagedcolumn")
local StatusBar = require("cyberui/ui/statusbar")
local TabBar = require("cyberui/ui/tabbar")
local Theme = require("cyberui/theme")

local Frame = {}

-- Build a page. o: { screen, title, path, actions, body, tab, back }.
-- The screen keeps its clock label so the app can tick it.
function Frame.page(o)
    local th = Theme.get()
    local side = th.space.xl
    local status, clock = StatusBar.build()
    o.screen.clock = clock
    local back = o.back ~= false and function() App.back() end or nil
    local top = Layout.Column:new({ pad = { th.space.s, side, 0, side }, gap = th.space.m, children = {
        status,
        Header.build({ title = o.title, path = o.path, on_back = back, actions = o.actions }),
    } })
    o.body.grow = true
    local body = Layout.Column:new({ grow = true, pad = { th.space.m, side, th.space.m, side }, children = { o.body } })
    local tabs = TabBar.build(App.TABS, o.tab, function(id) App.go(id) end)
    return Layout.Column:new({ children = { top, body, tabs } })
end

-- A paging row: first / previous, "LABEL 03 / 24" with page cells, next / last.
-- `state` holds page and pages (filled in by the grid's on_layout).
function Frame.pager(state, label, on_page)
    local th = Theme.get()
    local w = Theme.px(46)
    return Layout.Row:new({ gap = th.space.s, children = {
        Button:new({ icon = "first", variant = "icon", width = w, on_tap = function() on_page(1) end }),
        Button:new({ icon = "back", variant = "icon", width = w, on_tap = function() on_page(state.page - 1) end }),
        Label:new({ grow = true, kind = "mono", align = "center",
            text_fn = function() return string.format("%s %02d / %02d", label, state.page, state.pages or 1) end }),
        Button:new({ icon = "forward", variant = "icon_on", width = w, on_tap = function() on_page(state.page + 1) end }),
        Button:new({ icon = "last", variant = "icon", width = w, on_tap = function() on_page(state.pages or 1) end }),
    } })
end

-- A column of `items` that pages when it is too long, paged by the screen's
-- own `page` and `pages` (so swipes work too) with a paging row labelled
-- `label`.
function Frame.paged(screen, items, label)
    return PagedColumn:new({
        items = items, grow = true, page = screen.page or 1, gap = Theme.get().space.m,
        make_pager = function(pc) return Frame.pager(pc, label, function(p) screen:setPage(p) end) end,
        on_layout = function(pages, page) screen.pages, screen.page = pages, page end,
    })
end

return Frame
