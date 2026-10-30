-- Choosing what a launcher button opens: a short list of kinds (plugins,
-- plugin actions, KOReader's own actions), each opening a list of what it
-- holds, with the whole KOReader menu as the last way in. Back goes up a
-- list. params: { done(target) }.

local App = require("cyberui/app")
local Frame = require("cyberui/screens/frame")
local Grid = require("cyberui/ui/grid")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local ListRow = require("cyberui/ui/listrow")
local Screen = require("cyberui/screens/screen")
local TargetList = require("cyberui/targetlist")
local Targets = require("cyberui/targets")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local TargetPick = Screen:extend()

-- Start at the top list.
function TargetPick:init(params)
    self.page = 1
    self.levels = { { title = _("What it opens"), rows = TargetList.root(function()
        App.pop()
        Targets.pickMenu(params.done)
    end) } }
end

-- The list showing.
function TargetPick:level()
    return self.levels[#self.levels]
end

-- Up a list; false (leave) at the top.
function TargetPick:onBack()
    if #self.levels > 1 then
        self.levels[#self.levels] = nil
        self.page = 1
        App.update()
        return true
    end
    return false
end

-- A tap on a row: open its list, take its target, or go to the whole menu.
function TargetPick:choose(row)
    if row.rows then
        local rows = row.rows()
        self.levels[#self.levels + 1] = { title = row.label, rows = rows }
        self.page = 1
        return App.update()
    end
    if row.whole then return row.whole() end
    App.pop()
    self.params.done(row.target)
end

-- Build the screen.
function TargetPick:build()
    local th = Theme.get()
    local level = self:level()
    local body = {}
    if #level.rows == 0 then
        body[1] = Label:new({ text = _("Nothing here to pick."), kind = "body", color = "muted", lines = 2 })
    else
        body[1] = Grid:new({
            grow = true, items = level.rows, page = self.page, cols = 1, cell_h = Theme.px(58), gap = 0, row_gap = 0,
            make = function(row)
                return ListRow.build({ icon = row.icon, title = row.label, title_kind = "body", meta = row.sub,
                    value = (row.rows or row.whole) and ">" or nil, on_tap = function() self:choose(row) end })
            end,
            on_layout = function(_cap, pages, page) self.pages, self.page = pages, page end,
        })
        body[2] = Frame.pager(self, _("ITEMS"), function(p) self:setPage(p) end)
    end
    return Frame.page({ screen = self, title = level.title, path = "PICK // TARGET", tab = "settings",
        body = Layout.Column:new({ gap = th.space.m, children = body }) })
end

return TargetPick
