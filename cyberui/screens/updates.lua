-- Updates: the installed version, the newest release (and, with prereleases
-- on, a newer prerelease) with a button to install or go back, its release
-- notes, and whether to check by itself and tell about prereleases.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Controls = require("cyberui/ui/controls")
local Deco = require("cyberui/ui/deco")
local Dialog = require("cyberui/ui/dialog")
local Frame = require("cyberui/screens/frame")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Policy = require("cyberui/update/policy")
local Screen = require("cyberui/screens/screen")
local ScrollText = require("cyberui/ui/scrolltext")
local Settings = require("cyberui/settings")
local Theme = require("cyberui/theme")
local Updater = require("cyberui/update/updater")
local Version = require("cyberui/version")
local _ = require("cyberui/gettext")

local Updates = Screen:extend()

-- Check as the screen opens (the reader came here to know).
function Updates:init()
    self.notes_page = {}
    if not Updater.offers and not Updater.busy then self:check() end
end

-- Ask GitHub, turning Wi-Fi on first if KOReader needs to.
function Updates:check()
    local run = function() Updater.check(function() App.update() end) end
    local ok, NetworkMgr = pcall(require, "ui/network/manager")
    if ok and NetworkMgr.runWhenOnline then NetworkMgr:runWhenOnline(run) else run() end
end

-- Install `rel` with a progress panel.
local function install(rel)
    local title = string.format(_("Installing CyberUI %s"), rel.version)
    Updater.install(rel, function(text)
        App.dialog(function(_close, w) return Dialog.progress({ title = title, text = text }, w) end)
    end, function(ok, why)
        App.closeDialog()
        if not ok then
            App.confirm({ title = _("CyberUI was not updated"), text = why, ok = _("OK") })
        end
        App.update()
    end)
end

-- A release as a card: version, channel, date, and its button.
local function card(rel, label, action)
    local th = Theme.get()
    local kids = {
        Layout.Column:new({ grow = true, children = {
            Label:new({ text = "v" .. rel.version, kind = "title" }),
            Label:new({ text = (rel.pre and _("PRERELEASE") or _("STABLE")) .. (rel.date and (" // " .. rel.date) or ""),
                kind = "mono_small", color = "muted" }),
        } }),
    }
    if action then
        kids[#kids + 1] = Button:new({ label = label, variant = "primary", on_tap = function() action(rel) end })
    else
        kids[#kids + 1] = Label:new({ text = label, kind = "label", color = "muted" })
    end
    return Panel:new({ shape = "chamfer", corners = "r", line = "ink", pad = { th.space.s, th.space.m },
        child = Layout.Row:new({ gap = th.space.m, children = kids }) })
end

-- Build: status, release cards, notes, the two switches.
function Updates:build()
    local th = Theme.get()
    local o = Updater.offers
    local status
    if Updater.busy == "checking" then status = _("ASKING GITHUB...")
    elseif Updater.installed then status = string.format(_("v%s INSTALLED // RESTART KOREADER"), Updater.installed)
    elseif Updater.error then status = string.format(_("CHECK FAILED // %s"), Updater.error)
    elseif o then status = (o.stable_action == "update" or o.pre_action == "try") and _("UPDATE AVAILABLE") or _("UP TO DATE")
    else status = _("NOT CHECKED YET") end
    local body = {
        Layout.Row:new({ gap = th.space.m, children = {
            Layout.Column:new({ grow = true, children = {
                Label:new({ text = "CYBERUI v" .. Version, kind = "title" }), -- i18n: keep
                Label:new({ text = status, kind = "mono_small", color = "muted", lines = 2 }),
            } }),
            Button:new({ label = _("Check"), on_tap = function() self:check(); App.update() end }),
        } }),
    }
    local shown
    if o and o.stable then
        local label = ({ update = _("Install"), back = _("Back to stable"), current = _("Installed") })[o.stable_action]
        body[#body + 1] = card(o.stable, label, o.stable_action ~= "current" and not Updater.installed and install or nil)
        shown = o.stable
    end
    if o and o.pre and Updater.preOn() then
        local label = o.pre_action == "try" and _("Try prerelease") or _("Installed")
        body[#body + 1] = card(o.pre, label, o.pre_action == "try" and not Updater.installed and install or nil)
        if o.pre_action == "try" then shown = o.pre end
    end
    if shown and shown.notes ~= "" then
        body[#body + 1] = Panel:new({ shape = "brackets", label = string.format(_("NOTES // v%s"), shown.version),
            pad = th.space.l, grow = true, child = ScrollText:new({ text = Policy.notes(shown.notes), kind = "small",
                state = self.notes_page, on_turn = function() App.update() end }) })
    else
        body[#body + 1] = Layout.Spacer:new({ grow = true })
    end
    body[#body + 1] = Deco.Divider:new({})
    body[#body + 1] = Layout.Row:new({ gap = th.space.m, children = {
        Label:new({ text = _("Check once a day (on Wi-Fi that is already on)"), kind = "small", grow = true, lines = 2 }),
        Controls.Toggle:new({ on = Updater.autoOn(), on_change = function(on) Settings.save("update_auto", on); App.update() end }),
    } })
    body[#body + 1] = Layout.Row:new({ gap = th.space.m, children = {
        Label:new({ text = _("Tell me about prereleases (test builds, newer but less tried)"), kind = "small", grow = true, lines = 2 }),
        Controls.Toggle:new({ on = Updater.preOn(), on_change = function(on) Settings.save("update_pre", on); App.update() end }),
    } })
    return Frame.page({ screen = self, title = _("Updates"), path = string.format(_("GITHUB // %s"), Policy.SELF.repo:upper()), tab = "settings",
        body = Layout.Column:new({ gap = th.space.m, children = body }) })
end

return Updates
