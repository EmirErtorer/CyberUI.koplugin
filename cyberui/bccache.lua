-- CyberUI's own modules kept compiled. KOReader reads every Lua file from its
-- source at each start, and parsing the modules CyberUI's home needs is a good
-- part of its start on an e-reader. The first time a module is loaded after an
-- install or an update it is read from source as usual and its compiled form
-- saved in KOReader's cache folder; later starts load that copy. Each copy
-- starts with a line naming the source it was made from (size, age) and the
-- Lua that made it, and is used only while all three still match; anything
-- else is read from source again.
--
-- The modules a start loads are also kept together in one pack file, made a
-- few seconds after the first screen, so the next start reads one file
-- instead of one per module (each module in it is still checked against its
-- source the same way). The pack is let go once the start is over.

local lfs = require("libs/libkoreader-lfs")

local BcCache = {}

local PREFIX = "cyberui/"

local root      -- the plugin folder (the sources)
local dir       -- the folder of the compiled copies

local PACK = "start.pack"
local PACK_HEAD = "CYBERUI-PACK 1"
local pack      -- { data, at = name -> { stamp, from, to } }: the pack read at install, until packed again
local started   -- the modules loaded so far this start, in order: { name, stamp }, until packed

-- The line a copy must start with: the source's size and age, and the Lua.
local function stampOf(attr)
    return attr.size .. ":" .. attr.modification .. ":" .. (jit and jit.version or "lua")
end

-- The file a module's copy is kept in (one folder, no subfolders).
local function copyOf(name)
    return dir .. "/" .. name:gsub("/", "~") .. ".bc"
end

-- The bytes of a module's copy (without its stamp line) when it matches `stamp`.
local function copyBytes(copy, stamp)
    local f = io.open(copy, "rb")
    if not f then return nil end
    local line = f:read("*l")
    local bytes = line == stamp and f:read("*a") or nil
    f:close()
    return bytes
end

-- The module's chunk from its copy, when the copy matches `stamp`.
local function fromCopy(copy, stamp)
    local bytes = copyBytes(copy, stamp)
    return bytes and loadstring(bytes) or nil
end

-- Read the pack file: { data, at }, or nil when there is none or it is not one.
local function readPack()
    local f = io.open(dir .. "/" .. PACK, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    if not data or data:sub(1, #PACK_HEAD + 1) ~= PACK_HEAD .. "\n" then return nil end
    local at, pos = {}, #PACK_HEAD + 2
    while pos <= #data do
        local nl = data:find("\n", pos, true)
        if not nl then return nil end
        local name, stamp, len = data:sub(pos, nl - 1):match("^([^\t]+)\t([^\t]+)\t(%d+)$")
        len = tonumber(len)
        if not len or nl + len > #data then return nil end
        at[name] = { stamp = stamp, from = nl + 1, to = nl + len }
        pos = nl + len + 1
    end
    return { data = data, at = at }
end

-- The module's chunk from the pack, when its entry matches `stamp`.
local function fromPack(name, stamp)
    local e = pack and pack.at[name]
    if not e or e.stamp ~= stamp then return nil end
    return loadstring(pack.data:sub(e.from, e.to))
end

-- Save the compiled form of `chunk` under `stamp`.
local function save(copy, stamp, chunk)
    local ok, bytes = pcall(string.dump, chunk)
    if not ok then return end
    local f = io.open(copy, "wb")
    if not f then return end
    f:write(stamp, "\n", bytes)
    f:close()
end

-- Load module `name` from its copy, or from source (then saving a copy).
-- Returns the module's chunk, or nil to leave it to Lua's own loaders.
local function loadModule(name)
    if name:sub(1, #PREFIX) ~= PREFIX then return nil end
    local src = root .. "/" .. name .. ".lua"
    local attr = lfs.attributes(src)
    if not attr or attr.mode ~= "file" then return nil end
    local stamp = stampOf(attr)
    if started then started[#started + 1] = { name, stamp } end
    local chunk = fromPack(name, stamp)
    if chunk then return chunk end
    local copy = copyOf(name)
    chunk = fromCopy(copy, stamp)
    if chunk then return chunk end
    local err
    chunk, err = loadfile(src)
    if not chunk then error(err, 0) end
    save(copy, stamp, chunk)
    return chunk
end

-- The start is over: keep the modules it loaded in the pack for the next
-- one (the pack is written again only when they changed), and let go of the
-- pack read at this start.
function BcCache.packStart()
    if not started then return end
    local list = started
    started = nil
    local old = pack
    pack = nil
    local same = old ~= nil
    local parts = { PACK_HEAD .. "\n" }
    for _i, m in ipairs(list) do
        local name, stamp = m[1], m[2]
        local e = old and old.at[name]
        local bytes
        if e and e.stamp == stamp then
            bytes = old.data:sub(e.from, e.to)
        else
            same = false
            bytes = copyBytes(copyOf(name), stamp)
        end
        if bytes then parts[#parts + 1] = name .. "\t" .. stamp .. "\t" .. #bytes .. "\n" .. bytes end
    end
    if same then
        local n = 0
        for _k in pairs(old.at) do n = n + 1 end
        same = n == #list
    end
    if same then return end
    local tmp = dir .. "/" .. PACK .. ".new"
    local f = io.open(tmp, "wb")
    if not f then return end
    f:write(table.concat(parts))
    f:close()
    os.rename(tmp, dir .. "/" .. PACK)
end

-- Put the loader in front of Lua's own, for modules under `plugin_root`,
-- keeping the copies in `cache_dir`. Does nothing when the folder cannot be made.
function BcCache.install(plugin_root, cache_dir)
    if root then return end
    if lfs.attributes(cache_dir, "mode") ~= "directory" and not lfs.mkdir(cache_dir) then return end
    root, dir = plugin_root, cache_dir
    pack, started = readPack(), {}
    table.insert(_G.package.loaders, 2, function(name)
        local ok, chunk = pcall(loadModule, name)
        if ok then return chunk end
        return nil
    end)
end

return BcCache
