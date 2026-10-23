-- A book in a grid: its cover with a status badge, the title under it and a
-- thin progress line. Tap and hold actions come from the caller.

local Books = require("cyberui/data/books")
local Cover = require("cyberui/ui/cover")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Progress = require("cyberui/ui/progress")
local Theme = require("cyberui/theme")

local BookTile = {}

-- Build a tile w x h for `path`; o: { on_tap, on_hold }.
function BookTile.build(path, _w, h, o)
    local th = Theme.get()
    local badge, badge_on = Books.badge(path)
    local title_h = th.space.xs + Theme.text("small").height
    local bar_h = Theme.px(4)
    local cover_h = h - title_h - bar_h - th.space.xs
    return Layout.Column:new({ gap = th.space.xs, on_tap = o.on_tap, on_hold = o.on_hold, children = {
        Cover:new({ path = path, height = cover_h, badge = badge, badge_on = badge_on }),
        Label:new({ text = Books.info(path).title, kind = "small" }),
        Progress:new({ value = Books.state(path).percent, segments = 1, height = bar_h }),
    } })
end

-- Build a folder tile w x h: the cover of `first` (its first book, or nil
-- when it has none) stacked as a folder, `count` books inside.
function BookTile.folder(folder, _w, h, count, on_tap, first)
    local th = Theme.get()
    local title_h = th.space.xs + Theme.text("small").height
    return Layout.Column:new({ gap = th.space.xs, on_tap = on_tap, children = {
        Cover:new({ path = first, title = not first and folder.name or nil, height = h - title_h - Theme.px(4) - th.space.xs,
            folder = true, stack = first ~= nil, count = count }),
        Label:new({ text = folder.name, kind = "small" }),
        Layout.Spacer:new({ height = Theme.px(4) }),
    } })
end

return BookTile
