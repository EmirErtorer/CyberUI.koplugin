-- Jack-in cards: what the screen shows while a book opens. Each style is
-- { id, name, price, build(path) -> element }. The load blocks, so nothing on
-- a card can move and none shows made-up progress; a card is the book (cover,
-- title, where reading resumes) in some arrangement, painted once just before
-- the load starts, so a style costs one small paint and nothing else.

local Books = require("cyberui/data/books")
local Cover = require("cyberui/ui/cover")
local Deco = require("cyberui/ui/deco")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Paint = require("cyberui/gfx/paint")
local Panel = require("cyberui/ui/panel")
local Profile = require("cyberui/data/profile")
local Theme = require("cyberui/theme")
local _ = require("cyberui/gettext")

local px = Theme.px

-- The width of a card: the screen less its margins, at most 560.
local function cardWidth()
    return math.min(require("device").screen:getWidth() - 2 * Theme.get().space.xl, px(560))
end

-- Where reading resumes, as a line.
local function resumeLine(path)
    local st = Books.state(path)
    return st.percent > 0 and string.format(_("RESUMING AT %d%%"), math.floor(st.percent * 100 + 0.5)) or _("FIRST OPEN")
end

-- The book's cover, title and author.
local function bookLines(path, kind)
    local info = Books.info(path)
    return Label:new({ text = info.title, kind = kind or "display", lines = 3 }),
        Label:new({ text = info.author or "", kind = "body", color = "muted" })
end

-- The plain card: cover left, the facts and a striped working bar right.
local function standard(path)
    local th = Theme.get()
    local title, author = bookLines(path)
    return Panel:new({ shape = "header", title = _("JACK-IN"), title_right = _("DECRYPTING..."), pad = th.space.l, fill = "bg", width = cardWidth(),
        child = Layout.Row:new({ gap = th.space.l, valign = "stretch", children = {
            Cover:new({ path = path, width = px(112), height = px(164) }),
            Layout.Column:new({ grow = true, gap = th.space.xs, children = {
                title, author, Layout.Spacer:new({ height = th.space.s }),
                Label:new({ text = resumeLine(path), kind = "mono" }),
                Label:new({ text = _("[OK] MOUNT FILE // [OK] READ INDEX"), kind = "mono_small", color = "muted" }),
                Label:new({ text = _("[..] RENDERING PAGE"), kind = "mono_small" }),
                Layout.Spacer:new({ height = th.space.s }),
                Deco.Stripes:new({ dir = "d", height = px(14), color = "ink" }),
            } }),
        } }) })
end

-- All text on an inverted screen, like a terminal session.
local function terminal(path)
    local th = Theme.get()
    local info = Books.info(path)
    local function line(text, color) return Label:new({ text = text, kind = "mono", color = color or "on_ink", lines = 2 }) end
    return Panel:new({ shape = "frame", pad = th.space.l, fill = "ink", line = "ink", width = cardWidth(),
        child = Layout.Column:new({ gap = th.space.s, children = {
            Label:new({ text = _("JACK-IN"), kind = "micro", color = "on_ink" }),
            Deco.Stripes:new({ dir = "h", height = px(6), period = px(3), thick = px(1), color = "on_ink" }),
            line("$ mount " .. info.title), -- i18n: keep
            line("> " .. resumeLine(path)), -- i18n: keep
            line(_("[OK] MOUNT FILE // [OK] READ INDEX")),
            line(_("[..] RENDERING PAGE")),
            line("> _"), -- i18n: keep
            Deco.Stripes:new({ dir = "h", height = px(6), period = px(3), thick = px(1), color = "on_ink" }),
        } }) })
end

