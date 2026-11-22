-- CyberUI's own modules kept compiled. KOReader reads every Lua file from its
-- source at each start, and parsing the modules CyberUI's home needs is a good
-- part of its start on an e-reader. The first time a module is loaded after an
-- install or an update it is read from source as usual and its compiled form
-- saved in KOReader's cache folder; later starts load that copy. Each copy
-- starts with a line naming the source it was made from (size, age) and the
-- Lua that made it, and is used only while all three still match; anything
-- else is read from source again.

local lfs = require("libs/libkoreader-lfs")

local BcCache = {}

local PREFIX = "cyberui/"

local root      -- the plugin folder (the sources)
local dir       -- the folder of the compiled copies

-- The line a copy must start with: the source's size and age, and the Lua.
local function stampOf(attr)
    return attr.size .. ":" .. attr.modification .. ":" .. (jit and jit.version or "lua")
end

-- The file a module's copy is kept in (one folder, no subfolders).
local function copyOf(name)
    return dir .. "/" .. name:gsub("/", "~") .. ".bc"
end

-- The module's chunk from its copy, when the copy matches `stamp`.
local function fromCopy(copy, stamp)
    local f = io.open(copy, "rb")
    if not f then return nil end
    local line = f:read("*l")
    local bytes = line == stamp and f:read("*a")
    f:close()
    return bytes and loadstring(bytes) or nil
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
    local copy = copyOf(name)
    local chunk = fromCopy(copy, stamp)
    if chunk then return chunk end
    local err
    chunk, err = loadfile(src)
    if not chunk then error(err, 0) end
    save(copy, stamp, chunk)
    return chunk
end

-- Put the loader in front of Lua's own, for modules under `plugin_root`,
-- keeping the copies in `cache_dir`. Does nothing when the folder cannot be made.
function BcCache.install(plugin_root, cache_dir)
    if root then return end
    if lfs.attributes(cache_dir, "mode") ~= "directory" and not lfs.mkdir(cache_dir) then return end
    root, dir = plugin_root, cache_dir
    table.insert(_G.package.loaders, 2, function(name)
        local ok, chunk = pcall(loadModule, name)
        if ok then return chunk end
        return nil
    end)
end

return BcCache
