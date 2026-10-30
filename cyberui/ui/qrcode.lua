-- A QR code for a text, black on a white square with the quiet border a phone
-- needs, drawn the same in every colour scheme so it always scans. KOReader
-- makes the code itself, so nothing here needs a network.

local Blitbuffer = require("ffi/blitbuffer")
local Element = require("cyberui/ui/element")
local Paint = require("cyberui/gfx/paint")
local Theme = require("cyberui/theme")

local QRCode = Element:extend({ size = 180 })

local QUIET = 4   -- modules of white round the code

-- The code's modules (a grid, true where dark), or nil when it could not be made.
local function modules(text)
    local ok, grid = require("ffi/qrencode").qrcode(text)
    if not ok then return nil end
    return grid
end

-- Make the code once.
function QRCode:init()
    self.grid = modules(self.text)
end

-- The size of one module in pixels: whole pixels, so the edges stay sharp.
function QRCode:module()
    local n = self.grid and #self.grid or 1
    return math.max(2, math.floor(Theme.px(self.size) / (n + 2 * QUIET)))
end

-- Square, a whole number of modules wide.
function QRCode:naturalWidth()
    if not self.grid then return 0 end
    return (#self.grid + 2 * QUIET) * self:module()
end
function QRCode:naturalHeight() return self:naturalWidth() end

-- Draw the white square and the dark modules.
function QRCode:draw(bb, x, y)
    if not self.grid then return end
    local m = self:module()
    Paint.fill(bb, x, y, self.w, self.h, Blitbuffer.COLOR_WHITE)
    for gx, col in ipairs(self.grid) do
        for gy, v in ipairs(col) do
            if v >= 0 then Paint.fill(bb, x + (gx - 1 + QUIET) * m, y + (gy - 1 + QUIET) * m, m, m, Blitbuffer.COLOR_BLACK) end
        end
    end
end

return QRCode
