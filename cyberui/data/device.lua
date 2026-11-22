-- What the status bar shows about the device: the time and date, battery
-- level and whether Wi-Fi is on, plus a short device name.

local Device = require("device")

local DeviceInfo = {}

-- The time now, in the 12 or 24 hour clock KOReader is set to.
function DeviceInfo.clock()
    if G_reader_settings and G_reader_settings:isTrue("twelve_hour_clock") then
        return (os.date("%I:%M"):gsub("^0", ""))
    end
    return os.date("%H:%M")
end

-- Battery percentage, or nil when the device has no battery reading.
function DeviceInfo.battery()
    if not Device:hasBattery() then return nil end
    local ok, pct = pcall(function() return Device:getPowerDevice():getCapacity() end)
    return ok and pct or nil
end

local charging, charging_at   -- the last answer of charging() and when (os.time)
local CHARGING_KEEP = 10        -- seconds an answer is kept (KOReader reads the hardware each time)

-- Is the battery charging?
function DeviceInfo.charging()
    local now = os.time()
    if charging == nil or now - charging_at >= CHARGING_KEEP or now < charging_at then
        local ok, yes = pcall(function() return Device:getPowerDevice():isCharging() end)
        charging, charging_at = ok and yes or false, now
    end
    return charging
end

-- Forget the kept charging state (a charger was plugged in or out).
function DeviceInfo.forgetCharging()
    charging = nil
end

-- Is Wi-Fi switched on?
function DeviceInfo.wifi()
    local ok, NetworkMgr = pcall(require, "ui/network/manager")
    if not ok then return false end
    local ok2, on = pcall(NetworkMgr.isWifiOn, NetworkMgr)
    return ok2 and on or false
end

-- A short name for the device, e.g. "KOBO" or "KINDLE".
function DeviceInfo.name()
    local model = Device.model or "reader"
    return (model:match("^(%a+)") or "reader"):upper()
end

return DeviceInfo
