-- Switching gigs and eddies on or off from the settings. On takes effect at
-- once; off goes past three "are you sure" windows, each a little more
-- dramatic, because it stops all earning and lends every look until the
-- switch comes back on.

local App = require("cyberui/app")
local Economy = require("cyberui/data/economy")
local _ = require("cyberui/gettext")

local EconomyFlow = {}

-- The windows, in order: { title, text, ok, cancel }.
local function questions()
    return {
        { _("HOLD UP, CHOOM"), _("Gigs and eddies are a nova feature. You sure you wanna be zeroing the switch?"),
            _("ZERO IT"), _("KEEP IT") },
        { _("FLATLINING THE ECONOMY?"), _("No more payouts, no more eddies. The street quits paying you to read your backlog. Sure, choom?"),
            _("FLATLINE IT"), _("KEEP EARNING") },
        { _("LAST CALL, RUNNER"), _("Your eddies stay in the vault. But if you ever switch this back on, every look you did not buy goes back to default. Zero it for real?"),
            _("ZERO IT FOR REAL"), _("BACK OUT") },
    }
end

-- Ask question `step`; the last yes turns the economy off.
local function ask(step)
    local list = questions()
    local q = list[step]
    App.confirm({ title = q[1], text = q[2], ok = q[3], cancel = q[4], danger = true, icon = "warning",
        on_cancel = App.update,
        on_ok = function()
            if step < #list then return ask(step + 1) end
            Economy.set(false)
            App.toast(_("GIGS OFFLINE // EVERY LOOK UNLOCKED"))
            App.update()
        end })
end

-- The switch was flipped to `on`.
function EconomyFlow.switch(on)
    if not on then return ask(1) end
    Economy.set(true)
    App.toast(_("GIGS ONLINE"))
    App.update()
end

return EconomyFlow
