-- One data shard whole: the highlight, its note, chapter and date, with the way
-- to open the book at that place and another shard. params: { shard, number, of }.

local Actions = require("cyberui/actions")
local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Frame = require("cyberui/screens/frame")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Screen = require("cyberui/screens/screen")
local ShardCard = require("cyberui/ui/shardcard")
local Shards = require("cyberui/data/shards")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local ShardScreen = Screen:extend()

-- Build the screen.
function ShardScreen:build()
    local th = Theme.get()
    local p = self.params
    local s = p.shard
    local kids = { ShardCard:new({ shard = s, number = p.number, of = p.of, lines = 12, text_kind = "body" }) }
    local facts = {}
    if s.chapter and s.chapter ~= "" then facts[#facts + 1] = s.chapter end
    if s.date then facts[#facts + 1] = s.date end
    if #facts > 0 then kids[#kids + 1] = Label:new({ text = table.concat(facts, " // "), kind = "mono_small", color = "muted", lines = 2 }) end
    if s.note then
        kids[#kids + 1] = Label:new({ text = _("YOUR NOTE"), kind = "micro", color = "muted" })
        kids[#kids + 1] = Label:new({ text = s.note, kind = "body", lines = 4 })
    end
    local actions = {
        Button:new({ icon = "shard", variant = "icon", width = th.size.touch, on_tap = function()
            local pick = Shards.another()
            if pick then
                p.shard, p.number, p.of = pick.shard, pick.number, pick.of
                App.update()
            end
        end }),
        Button:new({ icon = "forward", variant = "icon_on", width = th.size.touch, on_tap = function() Actions.openAt(s.path, s) end }),
    }
    return Frame.page({ screen = self, title = _("Data shard"), path = "0x" .. s.id:sub(1, 4) .. " // RECOVERED", tab = "history", actions = actions,
        body = Layout.Column:new({ gap = th.space.m, children = kids }) })
end

return ShardScreen
