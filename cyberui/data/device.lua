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

-- Is the battery charging?
function DeviceInfo.charging()
    local ok, yes = pcall(function() return Device:getPowerDevice():isCharging() end)
    return ok and yes or false
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
