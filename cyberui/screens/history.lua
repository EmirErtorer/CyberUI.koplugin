-- The reading log ("telemetry"): tabs for the log itself, a week, month or
-- year at a time, streaks and records, a calendar, and the yearly goal. A
-- scope button limits every number to chosen folders. Each tab is a module
-- in screens/log/.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Calendar = require("cyberui/screens/log/calendar")
local Controls = require("cyberui/ui/controls")
local Frame = require("cyberui/screens/frame")
local GoalTab = require("cyberui/screens/log/goal")
local Layout = require("cyberui/ui/layout")
local Metric = require("cyberui/data/metric")
local Period = require("cyberui/screens/log/period")
local Scope = require("cyberui/data/statsscope")
local Settings = require("cyberui/settings")
local ScopeSheet = require("cyberui/screens/log/scope")
local Screen = require("cyberui/screens/screen")
local Stats = require("cyberui/data/stats")
local Streaks = require("cyberui/screens/log/streaks")
local Theme = require("cyberui/theme")
local Week = require("cyberui/screens/log/week")
local _ = require("gettext")

local History = Screen:extend()

-- The tabs: name, id and the module that builds it.
local TABS = {
    { _("Log"), "log", Week }, { _("Stats"), "stats", Period }, { _("Streaks"), "streaks", Streaks },
    { _("Calendar"), "calendar", Calendar }, { _("Goal"), "goal", GoalTab },
}

-- Start on the log, today selected, and every period at the present.
function History:init()
    self.tab = "log"
    self.day = 7
    self.period, self.back = "week", 0
    self.cal_back, self.goal_back = 0, 0
    self.page = 1
end

-- Build the log.
function History:build()
    local th = Theme.get()
    local options, module = {}, nil
    for i, t in ipairs(TABS) do
        options[i] = { t[1], t[2] }
        if t[2] == self.tab then module = t[3] end
    end
    local tabs = Controls.Segmented({ options = options, value = self.tab, kind = "label",
        on_change = function(v) self.tab, self.page = v, 1; App.update() end })
    local scope = Button:new({ icon = "folder", variant = Scope.active() and "icon_on" or "icon", width = th.size.touch,
        on_tap = ScopeSheet.open })
    local actions = { scope }
    if self.tab == "log" or self.tab == "calendar" then
        actions[#actions + 1] = Button:new({ label = Metric.unit(), variant = "secondary", width = th.size.touch, height = th.size.touch,
            on_tap = function() Metric.toggle(); App.update() end })
    end
    if self.tab == "log" or self.tab == "stats" then
        local skyline = Settings.get("chart_view", "bars") == "skyline"
        actions[#actions + 1] = Button:new({ icon = "skyline", variant = skyline and "icon_on" or "icon", width = th.size.touch,
            on_tap = function() Settings.save("chart_view", skyline and "bars" or "skyline"); App.update() end })
    end
    local path = "/VAR/LOG/" .. (Scope.active() and string.format(" // %d FOLDERS", #Scope.folders()) or "")
    return Frame.page({
        screen = self, title = _("Telemetry.log"), path = path, tab = "history", actions = actions,
        body = Layout.Column:new({ gap = th.space.m, children = { tabs, module.build(self) } }),
    })
end

-- Coming back after reading: the numbers changed.
function History:onRaise()
    Stats.invalidate()
end

return History
