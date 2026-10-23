-- What the diagnostics screen reads about the device: power, processor and
-- memory, storage, network, screen and light, uptime and identity. Each
-- reading is nil when the device does not offer it, so the screen hides it.
-- Linux system files (/proc, /sys) exist on Kindle, Kobo and the like.

local Device = require("device")
local DataStorage = require("datastorage")
local Settings = require("cyberui/settings")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")

local Sysinfo = {}

-- The first line of a file, or nil.
local function readLine(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*l")
    f:close()
    return s
end

-- A whole small file, or nil.
local function readAll(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- fn() or nil if it fails.
local function try(fn, ...)
    local ok, v = pcall(fn, ...)
    if ok then return v end
    return nil
end

-- A running plugin's instance by its name, or nil.
local function plugin(name)
    local fm = require("apps/filemanager/filemanager").instance
    return fm and fm[name]
end

---------------------------------------------------------------- power

-- Battery state, and a drain rate worked out from what was seen since the
-- last charge (kept between runs in CyberUI's settings).
function Sysinfo.power()
    local pd = try(function() return Device:getPowerDevice() end)
    if not (pd and Device:hasBattery()) then return nil end
    local now = os.time()
    local p = {
        pct = try(pd.getCapacity, pd),
        charging = try(pd.isCharging, pd) or false,
        charged = try(pd.isCharged, pd) or false,
    }
    if Device:hasAuxBattery() and try(pd.isAuxBatteryConnected, pd) then p.aux = try(pd.getAuxCapacity, pd) end
    local log = Settings.get("cell_log", {})
    if p.charging then
        log = { last_charge = now }
    elseif p.pct then
        if not log.base_t or p.pct > (log.base_pct or 0) then log.base_t, log.base_pct = now, p.pct end
        local hours = (now - log.base_t) / 3600
        if hours >= 0.5 and log.base_pct > p.pct then
            p.drain = (log.base_pct - p.pct) / hours
            p.left_h = p.pct / p.drain
        end
    end
    Settings.set("cell_log", log)
    p.last_charge = log.last_charge
    local stat = plugin("systemstat")
    if stat then p.cycles = stat.charge_count end
    return p
end

---------------------------------------------------------------- core

local last_cpu   -- { busy, total } from the previous reading

-- Processor load (0 to 1) since the last reading, or since boot; nil
-- without /proc/stat.
function Sysinfo.cpuLoad()
    local line = readLine("/proc/stat")
    if not line then return nil end
    local n = {}
    for v in line:gmatch("%d+") do n[#n + 1] = tonumber(v) end
    local total, idle = 0, (n[4] or 0) + (n[5] or 0)
    for _i, v in ipairs(n) do total = total + v end
    local busy = total - idle
    local d_total = last_cpu and total - last_cpu.total or total
    local d_busy = last_cpu and busy - last_cpu.busy or busy
    last_cpu = { busy = busy, total = total }
    if d_total > 0 then return d_busy / d_total end
    return nil
end

-- Memory used and total in MB, or nil.
function Sysinfo.memory()
    local mem = readAll("/proc/meminfo")
    if not mem then return nil end
    local total = tonumber(mem:match("MemTotal:%s*(%d+)"))
    local avail = tonumber(mem:match("MemAvailable:%s*(%d+)") or mem:match("MemFree:%s*(%d+)"))
    if not (total and avail) then return nil end
    return (total - avail) / 1024, total / 1024
end

-- Processor load, clock, cores, model and load average, plus memory and
-- KOReader's own share.
function Sysinfo.core()
    local c = { load = Sysinfo.cpuLoad() }
    local khz = tonumber(readLine("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq") or "")
    if khz then c.mhz = math.floor(khz / 1000 + 0.5) end
    local info = readAll("/proc/cpuinfo")
    if info then
        local cores = 0
        for _l in info:gmatch("\nprocessor%s*:") do cores = cores + 1 end
        if info:match("^processor%s*:") then cores = cores + 1 end
        c.cores = cores > 0 and cores or nil
        c.model = info:match("Hardware%s*:%s*([^\n]+)") or info:match("model name%s*:%s*([^\n]+)")
            or info:match("Processor%s*:%s*([^\n]+)")
    end
    local la = readLine("/proc/loadavg")
    if la then c.loadavg = la:match("^(%S+ %S+ %S+)") end
    c.mem_used, c.mem_total = Sysinfo.memory()
    local me = readAll("/proc/self/status")
    if me then
        local rss = tonumber(me:match("VmRSS:%s*(%d+)"))
        c.rss = rss and rss / 1024
        c.threads = tonumber(me:match("Threads:%s*(%d+)"))
    end
    return c
end

---------------------------------------------------------------- storage

-- Each storage the library and KOReader live on: { name, used, total } in
-- bytes, once per drive.
function Sysinfo.storage(library_dir)
    local out, seen = {}, {}
    local function add(name, path)
        if not path then return end
        local u = try(util.diskUsage, path)
        if u and u.total and u.total > 0 and not seen[u.total .. "|" .. (u.available or 0)] then
            seen[u.total .. "|" .. (u.available or 0)] = true
            out[#out + 1] = { name = name, total = u.total, used = u.total - (u.available or 0) }
        end
    end
    add("INTERNAL", DataStorage:getDataDir())
    add("LIBRARY", library_dir)
    if Device:hasExternalSD() then add("SD", "/mnt/sd") end
    return out
end

-- Total size of the files in `paths`, in bytes.
function Sysinfo.archiveSize(paths)
    local sum = 0
    for _i, p in ipairs(paths) do sum = sum + (lfs.attributes(p, "size") or 0) end
    return sum
end

---------------------------------------------------------------- uplink

-- Wi-Fi state, network name and address, and whether SSH is running.
function Sysinfo.uplink()
    local ok, NetworkMgr = pcall(require, "ui/network/manager")
    if not ok then return nil end
    local u = { on = try(NetworkMgr.isWifiOn, NetworkMgr) or false, connected = try(NetworkMgr.isConnected, NetworkMgr) or false }
    if u.connected then
        local nw = try(NetworkMgr.getCurrentNetwork, NetworkMgr)
        u.ssid = nw and nw.ssid
        local iface = try(NetworkMgr.getNetworkInterfaceName, NetworkMgr) or "wlan0"
        local f = io.popen("ip -4 -o addr show " .. iface .. " 2>/dev/null || ifconfig " .. iface .. " 2>/dev/null")
        if f then
            local out = f:read("*a") or ""
            f:close()
            u.ip = out:match("inet (%d+%.%d+%.%d+%.%d+)") or out:match("inet addr:(%d+%.%d+%.%d+%.%d+)")
        end
    end
    local ssh = plugin("SSH")
    u.ssh = ssh and try(ssh.isRunning, ssh) and (ssh.SSH_port or 2222) or nil
    return u
end

---------------------------------------------------------------- optics

-- Screen, frontlight, orientation, night mode and ways of input.
function Sysinfo.optics()
    local Screen = Device.screen
    local o = {
        w = Screen:getWidth(), h = Screen:getHeight(),
        dpi = try(Device.getDeviceScreenDPI, Device) or try(Screen.getDPI, Screen),
        color = Device:hasColorScreen(),
        portrait = Screen:getWidth() <= Screen:getHeight(),
        night = G_reader_settings and G_reader_settings:isTrue("night_mode") or false,
        touch = Device:isTouchDevice(), keys = Device:hasKeys(), keyboard = Device:hasKeyboard(),
    }
    o.pen = (Device.hasStylus and try(Device.hasStylus, Device)) or false
    if Device:hasFrontlight() then
        local pd = Device:getPowerDevice()
        o.light = try(pd.frontlightIntensity, pd)
        o.light_max = pd.fl_max
        if Device:hasNaturalLight() then o.warmth = try(pd.frontlightWarmth, pd) end
    end
    return o
end

---------------------------------------------------------------- uptime

-- How long the device and KOReader have been up, how much of KOReader's
-- time was spent asleep, and the sleep counts (those need KOReader's System
-- statistics plugin).
function Sysinfo.uptime()
    local time = require("ui/time")
    local stat = plugin("systemstat")
    local up = { device = tonumber((readLine("/proc/uptime") or ""):match("^(%S+)")) }
    if stat and stat.start_monotonic_time then
        up.total = time.to_s(time.boottime_or_realtime_coarse() - stat.start_monotonic_time)
        up.wakes = stat.wakeup_count
        up.last_sleep = stat.suspend_time and time.to_s(stat.suspend_time)
    elseif Sysinfo.started then
        up.total = os.time() - Sysinfo.started
    end
    if up.total then
        local asleep = 0
        if Device:canSuspend() then asleep = asleep + time.to_s(Device.total_suspend_time or 0) end
        if Device:canStandby() then asleep = asleep + time.to_s(Device.total_standby_time or 0) end
        up.asleep = math.min(asleep, up.total)
    end
    return up
end

---------------------------------------------------------------- ident

-- KOReader version, kernel, and how many plugins, dictionaries and fonts.
function Sysinfo.ident()
    local id = {}
    id.version = try(function() return require("version"):getShortVersion() end)
    id.kernel = readLine("/proc/sys/kernel/osrelease")
    id.model = Device.model
    local disabled = G_reader_settings and G_reader_settings:readSetting("plugins_disabled") or {}
    local total, off = 0, 0
    pcall(function()
        for name in lfs.dir(require("cyberui/apps/addons").pluginsDir()) do
            local plug = name:match("^(.+)%.koplugin$")
            if plug then
                total = total + 1
                if disabled[plug] then off = off + 1 end
            end
        end
    end)
    if total > 0 then id.modules, id.modules_on = total, total - off end
    local dicts = 0
    local dict_dir = DataStorage:getDataDir() .. "/data/dict"
    if lfs.attributes(dict_dir, "mode") == "directory" then
        for f in lfs.dir(dict_dir) do
            if f ~= "." and f ~= ".." and lfs.attributes(dict_dir .. "/" .. f, "mode") == "directory" then dicts = dicts + 1 end
        end
    end
    id.dicts = dicts
    id.fonts = try(function() return #require("fontlist"):getFontList() end)
    id.locale = G_reader_settings and G_reader_settings:readSetting("language")
    id.tz = os.date("%z")
    return id
end

return Sysinfo