-- A big cover with the title on a filled band under it.
local function poster(path)
    local th = Theme.get()
    local info = Books.info(path)
    return Panel:new({ shape = "brackets", pad = th.space.l, fill = "bg", width = cardWidth(),
        child = Layout.Column:new({ gap = th.space.m, children = {
            Layout.Row:new({ children = { Layout.Spacer:new({ grow = true }), Cover:new({ path = path, width = px(210), height = px(310) }),
                Layout.Spacer:new({ grow = true }) } }),
            Panel:new({ shape = "chamfer", corners = "tb", cut = "cut_small", fill = "accent", line = false, pad = th.space.m,
                child = Layout.Column:new({ gap = th.space.xs, children = {
                    Label:new({ text = info.title, kind = "display", color = "on_accent", align = "center", lines = 3 }),
                    Label:new({ text = (info.author or "") .. "  //  " .. resumeLine(path), kind = "mono_small", color = "on_accent", align = "center" }), -- i18n: keep
                } }) }),
        } }) })
end

-- A pass: the facts on the left, a barcode stub on the right, punched between them.
local function ticket(path)
    local th = Theme.get()
    local title, author = bookLines(path)
    local rnd = Profile.rng(path)
    return Panel:new({ shape = "chamfer", corners = "tb", cut = "cut", pad = th.space.l, fill = "bg", width = cardWidth(),
        child = Layout.Row:new({ gap = th.space.l, valign = "stretch", children = {
            Layout.Column:new({ grow = true, gap = th.space.xs, children = {
                Label:new({ text = _("ADMIT ONE"), kind = "micro", color = "accent" }),
                Deco.Stripes:new({ dir = "h", height = px(8), period = px(4), thick = px(2), color = "accent" }),
                title, author, Layout.Spacer:new({ height = th.space.s }),
                Label:new({ text = resumeLine(path), kind = "mono" }),
            } }),
            Deco.Stripes:new({ dir = "v", width = px(4), period = px(8), thick = px(3), color = "accent" }),
            Layout.Column:new({ width = px(110), gap = th.space.s, children = {
                Deco.Barcode:new({ bars = Paint.barsFrom(rnd), height = px(150) }),
                Label:new({ text = string.format("%04X", math.floor(rnd() * 65535)), kind = "mono", align = "center" }), -- i18n: keep
            } }),
        } }) })
end

-- A cover under sights with a scan beam across it, read out like a target lock.
local function scanner(path)
    local th = Theme.get()
    local title, author = bookLines(path, "heading")
    local rnd = Profile.rng(path)
    local cover = Layout.Overlay:new({ width = px(130), height = px(190), children = {
        Cover:new({ path = path, width = px(130), height = px(190) }),
        Layout.Column:new({ children = { Layout.Spacer:new({ height = px(70) }),
            Deco.Stripes:new({ dir = "h", height = px(22), period = px(3), thick = px(2), color = "accent" }) } }),
    } })
    return Panel:new({ shape = "brackets", label = _("TARGET_LOCKED"), pad = th.space.l, fill = "bg", width = cardWidth(),
        child = Layout.Row:new({ gap = th.space.l, valign = "stretch", children = {
            Panel:new({ shape = "brackets", pad = th.space.s, child = cover }),
            Layout.Column:new({ grow = true, gap = th.space.xs, children = {
                Label:new({ text = _("SCANNING..."), kind = "micro", color = "accent" }),
                Deco.Stripes:new({ dir = "h", height = px(10), period = px(5), thick = px(2), color = "accent" }),
                title, author,
                Label:new({ text = string.format("X %.2f  Y %.2f", rnd(), rnd()), kind = "mono_small", color = "muted" }), -- i18n: keep
                Label:new({ text = resumeLine(path), kind = "mono" }),
                Deco.Ruler:new({ height = px(8) }),
            } }),
        } }) })
end

return {
    { id = "jackin.standard", name = _("STANDARD"), price = 0, build = standard },
    { id = "jackin.terminal", name = _("TERMINAL"), price = 150, build = terminal },
    { id = "jackin.poster", name = _("POSTER"), price = 300, build = poster },
    { id = "jackin.ticket", name = _("TICKET"), price = 550, build = ticket },
    { id = "jackin.scanner", name = _("SCANNER"), price = 1000, build = scanner },
}
