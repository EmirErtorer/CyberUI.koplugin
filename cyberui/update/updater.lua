-- CyberUI updating itself from its GitHub releases: checking what there is,
-- remembering it (so home and System show it without asking again), and
-- installing a release after checking its download.
--
-- When it checks: when the reader asks (System > About > Updates), and by
-- itself at most once a day when CyberUI opens, only if Wi-Fi is already
-- connected (it never turns Wi-Fi on). A check is one request, run in a
-- background process that ends with it.
--
-- Settings (CyberUI's own): update_auto (on by default), update_pre (off),
-- update_last and update_tried (os.time), update_known ({ current, stable,
-- pre } as versions, from the last check).

local UIManager = require("ui/uimanager")
local Net = require("cyberui/install/net")
local GitHub = require("cyberui/install/github")
local Policy = require("cyberui/update/policy")
local Settings = require("cyberui/settings")
local Unpack = require("cyberui/install/unpack")
local Version = require("cyberui/version")
local _ = require("cyberui/gettext")

local Updater = {
    busy = nil,       -- "checking" or "installing" while one runs
    offers = nil,     -- the last check's offers (Policy.offers)
    error = nil,      -- why the last check or install failed
    installed = nil,  -- the version installed this session, waiting for a restart
}

-- Check by itself once a day? Tell about prereleases?
function Updater.autoOn() return Settings.get("update_auto", true) end
function Updater.preOn() return Settings.get("update_pre", false) end

-- The newer version the last check found (stable, or with prereleases on
-- a newer prerelease), or nil: what home and System show without a check.
function Updater.available()
    if Updater.installed then return nil end
    local k = Settings.get("update_known")
    if type(k) ~= "table" or k.current ~= Version then return nil end
    local best
    if type(k.stable) == "string" and Policy.compare(k.stable, Version) == 1 then best = k.stable end
    if Updater.preOn() and type(k.pre) == "string" and Policy.compare(k.pre, Version) == 1
            and (not best or Policy.compare(k.pre, best) == 1) then best = k.pre end
    return best
end

-- Ask GitHub now; done(offers) or done(nil, why) when it ends.
function Updater.check(done)
    if Updater.busy then return end
    Updater.busy, Updater.error = "checking", nil
    Settings.set("update_tried", os.time())
    GitHub.releases(Policy.SELF, function(list, why)
        Updater.busy = nil
        if not list then
            Updater.error = why
            if done then done(nil, why) end
            return
        end
        local offers = Policy.offers(list, Version)
        Updater.offers = offers
        Settings.set("update_last", os.time())
        Settings.save("update_known", { current = Version, stable = offers.stable and offers.stable.version,
            pre = offers.pre and offers.pre.version })
        if done then done(offers) end
    end)
end

-- Check by itself when a day has passed and Wi-Fi is already connected;
-- done() only when the check found something new.
function Updater.autoCheck(done)
    if not Updater.autoOn() or Updater.busy then return end
    if not Policy.due(os.time(), Settings.get("update_last"), Settings.get("update_tried")) then return end
    local ok, NetworkMgr = pcall(require, "ui/network/manager")
    if not (ok and NetworkMgr:isConnected()) then return end
    UIManager:scheduleIn(5, function()
        Updater.check(function(offers) if offers and Updater.available() and done then done() end end)
    end)
end

-- Download, check and install `release`, then ask to restart KOReader.
-- step(text) shows progress; done(true) or done(nil, why) when it ends.
function Updater.install(release, step, done)
    if Updater.busy then return end
    Updater.busy, Updater.error = "installing", nil
    local function finish(ok, why)
        Updater.busy = nil
        if not ok then Updater.error = why end
        done(ok, why)
    end
    step(string.format(_("DOWNLOADING %s (%.1f MB)"), release.tag, release.size / 1048576))
    Net.get(release.url, release.size, 300, function(zip, err)
        if not zip then return finish(nil, err) end
        step(_("CHECKING AND UNPACKING"))
        UIManager:nextTick(function()
            local Addons = require("cyberui/apps/addons")
            local ok, res, uerr = pcall(Unpack.replace, zip, release, Policy.SELF.folder, Addons.pluginsDir(), Updater.folder())
            os.remove(zip)
            if not (ok and res) then return finish(nil, tostring(ok and uerr or res)) end
            Updater.installed = release.version
            finish(true)
            UIManager:askForRestart(string.format(_("CyberUI %s is installed. Restart KOReader to use it."), release.version))
        end)
    end)
end

-- The folder CyberUI runs from on this device (normally CyberUI.koplugin).
function Updater.folder()
    return require("cyberui/paths").root:match("([^/]+)/?$")
end

-- At start: the copy an update replaced is no longer needed.
function Updater.cleanup()
    local Addons = require("cyberui/apps/addons")
    pcall(Unpack.removeTree, Unpack.previous(Addons.pluginsDir(), Updater.folder()))
end

return Updater
