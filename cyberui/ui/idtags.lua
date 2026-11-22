-- The rank tag and the ID barcode: the parts of the ID card (see idcard.lua)
-- that the home masthead shows too, kept apart so home loads only them.

local Deco = require("cyberui/ui/deco")
local Label = require("cyberui/ui/label")
local Paint = require("cyberui/gfx/paint")
local Panel = require("cyberui/ui/panel")
local Profile = require("cyberui/data/profile")
local Theme = require("cyberui/theme")

local IdTags = {}

-- The rank as a filled tag; `small` for a tag that sits in a line of text.
function IdTags.rankTag(rank, small)
    local th = Theme.get()
    return Panel:new({ shape = "chamfer", corners = "l", cut = "cut_small", fill = "accent", line = false,
        pad = { Theme.px(small and 1 or 3), small and th.space.s or th.space.m },
        child = Label:new({ text = rank.name, kind = small and "micro" or "label", color = "on_accent" }) })
end

-- A barcode that belongs to the ID code, `height` base pixels tall (and
-- `width` wide when given).
function IdTags.codeBars(height, width)
    return Deco.Barcode:new({ bars = Paint.barsFrom(Profile.rng(Profile.id())), height = Theme.px(height),
        width = width and Theme.px(width) or nil })
end

return IdTags
