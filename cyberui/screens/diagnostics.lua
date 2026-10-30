-- System diagnostics, opened from the scope button on home: power cell,
-- core (processor and memory), storage, uplink, optics (screen and light),
-- uptime and identity, as a deck readout. Readings the device does not offer
-- are left out. A snapshot taken when the screen opens: it never redraws by
-- itself (no e-ink refreshes for jumpy values); RESCAN takes a new one.

local App = require("cyberui/app")
local Banner = require("cyberui/data/banner")
local Button = require("cyberui/ui/button")
local Format = require("cyberui/format")
local Frame = require("cyberui/screens/frame")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Library = require("cyberui/data/library")
local Mainboard = require("cyberui/ui/mainboard")
local Panel = require("cyberui/ui/panel")
local Progress = require("cyberui/ui/progress")
local Screen = require("cyberui/screens/screen")
local Sysinfo = require("cyberui/data/sysinfo")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

local Diagnostics = Screen:extend()

-- A label and its value on one line; nil when there is no value.
local function kv(k, v)
    if v == nil or v == "" then return nil end
    return Layout.Row:new({ gap = Theme.get().space.s, children = {
        Label:new({ text = k, kind = "mono_small", color = "muted", width = Theme.px(76) }),
        Label:new({ text = tostring(v), kind = "mono_small", grow = true }),
    } })
end

-- A segmented gauge from 0 to 1.
local function gauge(value, segments)
    return Progress:new({ value = value, segments = segments or 24, cell_h = 10 })
end

