-- Book covers scaled to the size they are shown at, from CoverBrowser's cache.
-- Scaled covers are kept in a small most-recently-used cache so screens repaint
-- without decoding or scaling again.

local RenderImage = require("ui/renderimage")

local Covers = {}

local MAX = 36
local cache = {}   -- key -> { bb, used }
local count = 0
local tick = 0

-- CoverBrowser's book info cache, or nil.
local function bim()
    local ok, m = pcall(require, "bookinfomanager")
    return ok and m or nil
end

-- Drop the least recently used cover.
local function evict()
    local oldest, oldest_key
    for k, e in pairs(cache) do
        if not oldest or e.used < oldest then oldest, oldest_key = e.used, k end
    end
    if oldest_key then
        if cache[oldest_key].bb then cache[oldest_key].bb:free() end
        cache[oldest_key] = nil
        count = count - 1
    end
end

-- The cover of `path` scaled to fit w x h, or nil when there is none.
function Covers.get(path, w, h)
    local key = path .. "|" .. w .. "|" .. h
    tick = tick + 1
    local e = cache[key]
    if e then e.used = tick; return e.bb end
    local m = bim()
    local bi = m and m:getBookInfo(path, true)
    local bb
    if bi and bi.cover_bb then
        local cw, ch = bi.cover_bb:getWidth(), bi.cover_bb:getHeight()
        local scale = math.min(w / cw, h / ch)
        bb = RenderImage:scaleBlitBuffer(bi.cover_bb, math.max(1, math.floor(cw * scale)), math.max(1, math.floor(ch * scale)), true)
    end
    if count >= MAX then evict() end
    cache[key] = { bb = bb or false, used = tick }
    count = count + 1
    return bb
end

-- Forget the covers of one book, or all of them.
function Covers.forget(path)
    for k, e in pairs(cache) do
        if not path or k:sub(1, #path + 1) == path .. "|" then
            if e.bb then e.bb:free() end
            cache[k] = nil
            count = count - 1
        end
    end
end

return Covers
