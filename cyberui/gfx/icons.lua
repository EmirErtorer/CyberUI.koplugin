-- Line icons from the plugin's icons folder, drawn in any theme colour. Each
-- icon is rasterised once per size into a coverage mask and reused. An icon
-- may have an accent layer (<name>.accent.svg: status lights and the like)
-- drawn on top in a second colour. Icons the device already has can be used
-- too: "reader:<file>" is one in KOReader's data icons folder, "ko:<file>" one
-- of KOReader's stock set.

local Blitbuffer = require("ffi/blitbuffer")
local ffi = require("ffi")
local DataStorage = require("datastorage")
local RenderImage = require("ui/renderimage")
local Color = require("cyberui/theme/color")
local Paths = require("cyberui/paths")
local lfs = require("libs/libkoreader-lfs")
local _ = require("cyberui/gettext")

local Icons = {}

local masks = {}   -- "name|size" -> BB8 coverage mask, or false when it failed

-- The folder for icons the reader adds (they survive CyberUI updates).
function Icons.userDir()
    return DataStorage:getSettingsDir() .. "/cyberui-icons"
end

-- Where the device's own icons live, by the prefix an id carries (KOReader's
-- stock paths are relative to its folder).
local DEVICE_DIRS = {
    reader = function() return DataStorage:getDataDir() .. "/icons" end,
    ko = function() return "resources/icons/mdlight" end,
}

-- KOReader's state icons (rotations, Wi-Fi strengths...) are variants, not
-- icons to put on a button.
local KO_SKIP = { "^rotation%.", "^direction%.", "^dogear", "^cre%.render", "^wifi%.open%.", "^wifi%.secure%.",
    "^position%.marker", "%.alpha$", "%.rtl$", "^icon%-not%-found", "^texture%-box" }

-- The icon's source and file name when it is a device icon ("ko:menu.svg").
local function deviceIcon(name)
    local kind, file = name:match("^(%a+):([^/]+)$")
    if kind and DEVICE_DIRS[kind] then return kind, file end
end

-- Is this one of the plugin's or the reader's own icons (a bare name)?
local function isBare(name)
    return not name:find("/", 1, true) and not deviceIcon(name)
end

