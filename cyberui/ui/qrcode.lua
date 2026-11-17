-- A QR code for a text, black on a white square with the quiet border a phone
-- needs, drawn the same in every colour scheme so it always scans. KOReader
-- makes the code itself, so nothing here needs a network.

local Blitbuffer = require("ffi/blitbuffer")
local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Theme = require("cyberui/theme")

local QRCode = Element:extend({ size = 180 })

local QUIET = 4   -- modules of white round the code

-- The code's modules: { n (modules a side), dark(x, y) }, or nil when it could
-- not be made. KOReader's encoder gave a table of columns until 2026, and now
-- gives a flat array and its side (ok, matrix, size); both are read here.
local function modules(text)
    local called, ok, grid, size = pcall(require("ffi/qrencode").qrcode, text)
    if not (called and ok and grid) then return nil end
    if type(grid) == "table" then
        return { n = #grid, dark = function(x, y) return grid[x][y] >= 0 end }
    end
    if type(size) ~= "number" or size < 1 then return nil end
    return { n = size, dark = function(x, y) return grid[(y - 1) * size + x] >= 0 end }
end

-- Make the code once.
function QRCode:init()
    self.code = modules(self.text)
end

-- The size of one module in pixels: whole pixels, so the edges stay sharp.
function QRCode:module()
    local n = self.code and self.code.n or 1
    return math.max(2, math.floor(Theme.px(self.size) / (n + 2 * QUIET)))
end

-- Square, a whole number of modules wide.
function QRCode:naturalWidth()
    if not self.code then return 0 end
    return (self.code.n + 2 * QUIET) * self:module()
end
function QRCode:naturalHeight() return self:naturalWidth() end

-- Draw the white square and the dark modules.
function QRCode:draw(bb, x, y)
    local code = self.code
    if not code then return end
    local m = self:module()
    Paint.fill(bb, x, y, self.w, self.h, Blitbuffer.COLOR_WHITE)
    for gx = 1, code.n do
        for gy = 1, code.n do
            if code.dark(gx, gy) then
                Paint.fill(bb, x + (gx - 1 + QUIET) * m, y + (gy - 1 + QUIET) * m, m, m, Blitbuffer.COLOR_BLACK)
            end
        end
    end
end

return QRCode
