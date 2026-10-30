-- The goal tab: books finished this year against the reader's target, the
-- achievements earned, and the year's finished books on a shelf.

local Achievements = require("cyberui/data/achievements")
local Actions = require("cyberui/actions")
local App = require("cyberui/app")
local BookTile = require("cyberui/ui/booktile")
local Button = require("cyberui/ui/button")
local Controls = require("cyberui/ui/controls")
local Frame = require("cyberui/screens/frame")
local Goal = require("cyberui/data/goal")
local Grid = require("cyberui/ui/grid")
local Insights = require("cyberui/data/insights")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Progress = require("cyberui/ui/progress")
local Skyline = require("cyberui/ui/skyline")
local Theme = require("cyberui/theme")
local navrow = require("cyberui/ui/navrow")
local tile = require("cyberui/ui/stattile")
local _ = require("gettext")

local GoalTab = {}

local PER_ROW = 6   -- chips to a row, so every level fits its chip

-- A ladder of achievements: its name and one chip per level, filled when
-- earned, six to a row.
local function ladder(l)
    local th = Theme.get()
    local rows = {}
    for i = 1, #l.items, PER_ROW do
        local kids = { Label:new({ text = i == 1 and l.name or "", kind = "micro", color = "muted", width = Theme.px(76) }) }
        for j = i, math.min(#l.items, i + PER_ROW - 1) do
            local a = l.items[j]
            kids[#kids + 1] = Button:new({ label = a.short, kind = "micro", variant = a.got and "chip_on" or "chip", grow = true, height = Theme.px(30) })
        end
        rows[#rows + 1] = Layout.Row:new({ gap = th.space.xs, children = kids })
    end
    return Layout.Column:new({ gap = th.space.xs, children = rows })
end

-- The year as a skyline of 52 weeks: pages and minutes read each week, a sign
-- on a week a book was finished, the months' initials underneath.
local function yearSkyline(year, shelf)
    local weeks = {}
    for w = 1, 52 do weeks[w] = { pages = 0, minutes = 0 } end
    local function weekOf(time) return math.min(52, math.floor((tonumber(os.date("%j", time)) - 1) / 7) + 1) end
    for _i, d in ipairs(Insights.days()) do
        if d.date:sub(1, 4) == tostring(year) then
            local b = weeks[weekOf(d.time)]
            b.pages, b.minutes = b.pages + d.pages, b.minutes + d.seconds / 60
        end
    end
    for _i, b in ipairs(shelf) do
        local y, m, d = (b.date or ""):match("^(%d+)-(%d+)-(%d+)")
        if y then weeks[weekOf(os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }))].sign = true end
    end
    local now = os.date("*t")
    if year == now.year then weeks[weekOf(os.time())].current = true end
    local labels = {}
    for m, initial in ipairs({ "J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D" }) do
        labels[weekOf(os.time({ year = year, month = m, day = 1, hour = 12 }))] = initial
    end
    return Skyline:new({ buildings = weeks, labels = labels, minutes_per_window = 60, height = 104 })
end

-- Build the tab; `screen.goal_back` is how many years back from this one.
function GoalTab.build(screen)
    local th = Theme.get()
    local year = tonumber(os.date("%Y")) - screen.goal_back
    local target = Goal.target()
    local shelf = Goal.finishedIn(year)
    local streaks = Insights.streaks()
    local numbers = { hours = Insights.allTime().seconds / 3600, streak = streaks.day_best, finished = #Goal.finished() }
    local ladders = Achievements.ladders(numbers)
    local got, latest = Achievements.summary(ladders)

    local nav = navrow({ label = string.format("ARCHIVE_%d", year), can_next = screen.goal_back > 0,
        on_prev = function() screen.goal_back, screen.page = screen.goal_back + 1, 1; App.update() end,
        on_next = function() screen.goal_back, screen.page = screen.goal_back - 1, 1; App.update() end })
    local goal = Layout.Column:new({ gap = th.space.s, children = {
        Layout.Row:new({ gap = th.space.m, children = {
            tile(_("FINISHED"), string.format("%d/%d", #shelf, target), string.format(_("%d%% OF THE GOAL"), math.floor(math.min(#shelf / target, 1) * 100))),
            tile(_("ACHIEVED"), tostring(got), latest or _("NONE YET")),
            Layout.Column:new({ children = {
                Label:new({ text = _("YEAR GOAL"), kind = "micro", color = "muted" }),
                Controls.Stepper({ value = target, min = 1, max = 999, step = 1, format = function(v) return tostring(v) end, value_w = 48,
                    on_change = function(v) Goal.setTarget(v); App.update() end }),
            } }),
        } }),
        Progress:new({ value = math.min(#shelf / target, 1) }),
    } })
    local body = { nav, goal }
    -- (a wide, short screen has no room for it)
    local screen_dev = require("device").screen
    if screen_dev:getWidth() <= screen_dev:getHeight() then body[#body + 1] = yearSkyline(year, shelf) end
    for _i, l in ipairs(ladders) do body[#body + 1] = ladder(l) end
    if #shelf == 0 then
        body[#body + 1] = Label:new({ grow = true, text = _("NO BOOKS FINISHED THIS YEAR. MARK A BOOK DONE AND IT SHELVES HERE."), kind = "small", color = "muted", lines = 3 })
    else
        body[#body + 1] = Grid:new({ grow = true, items = shelf, page = screen.page, min_cell_w = Theme.px(96), ratio = 1.72,
            make = function(item, w, h) return BookTile.build(item.path, w, h, { on_tap = function() Actions.details(item.path) end }) end,
            on_layout = function(_cap, pages, page) screen.pages, screen.page = pages, page end })
        body[#body + 1] = Frame.pager(screen, _("SHELF"), function(p) screen:setPage(p) end)
    end
    return Layout.Column:new({ grow = true, gap = th.space.m, children = body })
end

return GoalTab
