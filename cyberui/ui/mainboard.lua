-- A see-through view of an e-reader's main board for the empty space of the
-- Diagnostics screen: the parts a real e-reader has (processor and memory in
-- ball-grid packages, flash, power chip with its inductors, frontlight driver,
-- touch controller, radio module under its shield can, the display and touch
-- flex connectors, USB-C, battery connector, crystals, decoupling, screws), joined
-- by straight orthogonal traces and labelled like silkscreen.
--
-- It is drawn in a fixed 1128 x 472 plan scaled to the room it has, centred,
-- and not at all when the room is too small to read it. Colours come from the
-- theme; nothing here changes after it is drawn, so it costs one paint.

local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local Mainboard = Element:extend()

local PLAN_W, PLAN_H = 1128, 472
local MIN_SCALE = 0.62       -- below this the parts would be too small to tell apart
local LABEL_SCALE = 0.8      -- below this the silkscreen text would crowd, so it is left out

local floor, max, min = math.floor, math.max, math.min

-- Nothing of its own to size by: it takes what the screen leaves.
function Mainboard:naturalHeight() return 0 end

-- Draw the plan (or nothing when the room is too small).
function Mainboard:draw(bb, x, y)
    local s = min(self.w / PLAN_W, self.h / PLAN_H)
    if s < MIN_SCALE then return end
    local th = Theme.get()
    local c = th.c
    local ox, oy = x + floor((self.w - PLAN_W * s) / 2), y + floor((self.h - PLAN_H * s) / 2)
    local labels = s >= LABEL_SCALE

    ---------------------------------------------------------------- the plan's own drawing tools
    local function R(v) return floor(v * s + 0.5) end
    -- a box from plan coordinates, its edges rounded the same way everywhere so lines stay straight
    local function box(bx, by, bw, bh, col)
        local x0, y0, x1, y1 = R(bx), R(by), R(bx + bw), R(by + bh)
        Paint.fill(bb, ox + x0, oy + y0, max(1, x1 - x0), max(1, y1 - y0), col)
    end
    local function frame(bx, by, bw, bh, col, t)
        t = t or 2
        box(bx, by, bw, t, col); box(bx, by + bh - t, bw, t, col)
        box(bx, by + t, t, bh - 2 * t, col); box(bx + bw - t, by + t, t, bh - 2 * t, col)
    end
    local function hline(x1, x2, ly, col, t) t = t or 2; box(min(x1, x2), ly - t / 2, math.abs(x2 - x1), t, col) end
    local function vline(lx, y1, y2, col, t) t = t or 2; box(lx - t / 2, min(y1, y2), t, math.abs(y2 - y1), col) end
    local function disc(cx, cy, r, col)
        local pts = {}
        for i = 0, 19 do local a = i * math.pi / 10; pts[#pts + 1] = { ox + R(cx + r * math.cos(a)), oy + R(cy + r * math.sin(a)) } end
        Paint.polygon(bb, pts, col)
    end
    local function ring(cx, cy, r, col, t)
        local pts = {}
        for i = 0, 23 do local a = i * math.pi / 12; pts[#pts + 1] = { ox + R(cx + r * math.cos(a)), oy + R(cy + r * math.sin(a)) } end
        Paint.outline(bb, pts, max(1, R(t or 2)), col)
    end
    local TH = Text.height("micro") / s                      -- a line of silkscreen, in plan units
    local function textWidth(str) return Text.width("micro", str) / s end
    -- a label centred in a part's body (nothing when it would not fit), so it sits on the part
    local function inside(bx, by, bw, bh, str, col)
        if not labels or textWidth(str) + 8 > bw or TH + 2 > bh then return end
        Text.draw(bb, ox + R(bx + (bw - textWidth(str)) / 2), oy + R(by + (bh - TH) / 2), "micro", str, col or c.ink)
    end
    -- a label centred on x just under (or over) a part, close to it
    local function under(cx, y_bottom, str, col)
        if labels then Text.draw(bb, ox + R(cx - textWidth(str) / 2), oy + R(y_bottom + 4), "micro", str, col or c.muted) end
    end
    local function over(cx, y_top, str, col)
        if labels then Text.draw(bb, ox + R(cx - textWidth(str) / 2), oy + R(y_top - 4 - TH), "micro", str, col or c.muted) end
    end

    ---------------------------------------------------------------- the parts
    local COPPER, POWER = c.accent2, c.accent

    -- the board and its mounting holes
    Paint.chamfer(bb, ox, oy, R(PLAN_W), R(PLAN_H), R(26), "trbl", c.soft)
    Paint.chamferFrame(bb, ox, oy, R(PLAN_W), R(PLAN_H), R(26), "trbl", max(2, R(3)), c.muted)
    for _i, p in ipairs({ { 34, 34 }, { 1094, 34 }, { 34, 438 }, { 1094, 438 } }) do
        disc(p[1], p[2], 15, c.bg); ring(p[1], p[2], 15, c.muted, 2); ring(p[1], p[2], 22, c.line, 1)
    end

    -- an IC in a ball-grid package: its name in a band on top, the balls under it, pin 1 marked
    local function bga(g, label)
        local band = TH + 10
        box(g.x, g.y, g.w, g.h, c.bg); frame(g.x, g.y, g.w, g.h, c.muted, 2)
        hline(g.x, g.x + g.w, g.y + band, c.muted, 2)
        inside(g.x, g.y, g.w, band, label)
        local cols, rows = floor((g.w - 24) / 14), floor((g.h - band - 16) / 14)
        local gx, gy = g.x + (g.w - (cols - 1) * 14) / 2, g.y + band + (g.h - band - (rows - 1) * 14) / 2
        for r = 0, rows - 1 do
            for q = 0, cols - 1 do box(gx + q * 14 - 2, gy + r * 14 - 2, 4, 4, c.line) end
        end
        box(g.x + 6, g.y + band + 6, 8, 8, c.accent)   -- pin 1
    end

    -- an IC with pads on its sides (a QFN): the pads, an exposed centre with its name on it, pin 1
    local function qfn(g, label, pads)
        for i = 0, pads - 1 do
            local fx = g.x + 8 + i * ((g.w - 16 - 4) / (pads - 1))
            box(fx, g.y - 7, 4, 7, c.muted); box(fx, g.y + g.h, 4, 7, c.muted)
        end
        for i = 0, pads - 1 do
            local fy = g.y + 8 + i * ((g.h - 16 - 4) / (pads - 1))
            box(g.x - 7, fy, 7, 4, c.muted); box(g.x + g.w, fy, 7, 4, c.muted)
        end
        box(g.x, g.y, g.w, g.h, c.bg); frame(g.x, g.y, g.w, g.h, c.muted, 2)
        box(g.x + 12, g.y + 12, g.w - 24, g.h - 24, c.line)
        box(g.x + 5, g.y + 5, 6, 6, c.accent)
        inside(g.x + 12, g.y + 12, g.w - 24, g.h - 24, label)
    end

    -- a two-pad part (capacitor or resistor) lying across
    local function passive(px_, py_, dark)
        box(px_, py_, 14, 8, dark and c.bg or c.muted)
        box(px_, py_, 3, 8, c.accent2); box(px_ + 11, py_, 3, 8, c.accent2)
    end

    -- a power inductor: a square with its winding
    local function inductor(ix, iy)
        box(ix, iy, 30, 30, c.bg); frame(ix, iy, 30, 30, c.muted, 2)
        for k = 1, 3 do hline(ix + 6, ix + 24, iy + 5 + k * 6, c.line, 2) end
    end

    -- a crystal: a metal can on two pads, its frequency on it
    local function crystal(g, label)
        box(g.x + 6, g.y + g.h, 14, 8, c.accent2); box(g.x + g.w - 20, g.y + g.h, 14, 8, c.accent2)
        box(g.x, g.y, g.w, g.h, c.bg); frame(g.x, g.y, g.w, g.h, c.muted, 2)
        inside(g.x, g.y, g.w, g.h, label)
    end

    -- a flex (ZIF) connector: housing with its name on it, contact fingers running on into the board
    local function zif(g, label)
        for i = 0, g.fingers - 1 do box(g.x + 10 + i * ((g.w - 24) / (g.fingers - 1)), g.y + g.h, 3, 16, c.accent) end
        box(g.x, g.y, g.w, g.h, c.bg); frame(g.x, g.y, g.w, g.h, c.muted, 2)
        inside(g.x, g.y, g.w, g.h, label)
    end

    ---------------------------------------------------------------- the layout (plan units)
    local SOC = { x = 262, y = 128, w = 150, h = 150 }
    local DDR = { x = 490, y = 128, w = 120, h = 84 }
    local EMMC = { x = 490, y = 236, w = 120, h = 84 }
    local FLD = { x = 80, y = 128, w = 76, h = 64 }
    local PMIC = { x = 80, y = 224, w = 100, h = 100 }
    local TOUCH = { x = 736, y = 140, w = 96, h = 72 }
    local WIFI = { x = 850, y = 128, w = 190, h = 110 }
    local EPD = { x = 232, y = 40, w = 330, h = TH + 14, fingers = 24 }
    local TFPC = { x = 700, y = 40, w = 150, h = TH + 14, fingers = 12 }
    local USB = { x = 560, y = 408, w = 140, h = TH + 20 }
    local BATT = { x = 70, y = 392, w = 80, h = TH + 14 }
    local XT24 = { x = 422, y = 296, w = 60, h = TH + 8 }
    local XT32 = { x = 206, y = 376, w = 60, h = TH + 8 }
    local PWR = { x = 972, y = 330, w = 40, h = 40 }
    local function finger(z, i) return z.x + 10 + i * ((z.w - 24) / (z.fingers - 1)) + 1.5 end

    -- traces first, so the parts sit on them
    for i = 3, 10 do vline(finger(EPD, i), EPD.y + EPD.h + 16, SOC.y, COPPER, 2) end        -- display flex straight into the processor
    for k = 0, 7 do hline(SOC.x + SOC.w, DDR.x, DDR.y + 8 + k * 9, COPPER, 2) end           -- processor to memory
    for k = 0, 5 do hline(SOC.x + SOC.w, EMMC.x, EMMC.y + 12 + k * 9, COPPER, 2) end        -- processor to flash
    for i = 3, 6 do vline(finger(TFPC, i), TFPC.y + TFPC.h + 16, TOUCH.y - 7, COPPER, 2) end -- touch flex into the touch controller
    local back_x, back_y = TOUCH.x + TOUCH.w - 8, 108
    vline(back_x, back_y, TOUCH.y - 7, COPPER, 2)                                           -- and its return to the processor
    hline(SOC.x + SOC.w - 12, back_x, back_y, COPPER, 2)
    vline(SOC.x + SOC.w - 12, back_y, SOC.y, COPPER, 2)
    local rad_top = WIFI.y + WIFI.h + 8
    for k = 0, 3 do                                                                         -- radio: down, across under the flash, up
        local lx, ly, ux = SOC.x + 118 + k * 9, 352 + k * 9, WIFI.x + 30 + k * 9
        vline(lx, SOC.y + SOC.h, ly, COPPER, 2)
        hline(lx, ux, ly, COPPER, 2)
        vline(ux, ly, rad_top, COPPER, 2)
    end
    hline(PMIC.x + PMIC.w + 7, SOC.x, 248, POWER, 4)                                        -- power chip to processor, two rails
    hline(PMIC.x + PMIC.w + 7, SOC.x, 268, POWER, 4)
    vline(BATT.x + 20, BATT.y - 7, PMIC.y + PMIC.h + 7, POWER, 4)                           -- battery up into the power chip
    vline(BATT.x + 40, BATT.y - 7, PMIC.y + PMIC.h + 7, c.accent2, 4)
    local usb_y = USB.y + floor(USB.h / 2)
    hline(USB.x, PMIC.x + 86, usb_y, POWER, 4)                                              -- USB supply along the bottom
    vline(PMIC.x + 86, usb_y, PMIC.y + PMIC.h + 7, POWER, 4)
    vline(FLD.x + 38, FLD.y + FLD.h + 7, PMIC.y - 7, COPPER, 2)                             -- frontlight driver to the power chip
    for _i, v in ipairs({ { SOC.x + SOC.w - 12, back_y }, { back_x, back_y }, { PMIC.x + 86, usb_y } }) do
        box(v[1] - 5, v[2] - 5, 10, 10, c.bg); frame(v[1] - 5, v[2] - 5, 10, 10, c.muted, 2)   -- vias where traces turn
    end

    -- the parts
    zif(EPD, "DISPLAY FPC")
    zif(TFPC, "TOUCH FPC")
    bga(SOC, "SoC")
    bga(DDR, "LPDDR3")
    bga(EMMC, "eMMC")
    qfn(PMIC, "PMIC", 8)
    qfn(FLD, "LED", 5)
    qfn(TOUCH, "TOUCH", 6)
    inductor(FLD.x + 90, FLD.y + 17)
    inductor(196, 300)
    inductor(238, 300)
    crystal(XT24, "24M")
    crystal(XT32, "32K")
    -- the radio under its shield can, dimples on the lid, pads round the edge
    for i = 0, 9 do
        box(WIFI.x + 10 + i * ((WIFI.w - 24) / 9), WIFI.y + WIFI.h, 4, 8, c.muted)
        box(WIFI.x + 10 + i * ((WIFI.w - 24) / 9), WIFI.y - 8, 4, 8, c.muted)
    end
    box(WIFI.x, WIFI.y, WIFI.w, WIFI.h, c.bg); frame(WIFI.x, WIFI.y, WIFI.w, WIFI.h, c.muted, 2)
    frame(WIFI.x + 8, WIFI.y + 8, WIFI.w - 16, WIFI.h - 16, c.line, 1)
    for q = 0, 6 do for r = 0, 3 do disc(WIFI.x + 26 + q * ((WIFI.w - 52) / 6), WIFI.y + 22 + r * ((WIFI.h - 44) / 3), 3, c.line) end end
    local lw = textWidth("WIFI/BT") + 16
    box(WIFI.x + (WIFI.w - lw) / 2, WIFI.y + (WIFI.h - TH) / 2 - 3, lw, TH + 6, c.bg)
    inside(WIFI.x, WIFI.y, WIFI.w, WIFI.h, "WIFI/BT")
    -- its coax socket and the line to the antenna
    local ANT = { x = WIFI.x + WIFI.w + 22, y = WIFI.y + 40, w = 30, h = 30 }
    hline(WIFI.x + WIFI.w, ANT.x, ANT.y + 15, c.accent2, 2)
    box(ANT.x, ANT.y, ANT.w, ANT.h, c.bg); frame(ANT.x, ANT.y, ANT.w, ANT.h, c.muted, 2)
    disc(ANT.x + 15, ANT.y + 15, 7, c.accent2)
    over(ANT.x + 15, ANT.y, "ANT")
    -- the battery connector: two pads on top (+ red, - teal), its name on the body
    box(BATT.x + 15, BATT.y - 7, 10, 7, POWER); box(BATT.x + 35, BATT.y - 7, 10, 7, c.accent2)
    box(BATT.x, BATT.y, BATT.w, BATT.h, c.bg); frame(BATT.x, BATT.y, BATT.w, BATT.h, c.muted, 2)
    inside(BATT.x, BATT.y, BATT.w, BATT.h, "BATT")
    -- USB-C: pins along the top, its name in the shell
    for i = 0, 12 do box(USB.x + 10 + i * ((USB.w - 24) / 12), USB.y - 6, 4, 6, c.muted) end
    box(USB.x, USB.y, USB.w, USB.h, c.bg); frame(USB.x, USB.y, USB.w, USB.h, c.muted, 2)
    inside(USB.x, USB.y, USB.w, USB.h, "USB-C")
    -- the power button, named underneath
    box(PWR.x, PWR.y, PWR.w, PWR.h, c.bg); frame(PWR.x, PWR.y, PWR.w, PWR.h, c.muted, 2); disc(PWR.x + 20, PWR.y + 20, 9, c.line)
    under(PWR.x + 20, PWR.y + PWR.h, "PWR")
    -- decoupling beside the memory and the processor, rows of tiny parts
    for k = 0, 3 do passive(SOC.x + 10 + k * 22, SOC.y + SOC.h + 8, k % 2 == 1) end
    for k = 0, 3 do passive(DDR.x + 10 + k * 28, DDR.y + DDR.h + 7, k % 2 == 0) end
    for k = 0, 3 do passive(EMMC.x + 10 + k * 28, EMMC.y + EMMC.h + 7, k % 2 == 1) end
    -- test points, named underneath
    for _i, p in ipairs({ { 640, 262 }, { 670, 262 }, { 700, 262 }, { 640, 292 }, { 670, 292 } }) do
        disc(p[1], p[2], 6, c.bg); ring(p[1], p[2], 6, c.accent2, 2)
    end
    under(670, 300, "TP1-5")
    -- the board's own mark, along the bottom right
    if labels then
        local mark = "MAIN PCB  REV A"
        Text.draw(bb, ox + R(1040 - textWidth(mark)), oy + R(PLAN_H - 20 - TH), "micro", mark, c.muted)
    end
end

return Mainboard