-- A titled panel around the rows given, skipping missing ones.
local function panel(title, right, rows)
    local kids = {}
    for i = 1, table.maxn(rows) do
        if rows[i] then kids[#kids + 1] = rows[i] end
    end
    if #kids == 0 then kids[1] = Label:new({ text = _("NOT REPORTED BY THIS DEVICE"), kind = "mono_small", color = "muted" }) end
    local th = Theme.get()
    return Panel:new({ shape = "header", title = title, title_right = right, pad = th.space.s,
        child = Layout.Column:new({ gap = Theme.px(3), children = kids }) })
end

-- Hours and minutes: "14H 22M".
local function hm(s)
    if not s then return nil end
    s = math.floor(s)
    return string.format("%dH %02dM", math.floor(s / 3600), math.floor(s % 3600 / 60))
end

-- Mebibytes as "312 MB".
local function mb(v)
    return v and string.format("%d MB", math.floor(v + 0.5)) or nil
end

-- The power cell: gauge, state, drain and cycles.
local function powerPanel()
    local p = Sysinfo.power()
    if not p or not p.pct then return panel(_("POWER CELL"), nil, {}) end
    local state = p.charging and _("CHARGING") or p.charged and _("FULL") or _("DISCHARGING")
    return panel(_("POWER CELL"), string.format("%d%%", p.pct), {
        gauge(p.pct / 100, 30),
        kv(_("STATE"), state),
        kv(_("DRAIN"), p.drain and string.format(_("%.1f%%/H // ~%dH LEFT"), p.drain, math.floor(p.left_h + 0.5))),
        kv(_("CHARGED"), p.last_charge and Format.ago(p.last_charge)),
        kv(_("CYCLES"), p.cycles),
        kv(_("AUX CELL"), p.aux and string.format("%d%%", p.aux)),
    })
end

-- Processor and memory.
local function corePanel()
    local c = Sysinfo.core()
    return panel(_("CORE"), c.load and string.format("%d%%", math.floor(c.load * 100 + 0.5)), {
        c.load and gauge(c.load, 16),
        kv(_("CLOCK"), c.mhz and string.format("%d MHz", c.mhz)),
        kv(_("CORES"), c.cores and string.format("%d× %s", c.cores, c.model or "CPU")),
        kv(_("LOAD"), c.loadavg),
        kv(_("MEM"), c.mem_total and string.format("%s / %s", mb(c.mem_used), mb(c.mem_total))),
        c.mem_total and gauge(c.mem_used / c.mem_total, 16),
        kv(_("PROC"), c.rss and string.format(_("%s // %d THR"), mb(c.rss), c.threads or 0)),
    })
end

-- Storage drives and the library's size.
local function storagePanel()
    local rows = {}
    for _i, d in ipairs(Sysinfo.storage(Library.home())) do
        rows[#rows + 1] = kv(d.name, string.format("%s / %s", Format.size(d.used), Format.size(d.total)))
        rows[#rows + 1] = gauge(d.used / d.total, 16)
    end
    local all = Library.all()
    rows[#rows + 1] = kv(_("ARCHIVE"), string.format(_.n("%d FILE // %s", "%d FILES // %s", #all), #all, Format.size(Sysinfo.archiveSize(all))))
    return panel(_("STORAGE"), nil, rows)
end

-- Network and services.
local function uplinkPanel()
    local u = Sysinfo.uplink()
    if not u then return panel(_("UPLINK"), nil, {}) end
    local state = u.connected and _("ACTIVE") or u.on and _("SEARCHING") or _("NO CARRIER")
    return panel(_("UPLINK"), state, {
        kv(_("NODE"), u.ssid),
        kv(_("ADDR"), u.ip),
        kv(_("WI-FI"), u.on and _("ON") or _("OFF")),
        kv(_("SSH"), u.ssh and string.format(_("OPEN :%s"), u.ssh) or _("CLOSED")),
    })
end

-- Screen, light and input.
local function opticsPanel()
    local o = Sysinfo.optics()
    local input = { o.touch and _("TOUCH") or nil, o.pen and _("PEN") or nil, o.keys and _("KEYS") or nil, o.keyboard and _("KEYBOARD") or nil }
    local list = {}
    for i = 1, 4 do if input[i] then list[#list + 1] = input[i] end end
    return panel(_("OPTICS"), nil, {
        kv(_("PANEL"), string.format("%d×%d%s", o.w, o.h, o.dpi and (" @" .. o.dpi) or "")),
        kv(_("DEPTH"), o.color and _("COLOUR") or _("MONO")),
        kv(_("LUMEN"), o.light and string.format("%d/%d", o.light, o.light_max or 0)),
        kv(_("TINT"), o.warmth and string.format("%d%%", o.warmth)),
        kv(_("MODE"), (o.portrait and _("PORTRAIT") or _("LANDSCAPE")) .. " // " .. (o.night and _("INVERT ON") or _("INVERT OFF"))),
        kv(_("INPUT"), #list > 0 and table.concat(list, " + ") or nil),
    })
end

-- How long the device and KOReader have been up, and how much of KOReader's
-- time awake.
local function uptimePanel()
    local up = Sysinfo.uptime()
    local awake = up.total and up.asleep and up.total - up.asleep
    return panel(_("UPTIME"), hm(up.device or up.total), {
        kv(_("DEVICE"), up.device and hm(up.device)),
        kv(_("KOREADER"), up.total and hm(up.total)),
        awake and up.total > 0 and gauge(awake / up.total, 30),
        kv(_("AWAKE"), awake and string.format("%s // %s %s", hm(awake), _("SLEEP"), hm(up.asleep))),
        kv(_("WAKES"), up.wakes and up.wakes > 0 and up.wakes or nil),
        kv(_("SLEPT AT"), up.last_sleep and os.date("%H:%M", up.last_sleep)),
    })
end

-- The identity lines at the bottom.
local function identLines()
    local id = Sysinfo.ident()
    local family = Banner.device()
    local model = id.model and id.model:upper() ~= family and (" " .. id.model:upper()) or ""
    local first = { family .. model, id.version and ("KOREADER " .. id.version),
        id.kernel and ("KERNEL " .. id.kernel) }
    local second = { id.modules and string.format(_("MODULES %d/%d"), id.modules_on, id.modules), string.format(_("DICTS %d"), id.dicts),
        id.fonts and string.format(_("FONTS %d"), id.fonts), id.locale and ("LOCALE " .. id.locale:upper()), "UTC" .. id.tz }
    local function join(t)
        local out = {}
        for i = 1, table.maxn(t) do if t[i] then out[#out + 1] = t[i] end end
        return table.concat(out, " // ")
    end
    return Layout.Column:new({ children = {
        Label:new({ text = join(first), kind = "micro", color = "muted" }),
        Label:new({ text = join(second), kind = "micro", color = "muted" }),
    } })
end

-- Build the readout: power across the top, two columns, uptime and identity.
function Diagnostics:build()
    local th = Theme.get()
    local body = Layout.Column:new({ gap = th.space.m, clip = true, children = {
        powerPanel(),
        Layout.Row:new({ gap = th.space.m, valign = "top", children = {
            Layout.Column:new({ grow = true, gap = th.space.m, children = { corePanel(), storagePanel() } }),
            Layout.Column:new({ grow = true, gap = th.space.m, children = { uplinkPanel(), opticsPanel() } }),
        } }),
        uptimePanel(),
        identLines(),
        Mainboard:new({ grow = true }),   -- the empty space under the readouts: the board inside
    } })
    return Frame.page({ screen = self, title = _("Diagnostics"), path = "ROOT@" .. Banner.device() .. " // SYS.MONITOR", -- i18n: keep
        tab = "home", body = body,
        actions = { Button:new({ label = _("RESCAN"), on_tap = function() App.update() end }) } })
end

return Diagnostics
