-- What a book pays in eddies, shown the same way wherever it appears: the bar
-- of its ten payouts and the finish (see EarnBar), what it has paid so far
-- out of its price, the next payout and the finish to come, and how its pages
-- are counting. The book's dossier shows it in full, the Gigs page in short.

local EarnBar = require("cyberui/ui/earnbar")
local Format = require("cyberui/format")
local Gigs = require("cyberui/data/gigs")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

local Earnings = {}

-- One line of small facts.
local function line(text, color)
    return Label:new({ text = text, kind = "mono_small", color = color or "muted", lines = 2 })
end

-- The bar for earnings `e`.
function Earnings.bar(e)
    return EarnBar:new({ paid = e.paid, tenths = e.tenths, finish_paid = e.finish_paid })
end

-- What has been paid out of the price, and what comes next: "€$12 OF €$60 PAID // NEXT €$3 AT 40%".
function Earnings.summary(e)
    local text = string.format(_("%s OF %s PAID"), Format.credits(e.earned), Format.credits(e.price))
    if e.next then
        text = text .. " // " .. string.format(_("NEXT %s AT %d%%"), Format.credits(e.next.pay), e.next.k * 10)
    elseif not e.finish_paid then
        text = text .. " // " .. string.format(_("FINISH PAYS %s"), Format.credits(e.finish))
    end
    return text
end

-- How a book's pages are counting: how many counted, how many were turned
-- too quickly, and by which rule.
local function pacing(e)
    local how = (e.mode == "words" and _("A page counts once its words could have been read."))
        or (e.mode == "pace" and _("A page counts after a third of your usual time on a page of this book."))
        or _("A page counts once it could have been read.")
    return line(string.format(_("PAGES COUNTED %d // TOO QUICK %d"), e.counted or 0, e.quick or 0) .. "\n" .. how)
end

-- The full panel for the book at `path`, or nil when eddies are off.
function Earnings.panel(path)
    local th = Theme.get()
    local e = Gigs.earnings(path)
    if e.state == "off" then return nil end
    local kids = {}
    if e.state == "short" then
        kids[1] = line(_("This file is too short to pay eddies."))
    elseif e.state == "started" then
        kids[1] = line(_("This book was started before it could pay, so it pays no eddies."))
    elseif e.state == "offer" then
        local step = Gigs.paidAt(e.price, 10) / 10
        kids[1] = Label:new({ text = string.format(_("PAYS %s"), Format.credits(e.price)), kind = "label" })
        kids[2] = Earnings.bar(e)
        kids[3] = line(string.format(_("%s PER 10%% // %s ON FINISH"), Format.credits(step), Format.credits(e.finish)))
    else
        kids[1] = Label:new({ text = Earnings.summary(e), kind = "label", lines = 2 })
        kids[2] = Earnings.bar(e)
        local rest = e.finish_paid and _("FINISHED: ALL PAID")
            or string.format(_("%s STILL TO EARN // FINISH PAYS %s"), Format.credits(e.left), Format.credits(e.finish))
        kids[3] = line(rest)
        kids[4] = pacing(e)
    end
    local rate = e.gig and _("GIG RATE") or _("PLAIN RATE")
    if e.state == "short" or e.state == "started" then rate = _("NO PAY") end
    return Panel:new({ shape = "brackets", label = "EDDIES // " .. rate, pad = th.space.m, -- i18n: keep
        child = Layout.Column:new({ gap = th.space.xs, children = kids }) })
end

return Earnings
