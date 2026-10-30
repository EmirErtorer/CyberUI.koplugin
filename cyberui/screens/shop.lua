-- The shop: styles for the ID card and the jack-in card, bought with eddies.
-- One tab per category, each style shown as it really looks. A style you own is
-- worn with a tap; one you do not own opens a full preview with the price,
-- and the buy button only works when the eddies are there.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Controls = require("cyberui/ui/controls")
local Format = require("cyberui/format")
local Frame = require("cyberui/screens/frame")
local IdCard = require("cyberui/ui/idcard")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Ledger = require("cyberui/data/ledger")
local Library = require("cyberui/data/library")
local Panel = require("cyberui/ui/panel")
local Screen = require("cyberui/screens/screen")
local Shop = require("cyberui/data/shop")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

local ShopScreen = Screen:extend()

-- Start on the first tab, first page.
function ShopScreen:init()
    self.cat, self.page = Shop.categories[1].id, 1
end

-- The book the jack-in previews show: the first in the library.
local function sampleBook()
    return Library.all()[1] or "/Sample Book.epub"
end

-- The style on its own, as it looks: a small card, or the jack-in card.
local function preview(cat, style)
    if cat == "jackin" then return style.build(sampleBook()) end
    return IdCard.sample({ styles = { [cat] = style } })
end

-- The line under a preview: what a tap does, or what is still missing.
local function hint(style)
    local status, missing = Shop.status(style)
    if status == "worn" then return _("EQUIPPED"), "accent" end
    if status == "owned" then return _("TAP TO EQUIP"), "muted" end
    if status == "buy" then return _("TAP TO BUY"), "accent" end
    return string.format(_("NEED %s MORE"), Format.credits(missing)), "muted"
end

-- The full preview of a style not owned yet, with its buy button.
local function buyDialog(cat, style)
    local th = Theme.get()
    App.dialog(function(close, screen_w)
        local width = math.min(screen_w - 2 * th.space.xl, Theme.px(560))
        local _status, missing = Shop.status(style)
        local buy = Button:new({ icon = "forward", variant = "primary", grow = true, disabled = missing > 0,
            label = missing > 0 and string.format(_("NEED %s MORE"), Format.credits(missing)) or string.format(_("BUY %s"), Format.credits(style.price)),
            on_tap = function()
                if Shop.buy(style) then
                    Shop.wear(style)
                    close()
                    App.toast(_("UNLOCKED // EQUIPPED"))
                    App.update()
                end
            end })
        local shown = cat == "jackin" and style.build(sampleBook()) or IdCard.full({ width = width - 2 * th.space.m, styles = { [cat] = style } })
        return Panel:new({ shape = "frame", pad = th.space.m, fill = "bg", width = width,
            child = Layout.Column:new({ gap = th.space.m, children = {
                shown,
                Layout.Row:new({ gap = th.space.s, children = { buy,
                    Button:new({ icon = "close", variant = "icon", width = th.size.touch, on_tap = close }) } }),
            } }) })
    end)
end

-- One style: its name and price (or state), the preview and a hint line.
local function entry(cat, style)
    local th = Theme.get()
    local owned = Shop.owned(style)
    local note, colour = hint(style)
    return Panel:new({ shape = "none", pad = { th.space.s, 0, th.space.s, 0 },
        on_tap = function()
            if owned then
                Shop.wear(style)
                App.toast(_("EQUIPPED"))
                App.update()
            else
                buyDialog(cat, style)
            end
        end,
        child = Layout.Column:new({ gap = th.space.xs, children = {
            Layout.Row:new({ children = {
                Label:new({ text = style.name, kind = "heading", grow = true }),
                Label:new({ text = owned and (style.price == 0 and _("FREE") or _("OWNED")) or Format.credits(style.price), kind = "mono", color = owned and "muted" or "accent" }),
            } }),
            preview(cat, style),
            Label:new({ text = note, kind = "mono_small", color = colour }),
        } }) })
end

-- The cheapest style not owned yet, as a line that says how far off it is.
local function nextLine()
    local best
    for _i, cat in ipairs(Shop.categories) do
        for _j, style in ipairs(cat.styles) do
            if not Shop.owned(style) and (not best or style.price < best.price) then best = style end
        end
    end
    if not best then return nil end
    local missing = best.price - Ledger.balance()
    return missing > 0 and string.format(_("NEXT: %s // NEED %s MORE"), best.name, Format.credits(missing))
        or string.format(_("NEXT: %s // READY TO BUY"), best.name)
end

-- Build the screen.
function ShopScreen:build()
    local th = Theme.get()
    local options = {}
    for i, cat in ipairs(Shop.categories) do options[i] = { cat.name, cat.id } end
    local tabs = Controls.Segmented({ options = options, value = self.cat, kind = "label",
        on_change = function(v) self.cat, self.page = v, 1; App.update() end })
    local items = {}
    for _i, style in ipairs(Shop.category(self.cat).styles) do items[#items + 1] = entry(self.cat, style) end
    local kids = { tabs }
    local line = nextLine()
    if line then kids[#kids + 1] = Label:new({ text = line, kind = "mono_small", color = "muted" }) end
    kids[#kids + 1] = Frame.paged(self, items, _("SHOP"))
    return Frame.page({ screen = self, title = _("SHOP"), path = string.format(_("SHOP // BALANCE %s"), Format.credits(Ledger.balance())),
        tab = "library", body = Layout.Column:new({ gap = th.space.m, children = kids }) })
end

return ShopScreen
