-- Achievements worked out from the numbers (nothing is stored): hours read,
-- the longest daily streak and books finished, each a ladder of levels.

local Insights = require("cyberui/data/insights")

local Achievements = {}

-- Each ladder: its name, the levels with their short labels, and where its
-- number comes from.
local LADDERS = {
    { name = "CLEARANCE", levels = Insights.MILESTONES, of = function(n) return n.hours end,
        short = function(v) return v >= 1000 and (v / 1000) .. "K" or tostring(v) end, unit = "H" },
    { name = "UPTIME", levels = { 3, 7, 14, 30, 100, 365 }, of = function(n) return n.streak end,
        short = tostring, unit = "D" },
    { name = "ARCHIVE", levels = { 1, 5, 10, 25, 50, 100 }, of = function(n) return n.finished end,
        short = tostring, unit = "" },
}

-- The ladders for the numbers { hours, streak, finished }: each as
-- { name, items = { { name, short, got } } }.
function Achievements.ladders(numbers)
    local out = {}
    for _i, ladder in ipairs(LADDERS) do
        local value = ladder.of(numbers)
        local items = {}
        for _j, level in ipairs(ladder.levels) do
            items[#items + 1] = { name = string.format("%s_%d%s", ladder.name, level, ladder.unit),
                short = ladder.short(level), got = value >= level }
        end
        out[#out + 1] = { name = ladder.name, items = items }
    end
    return out
end

-- How many are earned in all, and the name of the last earned in the ladders'
-- order (nil when none).
function Achievements.summary(ladders)
    local got, latest = 0, nil
    for _i, l in ipairs(ladders) do
        for _j, a in ipairs(l.items) do
            if a.got then got = got + 1; latest = a.name end
        end
    end
    return got, latest
end

return Achievements
