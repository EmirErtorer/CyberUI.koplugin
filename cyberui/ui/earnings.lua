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

-- Which rule judges a book's pages, as a short tag and as the sentence that explains it.
local function rule(e)
    if e.mode == "words" then return _("BY WORDS"), _("A page counts once its words could have been read.") end
    if e.mode == "pace" then return _("BY YOUR PACE"), _("A page counts after a third of your usual time on a page of this book.") end
    return _("MEASURING"), _("A page counts once it could have been read.")
end

-- A tap on the eddies tells the whole story of how the book's pages count.
local function explain(e)
    local App = require("cyberui/app")
    local _tag, how = rule(e)
    App.confirm({ icon = "gigs", title = _("How pages count"), ok = _("OK"), cancel = false,
        text = how .. "\n\n" .. string.format(_("PAGES COUNTED %d // TOO QUICK %d"), e.counted or 0, e.quick or 0) })
end

-- The eddies of the book at `path`, compact enough to leave the synopsis its
-- room: what it has paid and what comes next with its rate beside it, the bar,
-- and one line with what is still to come and how its pages are counting
-- (the rule is named by the rate, and a tap explains it). Nil when eddies are off.
function Earnings.panel(path)
    local th = Theme.get()
    local e = Gigs.earnings(path)
    if e.state == "off" then return nil end
    local rate = e.gig and _("GIG RATE") or _("PLAIN RATE")
    if e.state == "short" or e.state == "started" then rate = _("NO PAY") end
    -- (a book that pays also says by which rule its pages count)
    if e.state == "paying" then rate = rate .. " // " .. rule(e) end
    local function head(text)
        return Layout.Row:new({ gap = th.space.s, valign = "center", children = {
            Label:new({ text = text, kind = "label", lines = 2, grow = true }),
            Label:new({ text = "EDDIES // " .. rate, kind = "micro", color = e.gig and "accent" or "muted" }), -- i18n: keep
        } })
    end
    local kids
    if e.state == "short" then
        kids = { head(_("NO PAY")), line(_("This file is too short to pay eddies.")) }
    elseif e.state == "started" then
        kids = { head(_("NO PAY")), line(_("This book was started before it could pay, so it pays no eddies.")) }
    elseif e.state == "offer" then
        local step = Gigs.paidAt(e.price, 10) / 10
        kids = { head(string.format(_("PAYS %s"), Format.credits(e.price))), Earnings.bar(e),
            line(string.format(_("%s PER 10%% // %s ON FINISH"), Format.credits(step), Format.credits(e.finish))) }
    else
        local rest = e.finish_paid and _("FINISHED: ALL PAID")
            or string.format(_("%s STILL TO EARN // FINISH PAYS %s"), Format.credits(e.left), Format.credits(e.finish))
        local counting = string.format(_("PAGES COUNTED %d // TOO QUICK %d"), e.counted or 0, e.quick or 0)
        kids = { head(Earnings.summary(e)), Earnings.bar(e), line(rest .. " // " .. counting) }
    end
    return Panel:new({ shape = "none", on_tap = e.state == "paying" and function() explain(e) end or nil,
        child = Layout.Column:new({ gap = th.space.xs, children = kids }) })
end

return Earnings
