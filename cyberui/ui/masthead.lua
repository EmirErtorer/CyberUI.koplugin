-- The masthead at the top of home: one panel holding the banner's lines and,
-- under them, who the operator is (handle and rank), with their face on the left
-- and the barcode of their ID on the right. Without the operator card it is the
-- plain banner with the logo. Holding it changes what the banner says.

local Avatar = require("cyberui/ui/avatar")
local Banner = require("cyberui/data/banner")
local Icon = require("cyberui/ui/icon")
local IdCard = require("cyberui/ui/idcard")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Profile = require("cyberui/data/profile")
local Theme = require("cyberui/theme")

local Masthead = {}

-- The handle and the rank tag on one line.
local function operatorLine(handle, rank)
    local th = Theme.get()
    return Layout.Row:new({ gap = th.space.m, valign = "center", children = {
        Label:new({ text = handle, kind = "mono_small" }),
        IdCard.rankTag(rank, true),
    } })
end

-- Build it. o: { operator (show the face and rank), on_open (tap the face),
-- on_photo (hold the face) }.
function Masthead.build(o)
    local th = Theme.get()
    local top = Banner.top()
    local title, quote = Banner.title()
    local lines = {}
    if top then lines[1] = Label:new({ text = top, kind = "micro", color = "muted" }) end
    lines[#lines + 1] = quote and Label:new({ text = title, kind = "body", lines = 2 }) or Label:new({ text = title, kind = "title" })
    local lead, bars
    if o.operator then
        lines[#lines + 1] = operatorLine(Profile.handle(), Profile.rank(Profile.stats().hours))
        lead = Avatar:new({ seed = Profile.handle(), size = 56, on_tap = o.on_open, on_hold = o.on_photo })
        bars = IdCard.codeBars(32, 84)
    else
        lead = Icon:new({ name = "book", size = 28, color = "accent" })
        bars = IdCard.codeBars(32, 96)
    end
    return Panel:new({ shape = "chamfer", corners = "t", pad = { th.space.s, th.space.m, th.space.s, th.space.s },
        on_tap = o.on_open, on_hold = function() require("cyberui/screens/settings").pickBannerTitle() end,
        child = Layout.Row:new({ gap = th.space.m, valign = "center", children = {
            lead,
            Layout.Column:new({ grow = true, children = lines }),
            bars,
        } }) })
end

return Masthead
