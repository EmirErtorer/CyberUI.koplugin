-- Timing of CyberUI's own work (building and painting screens), kept in
-- Perf.last and logged at debug level so speed can be checked at any time.

local logger = require("logger")
local time = require("ui/time")

local Perf = { last = {} }

-- Run fn(...) and remember how long it took under `name` (milliseconds).
function Perf.measure(name, fn, ...)
    local t0 = time.now()
    local a, b = fn(...)
    local ms = time.to_ms(time.since(t0))
    Perf.last[name] = ms
    logger.dbg("CyberUI perf:", name, ms, "ms")
    return a, b
end

return Perf