-- The file of an icon: a path as it is, a device icon in its folder (the
-- plugin's tools icon when it has gone), else the reader's own icon of that
-- name, else the plugin's.
local function fileOf(name)
    if name:find("/", 1, true) then return name end
    local kind, file = deviceIcon(name)
    if kind then
        local path = DEVICE_DIRS[kind]() .. "/" .. file
        if lfs.attributes(path, "mode") == "file" then return path end
        return Paths.file("icons/tools.svg")
    end
    local own = Icons.userDir() .. "/" .. name .. ".svg"
    if lfs.attributes(own, "mode") == "file" then return own end
    return Paths.file("icons/" .. name .. ".svg")
end

-- Rasterise an icon file into a mask: 255 where its lines are, 0 elsewhere;
-- false when there is no such file. A name with a slash is a file path
-- (another plugin's own icon).
local function build(name, size)
    local file = fileOf(name)
    if lfs.attributes(file, "mode") ~= "file" then return false end
    local raw, straight = RenderImage:renderSVGImageFile(file, size, size)
    if not raw then return false end
    local w, h = raw:getWidth(), raw:getHeight()
    local mask = Blitbuffer.new(w, h, Blitbuffer.TYPE_BB8)
    mask:fill(Blitbuffer.COLOR_WHITE)
    if straight then mask:alphablitFrom(raw, 0, 0, 0, 0, w, h)
    else mask:pmulalphablitFrom(raw, 0, 0, 0, 0, w, h) end
    raw:free()
    -- flip the pixels themselves: bb:invert() only sets a flag that the fast
    -- C blitter ignores, which left icons blank in night mode
    mask:invertRect(0, 0, w, h)
    return mask
end

-- Masks are also kept on disk, so a start draws its icons without loading
-- the SVG renderer: one file per icon file and size, starting with a line
-- naming the icon file's size and age, the size drawn at and the mask's
-- width and height, then the mask's bytes.
local disk_dir   -- the folder of the kept masks (made on first use)

-- The folder of the kept masks.
local function diskDir()
    if not disk_dir then
        disk_dir = DataStorage:getDataDir() .. "/cache/cyberui-icons"
        if lfs.attributes(disk_dir, "mode") ~= "directory" then lfs.mkdir(disk_dir) end
    end
    return disk_dir
end

-- The kept mask's file and the line it must start with, or nil.
local function diskEntry(name, size)
    local file = fileOf(name)
    local attr = lfs.attributes(file)
    if not attr or attr.mode ~= "file" then return nil end
    local id = file:gsub("[^%w%.%-]", "_")
    if #id > 180 then id = id:sub(-180) end
    return diskDir() .. "/" .. id .. "-" .. size .. ".mask", attr.size .. ":" .. attr.modification .. ":" .. size
end

-- The masks a start draws are kept together in one more file too, read at
-- once instead of one file each (see Icons.packStart): after a first line,
-- each mask as "file\tstamp\twidth\theight" on a line, then its bytes.
local PACK_HEAD = "CYBERUI-MASKS 1"
local PACK = "start.pack"
local pack      -- { data, at = { file -> { stamp, w, h, from } } }, false when none
local used = {} -- the masks drawn this start: { key, file, stamp }, until packed

-- Read the pack, or false when there is none or it is not one.
local function readPack()
    local f = io.open(diskDir() .. "/" .. PACK, "rb")
    if not f then return false end
    local data = f:read("*a")
    f:close()
    if not data or data:sub(1, #PACK_HEAD + 1) ~= PACK_HEAD .. "\n" then return false end
    local at, pos = {}, #PACK_HEAD + 2
    while pos <= #data do
        local nl = data:find("\n", pos, true)
        if not nl then return false end
        local file, stamp, w, h = data:sub(pos, nl - 1):match("^([^\t]+)\t([^\t]+)\t(%d+)\t(%d+)$")
        w, h = tonumber(w), tonumber(h)
        if not (w and h) or nl + w * h > #data then return false end
        at[file] = { stamp = stamp, w = w, h = h, from = nl }
        pos = nl + w * h + 1
    end
    return { data = data, at = at }
end

-- A mask from its bytes at `bytes` (w x h, row after row).
local function fromBytes(bytes, w, h)
    local m = Blitbuffer.new(w, h, Blitbuffer.TYPE_BB8)
    local dst = ffi.cast("uint8_t*", m.data)
    if m.stride == w then
        ffi.copy(dst, bytes, w * h)
    else
        for y = 0, h - 1 do ffi.copy(dst + y * m.stride, bytes + y * w, w) end
    end
    return m
end

-- The mask kept in the pack for `file` when it matches `stamp`, or nil.
local function fromPack(file, stamp)
    if pack == nil then pack = readPack() end
    local e = pack and pack.at[file]
    if not e or e.stamp ~= stamp then return nil end
    return fromBytes(ffi.cast("const uint8_t*", pack.data) + e.from, e.w, e.h)
end

-- A kept mask that still matches its icon file, or nil.
local function readKept(path, stamp)
    local f = io.open(path, "rb")
    if not f then return nil end
    local line = f:read("*l")
    local kept_stamp, w, h = (line or ""):match("^(%S+) (%d+) (%d+)$")
    w, h = tonumber(w), tonumber(h)
    local m
    if kept_stamp == stamp and w and h then
        local bytes = f:read(w * h)
        if bytes and #bytes == w * h then m = fromBytes(ffi.cast("const uint8_t*", bytes), w, h) end
    end
    f:close()
    return m
end

-- A mask's bytes, row after row.
local function bytesOf(m)
    local w, h = m:getWidth(), m:getHeight()
    local src = ffi.cast("uint8_t*", m.data)
    if m.stride == w then return ffi.string(src, w * h) end
    local rows = {}
    for y = 0, h - 1 do rows[y + 1] = ffi.string(src + y * m.stride, w) end
    return table.concat(rows)
end

-- Keep a mask on disk (nothing happens when it cannot be written).
local function writeKept(path, stamp, m)
    local f = io.open(path, "wb")
    if not f then return end
    f:write(stamp, " ", m:getWidth(), " ", m:getHeight(), "\n", bytesOf(m))
    f:close()
end

-- The cached mask of an icon file at a size.
local function mask(name, size)
    local key = name .. "|" .. size
    local m = masks[key]
    if m == nil then
        local path, stamp = diskEntry(name, size)
        m = path and (fromPack(path, stamp) or readKept(path, stamp))
        if not m then
            m = build(name, size)
            if m and path then writeKept(path, stamp, m) end
        end
        masks[key] = m
        if m and used then used[#used + 1] = { key, path, stamp } end
    end
    return m
end

-- Blit a mask in a colour.
local function blit(bb, m, x, y, color)
    local w, h = m:getWidth(), m:getHeight()
    if Color.isRGB(color) then
        bb:colorblitFromRGB32(m, x, y, 0, 0, w, h, color)
    else
        bb:colorblitFrom(m, x, y, 0, 0, w, h, color)
    end
end

-- The sorted names of the SVG files in a folder (none when it is missing).
local function svgFiles(dir)
    local out = {}
    local ok, iter, state = pcall(lfs.dir, dir)
    if ok then
        for file in iter, state do
            if file:match("^[^.].*%.svg$") then out[#out + 1] = file end
        end
    end
    table.sort(out)
    return out
end

-- The names of the icons that can be chosen from a source: "set" (the
-- default: the plugin's and the reader's cyberui-icons, by bare name),
-- "reader" or "ko" (the device's). The accent layers are part of their icon.
function Icons.list(source)
    local out = {}
    if DEVICE_DIRS[source] then
        for _i, file in ipairs(svgFiles(DEVICE_DIRS[source]())) do
            local stem = file:match("^(.+)%.svg$")
            local skip = false
            for _j, pat in ipairs(source == "ko" and KO_SKIP or {}) do skip = skip or stem:match(pat) ~= nil end
            if not skip then out[#out + 1] = source .. ":" .. file end
        end
        return out
    end
    local seen = {}
    for _i, dir in ipairs({ Paths.file("icons"), Icons.userDir() }) do
        for _j, file in ipairs(svgFiles(dir)) do
            local name = file:match("^(.+)%.svg$")
            if not name:find(".accent", 1, true) and not seen[name] then
                seen[name] = true
                out[#out + 1] = name
            end
        end
    end
    table.sort(out)
    return out
end

-- The sources an icon can come from, { id, label, names } for each one that
-- has any icon.
function Icons.sources()
    local out = {}
    for _i, src in ipairs({ { id = "set", label = _("CYBERUI") }, { id = "reader", label = _("READER") }, { id = "ko", label = _("KOREADER") } }) do
        src.names = Icons.list(src.id)
        if #src.names > 0 then out[#out + 1] = src end
    end
    return out
end

-- The source id an icon name belongs to.
function Icons.sourceOf(name)
    return deviceIcon(name or "") or "set"
end

-- Draw icon `name` at size x size with its top-left at (x, y), its accent
-- layer (if it has one) in `accent` (`color` when not given).
function Icons.draw(bb, name, x, y, size, color, accent)
    local m = mask(name, size)
    if not m then return end
    blit(bb, m, x, y, color)
    local a = isBare(name) and mask(name .. ".accent", size)
    if a then blit(bb, a, x, y, accent or color) end
end

-- The start is over: keep the masks it drew together for the next one
-- (the file is written again only when they changed), and let the pack go.
function Icons.packStart()
    if not used then return end
    local list, old = used, pack
    used, pack = nil, false
    local same = old and true or false
    local parts, n = { PACK_HEAD .. "\n" }, 0
    for _i, u in ipairs(list) do
        local m = masks[u[1]]
        if m and u[2] then
            local e = old and old.at[u[2]]
            same = same and e ~= nil and e.stamp == u[3]
            n = n + 1
            parts[#parts + 1] = u[2] .. "\t" .. u[3] .. "\t" .. m:getWidth() .. "\t" .. m:getHeight() .. "\n" .. bytesOf(m)
        end
    end
    if same then
        local had = 0
        for _k in pairs(old.at) do had = had + 1 end
        same = had == n
    end
    if same or n == 0 then return end
    local file = diskDir() .. "/" .. PACK
    local f = io.open(file .. ".new", "wb")
    if not f then return end
    f:write(table.concat(parts))
    f:close()
    os.rename(file .. ".new", file)
end

-- Free every mask (when CyberUI is closed for good).
function Icons.free()
    for k, m in pairs(masks) do
        if m then m:free() end
        masks[k] = nil
    end
end

return Icons
