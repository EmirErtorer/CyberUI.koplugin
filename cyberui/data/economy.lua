-- The master switch for gigs and eddies. On (the default) books pay eddies
-- and the shop sells looks for them. Off, nothing is earned or spent and the
-- shop lends every look; turning it back on gives back only the looks that
-- were paid for, and a borrowed one in use is put back to the free style. The
-- ledger is never touched, so the balance is still there afterwards.

local Settings = require("cyberui/settings")

local Economy = {}

-- Is the economy on?
function Economy.on()
    return Settings.get("gigs_on", true) ~= false
end

-- Switch it on or off. Coming back on, looks that were only borrowed are
-- returned before anything is drawn.
function Economy.set(on)
    Settings.save("gigs_on", on and true or false)
    require("cyberui/data/gigs").reload()
    if on then require("cyberui/data/shop").revert() end
end

return Economy
