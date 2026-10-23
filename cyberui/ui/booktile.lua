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
function BookTile.build(path, w, h, o)
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

-- Build a folder tile w x h; `count` books inside (nil when unknown).
function BookTile.folder(folder, w, h, count, on_tap)
    local th = Theme.get()
    local title_h = th.space.xs + Theme.text("small").height
    return Layout.Column:new({ gap = th.space.xs, on_tap = on_tap, children = {
        Cover:new({ title = folder.name, height = h - title_h - Theme.px(4) - th.space.xs, folder = true,
            badge = (count and count > 0) and tostring(count) or nil }),
        Label:new({ text = folder.name, kind = "small" }),
        Layout.Spacer:new({ height = Theme.px(4) }),
    } })
end

return BookTile
