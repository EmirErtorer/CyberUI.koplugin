-- The status line across the top of every screen: the tag on the left (the
-- reader's own text), a ruler, then the readouts the reader chose, in their
-- order (System > Home > Top bar). Once a minute only the `live` readouts
-- (clock, date, battery, Wi-Fi) are read again, and the bar is redrawn only
-- when one of them changed; the rest are read when a screen is drawn, so
-- jumpy values like processor load never cause e-ink refreshes by themselves.

local DeviceInfo = require("cyberui/data/device")
local Deco = require("cyberui/ui/deco")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Settings = require("cyberui/settings")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local StatusBar = {}

StatusBar.TAG = "CYBR//DECK"
StatusBar.DEFAULT = { "clock", "battery", "cpu", "mem" }
StatusBar.MAX = 6

-- Percent text for a fraction, or nil.
local function pct(prefix, f)
    return f and string.format("%s %d%%", prefix, math.floor(f * 100 + 0.5)) or nil
end

-- Every readout the bar can show: its name in the editor and how to read it
-- now (nil hides it). `muted` ones are drawn in the quiet colour.
StatusBar.ITEMS = {
    { id = "clock", name = _("Clock"), live = true, read = function() return DeviceInfo.clock() end },
    { id = "date", name = _("Date"), live = true, read = function() return os.date("%d.%m") end },
    { id = "wifi", name = _("Wi-Fi"), muted = true, live = true, read = function() return DeviceInfo.wifi() and _("WIFI") or nil end },
    { id = "battery", name = _("Battery"), live = true, read = function()
        local p = DeviceInfo.battery()
        return p and ((DeviceInfo.charging() and "BAT+ " or "BAT ") .. p .. "%")
    end },
    { id = "light", name = _("Frontlight"), read = function()
        local Device = require("device")
        if not Device:hasFrontlight() then return nil end
        local ok, v = pcall(function() return Device:getPowerDevice():frontlightIntensity() end)
        return ok and v and ("LUM " .. v) or nil
    end },
    { id = "cpu", name = _("Processor load"), read = function() return pct("CPU", require("cyberui/data/sysinfo").cpuLoad()) end },
    { id = "mem", name = _("Memory"), read = function()
        local used, total = require("cyberui/data/sysinfo").memory()
        return used and pct("MEM", used / total)
    end },
    { id = "disk", name = _("Storage"), read = function()
        local drives = require("cyberui/data/sysinfo").storage()
        local d = drives[1]
        return d and pct("DSK", d.used / d.total)
    end },
    { id = "book", name = _("Book progress"), read = function()
        local History = require("cyberui/data/history")
        local cur = History.current()
        return cur and pct("FILE", require("cyberui/data/books").state(cur.path).percent)
    end },
    { id = "uptime", name = _("Uptime"), read = function()
        local up = require("cyberui/data/sysinfo").uptime().total
        return up and string.format("UP %dH%02d", math.floor(up / 3600), math.floor(up % 3600 / 60))
    end },
}

local by_id = {}
for _i, it in ipairs(StatusBar.ITEMS) do by_id[it.id] = it end

-- The item with this id, or nil.
function StatusBar.item(id)
    return by_id[id]
end

-- The ids shown, in order.
function StatusBar.shown()
    return Settings.get("topbar", StatusBar.DEFAULT)
end

-- The tag text on the left.
function StatusBar.tag()
    local t = Settings.get("topbar_tag")
    return (t and t ~= "") and t or StatusBar.TAG
end

-- Fill the readout labels with what each item reads now (only the live
-- ones when `live_only`). True when any text changed.
local function fill(labels, live_only)
    local changed = false
    for _i, l in ipairs(labels) do
        if l.item.live or not live_only then
            local text = l.item.read() or ""
            if text ~= l.text then l.text, changed = text, true end
        end
    end
    return changed
end

-- Build the bar. Returns the row twice: the second is what the app ticks.
function StatusBar.build()
    local th = Theme.get()
    local kids = {
        Label:new({ text = StatusBar.tag(), kind = "mono_small", color = "ink" }),
        Deco.Ruler:new({ grow = true, height = Theme.px(7) }),
    }
    local labels = {}
    for _i, id in ipairs(StatusBar.shown()) do
        local it = by_id[id]
        if it then
            local l = Label:new({ item = it, kind = "mono_small", color = it.muted and "muted" or "ink" })
            labels[#labels + 1] = l
            kids[#kids + 1] = l
        end
    end
    fill(labels)
    local row = Layout.Row:new({ gap = th.space.m, height = th.size.status, children = kids, labels = labels })
    return row, row
end

-- Read the live items again; when one changed, lay the bar out anew and
-- return true so the caller repaints it.
function StatusBar.tick(row)
    if not fill(row.labels, true) then return false end
    row:layout(row.w, row.h)
    return true
end

return StatusBar
