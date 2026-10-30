-- Widgets on KOReader's real blitter: every element lays out and paints in
-- every scheme and mode without errors, taps reach the right element, and a
-- sheet of all of them is saved for a look (out/widgets-<scheme>-<mode>.png).
-- Run: cd <emulator>/koreader && ./luajit <repo>/tests/widgets.lua <repo> [out_dir]

local REPO, OUT = arg[1] or ".", arg[2]
local Kit = dofile(REPO .. "/tests/kit.lua").boot(REPO)

local Theme = require("cyberui/theme")
local Layout = require("cyberui/ui/layout")
local Label = require("cyberui/ui/label")
local Button = require("cyberui/ui/button")
local Panel = require("cyberui/ui/panel")
local Progress = require("cyberui/ui/progress")
local Controls = require("cyberui/ui/controls")
local Deco = require("cyberui/ui/deco")
local Icon = require("cyberui/ui/icon")
local Registry = require("cyberui/theme/registry")

local tapped
-- One of everything, in a column.
local function sheet()
    local function btn(v, label, extra)
        local o = { variant = v, label = label, on_tap = function() tapped = label end }
        for k, val in pairs(extra or {}) do o[k] = val end
        return Button:new(o)
    end
    return Layout.Column:new({ pad = 16, gap = 10, children = {
        Label:new({ text = "Display heading", kind = "display" }),
        Label:new({ text = "Body text that is long enough to need an ellipsis at the end of the line for sure", kind = "body" }),
        Label:new({ text = "mono 0123456789 // micro", kind = "mono", color = "muted" }),
        Layout.Row:new({ gap = 8, children = {
            btn("primary", "Resume", { icon = "forward" }), btn("secondary", "Secondary"), btn("soft", "Soft", { sub = "sub line" }),
        } }),
        Layout.Row:new({ gap = 8, children = {
            btn("chip_on", "Reading"), btn("chip", "Unread"), btn("ghost", "Ghost"), btn("icon", nil, { icon = "search", width = 44 }),
            btn("secondary", "Locked", { disabled = true }),
        } }),
        Progress:new({ value = 0.64 }),
        Layout.Row:new({ gap = 12, children = {
            Controls.Toggle:new({ on = true }), Controls.Toggle:new({ on = false }),
            Controls.Stepper({ value = 6, min = 1, max = 20, format = function(v) return v .. " PG" end }),
        } }),
        Controls.Segmented({ options = { { "Light", "light" }, { "Dark", "dark" }, { "System", "system" } }, value = "dark" }),
        Panel:new({ shape = "chamfer", label = "Active file", pad = 12, child = Label:new({ text = "Chamfer panel" }) }),
        Panel:new({ shape = "brackets", label = "Brackets", pad = 12, child = Label:new({ text = "Bracket frame" }) }),
        Panel:new({ shape = "header", title = "$ cat ./now_reading", title_right = "PID 0412", pad = 10,
            child = Label:new({ text = "Header panel" }) }),
        Layout.Row:new({ gap = 8, height = 30, children = {
            Deco.Barcode:new({ width = 90 }), Deco.Stripes:new({ width = 90, dir = "d" }), Deco.Ruler:new({ grow = true }),
            Icon:new({ name = "home" }), Icon:new({ name = "library", color = "accent" }),
        } }),
    } })
end

local W, H = Kit.Screen:getWidth(), Kit.Screen:getHeight()
for _, s in ipairs(Registry.schemeList()) do
    for _, mode in ipairs({ "light", "dark" }) do
        local Settings = require("cyberui/settings")
        Settings.set("scheme", s.id)
        Settings.set("mode", mode)
        Theme.refresh()
        local root = sheet()
        local ok, err = pcall(function()
            root:layout(W, H)
            local bb = Kit.canvas()
            local t = Theme.get()
            require("cyberui/gfx/paint").fill(bb, 0, 0, W, H, t.c.bg)
            root:paint(bb, 0, 0)
            if OUT then Kit.png(bb, string.format("%s/widgets-%s-%s.png", OUT, s.id, mode)) end
            bb:free()
        end)
        Kit.ok(ok, s.id .. "/" .. mode .. " paints: " .. tostring(err))
    end
end

-- taps land on the innermost element that answers them
do
    local root = sheet()
    root:layout(W, H)
    local bb = Kit.canvas()
    root:paint(bb, 0, 0)
    local resume = root.children[4].children[1]
    local hit = root:hit(resume.x + 5, resume.y + 5, "on_tap")
    Kit.ok(hit == resume, "a tap on Resume finds Resume")
    hit.on_tap()
    Kit.ok(tapped == "Resume", "and runs its action")
    local locked = root.children[5].children[5]
    Kit.ok(root:hit(locked.x + 5, locked.y + 5, "on_tap") == nil, "a disabled button takes no taps")
    Kit.ok(root:hit(W - 2, H - 2, "on_tap") == nil, "empty room takes no taps")
    -- timing: a whole sheet laid out and painted
    local ms = Kit.time(function() root:layout(W, H); root:paint(bb, 0, 0) end, 30)
    print(string.format("sheet layout+paint: %.2f ms", ms))
    Kit.ok(ms < 30, "a full sheet paints in under 30 ms")
    bb:free()
end

-- a tap between the tabs is swallowed (it must not reach KOReader's corner gestures)
do
    local bar = require("cyberui/ui/tabbar").build({ { id = "a", label = "A" }, { id = "b", label = "B" } }, "a", function() end)
    bar:layout(W, nil)
    bar:paint(Kit.canvas(), 0, 0)
    local gap = bar:hit(W / 2, 2, "on_tap")
    Kit.ok(gap ~= nil and gap.on_tap == nil, "the tab bar swallows taps that miss a tab")
end

-- Arabic is shaped and measured as joined text, and paints
do
    local Text = require("cyberui/gfx/text")
    local ar = "مرحبا بالعالم"
    local w = Text.width("body", ar)
    Kit.ok(w > 0, "Arabic text has a width")
    local bb = Kit.canvas()
    local drawn = Text.draw(bb, 10, 10, "body", ar, Theme.color("ink"))
    Kit.ok(drawn == w, "and is drawn as wide as it is measured")
    local plain = 0
    for _i, cp in ipairs(Text.codepoints(ar)) do
        plain = plain + require("ui/rendertext"):getGlyph(Theme.text("body").face, cp, false).ax
    end
    Kit.ok(w ~= plain, "joined letters measure differently from isolated ones")
    bb:free()
end

Kit.finish("widgets")
