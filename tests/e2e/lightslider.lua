-- The frontlight and warmth rows of the menu's Deck tab are sliders: a tap
-- sets the value under the finger (the emulator has a frontlight of 0 to 100).
local H = ...
local Device = require("device")

-- The sliders in the open menu's panel.
local function sliders()
    local out = {}
    local function walk(e)
        if e.min and e.max and e.on_change then out[#out + 1] = e end
        for _i, c in ipairs(e.children or { e.child }) do if c then walk(c) end end
    end
    walk(require("cyberui/app").overlay())
    return out
end

H.step(2, function()
    local m = require("cyberui/menu").open({})
    for i, t in ipairs(m.tabs) do if t.deck then m:switchTab(i) end end
    m:turnDeck(1)   -- the Controls page
end)
H.step(1.5, function()
    local s = sliders()
    H.check(#s == 2, "lumen and tint are sliders")
    H.tapAt(s[1].x + s[1]:trackWidth() * 0.25, s[1].y + s[1].h / 2)
end)
H.step(1, function()
    local v = Device:getPowerDevice():frontlightIntensity()
    H.check(math.abs(v - 25) <= 5, "a tap at a quarter sets the light to about a quarter (" .. tostring(v) .. ")")
    H.shot("sliders")
    local s = sliders()[1]
    H.tapAt(s.x + s:trackWidth() * 0.9, s.y + s.h / 2)
end)
H.step(1, function()
    local v = Device:getPowerDevice():frontlightIntensity()
    H.check(math.abs(v - 90) <= 5, "and at nine tenths to about 90 (" .. tostring(v) .. ")")
    H.shot("sliders-after")
end)
