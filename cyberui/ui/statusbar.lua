-- The status line across the top of every screen: the brand mark, a ruler,
-- then the clock, Wi-Fi and battery. The clock can be refreshed on its own.

local DeviceInfo = require("cyberui/data/device")
local Deco = require("cyberui/ui/deco")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local StatusBar = {}

-- Battery as "BAT 64%" (with a + while charging), or nil.
local function battery()
    local pct = DeviceInfo.battery()
    if not pct then return nil end
    return (DeviceInfo.charging() and "BAT+ " or "BAT ") .. pct .. "%"
end

-- Build the bar; `brand` is the text on the left. Returns the row and its clock label.
function StatusBar.build(brand)
    local th = Theme.get()
    local clock = Label:new({ text = DeviceInfo.clock(), kind = "mono_small" })
    local kids = {
        Label:new({ text = brand or "CYBR//DECK", kind = "mono_small", color = "ink" }),
        Deco.Ruler:new({ grow = true, height = Theme.px(7) }),
        clock,
    }
    if DeviceInfo.wifi() then kids[#kids + 1] = Label:new({ text = _("WIFI"), kind = "mono_small", color = "muted" }) end
    local bat = battery()
    if bat then kids[#kids + 1] = Label:new({ text = bat, kind = "mono_small" }) end
    local row = Layout.Row:new({ gap = th.space.m, height = th.size.status, children = kids })
    return row, clock
end

-- Put the current time into a clock label (the caller repaints it).
function StatusBar.tick(clock)
    clock.text = DeviceInfo.clock()
    clock:layout(clock.w, clock.h)
end

return StatusBar
