-- Installing a downloaded plugin zip: it must match the size and SHA-256
-- digest GitHub lists, every entry must sit inside the plugin's own folder
-- (plain files and folders, within limits), every Lua file must load, and
-- main.lua and _meta.lua must be there. It is unpacked into a staging
-- folder beside the plugins and only then moved into place.

local lfs = require("libs/libkoreader-lfs")

local Unpack = {}

Unpack.MAX_UNPACKED = 96 * 1024 * 1024
Unpack.MAX_ENTRIES = 4096

-- Remove a file or a folder and everything in it.
function Unpack.removeTree(path)
    local mode = lfs.symlinkattributes(path, "mode")
    if not mode then return true end
    if mode ~= "directory" then return os.remove(path) end
    for name in lfs.dir(path) do
        if name ~= "." and name ~= ".." then
            local ok, err = Unpack.removeTree(path .. "/" .. name)
            if not ok then return nil, err end
        end
    end
    return lfs.rmdir(path)
end

-- The SHA-256 (hex) and size of a file.
function Unpack.digest(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local hash = require("ffi/sha2").sha256()
    local size = 0
    while true do
        local chunk = f:read(65536)
        if not chunk then break end
        size = size + #chunk
        hash(chunk)
    end
    f:close()
    return hash(), size
end

-- The path of a zip entry inside the plugin folder `folder` ("" for the
-- folder itself), or nil when the entry is not safe to unpack.
function Unpack.entry(path, mode, folder)
    if type(path) ~= "string" or (mode ~= "file" and mode ~= "directory")
            or path:find("[%c\\]") or path:sub(1, 1) == "/" then return nil end
    path = path:gsub("/$", "")
    if path == folder then return mode == "directory" and "" or nil end
    local rel = path:match("^" .. folder:gsub("%p", "%%%0") .. "/(.+)$")
    if not rel or rel:find("//", 1, true) then return nil end
    for part in rel:gmatch("[^/]+") do
        if part == "." or part == ".." then return nil end
    end
    return rel
end

-- Make a folder unless it exists.
local function mkdir(path)
    return lfs.symlinkattributes(path, "mode") == "directory" or lfs.mkdir(path)
end

-- Check `zip` against `release` and unpack it into `stage`. Returns true, or
-- nil and why (nothing is left in `stage` then).
local function prepare(zip, stage, release, folder)
    local sum, size = Unpack.digest(zip)
    if not sum then return nil, "the download could not be read" end
    if size ~= release.size or sum:lower() ~= release.digest then
        return nil, "the download does not match the one GitHub lists"
    end
    Unpack.removeTree(stage)
    if not mkdir(stage) then return nil, "no staging folder" end
    local reader = require("ffi/archiver").Reader:new()
    if not reader:open(zip) then Unpack.removeTree(stage); return nil, "the zip could not be opened" end
    local ok, failure = pcall(function()
        local seen, bytes, count = {}, 0, 0
        for entry in reader:iterate() do
            local rel = Unpack.entry(entry.path, entry.mode, folder)
            assert(rel ~= nil, "an unsafe entry in the zip")
            assert(not seen[rel], "a repeated entry in the zip")
            seen[rel] = entry.mode
            count = count + 1
            assert(count <= Unpack.MAX_ENTRIES, "too many entries in the zip")
            local n = tonumber(entry.size) or 0
            bytes = bytes + n
            assert(bytes <= Unpack.MAX_UNPACKED, "the zip unpacks too large")
            if rel ~= "" then
                local dir = stage
                for part in rel:gmatch("([^/]+)/") do
                    dir = dir .. "/" .. part
                    assert(mkdir(dir), "a folder could not be made")
                end
                if entry.mode == "directory" then
                    assert(mkdir(stage .. "/" .. rel), "a folder could not be made")
                else
                    -- written by CyberUI itself to the checked path: nothing
                    -- in the zip decides where a file goes or who may run it
                    local data = reader:extractToMemory(entry.path)
                    assert(data and #data == n, "a file could not be unpacked")
                    local out = assert(io.open(stage .. "/" .. rel, "wb"), "a file could not be written")
                    local wrote = out:write(data)
                    out:close()
                    assert(wrote, "a file could not be written")
                    if rel:match("%.lua$") then assert(loadfile(stage .. "/" .. rel), "a broken file in the zip") end
                end
            end
        end
        assert(not reader.err, "the zip is damaged")
        assert(seen["main.lua"] == "file" and seen["_meta.lua"] == "file", "the zip is not a whole plugin")
    end)
    reader:close()
    if not ok then
        Unpack.removeTree(stage)
        return nil, (tostring(failure):gsub("^.-:%d+: ", ""))
    end
    return true
end

-- Install `zip` (checked against `release`) as `plugins_dir/folder`.
-- Returns true, or nil and why.
function Unpack.install(zip, release, folder, plugins_dir)
    local target = plugins_dir .. "/" .. folder
    if lfs.symlinkattributes(target) then return nil, "it is already installed" end
    local stage = plugins_dir .. "/.cyberui-install-" .. folder
    local ok, err = prepare(zip, stage, release, folder)
    if not ok then return nil, err end
    local moved, merr = os.rename(stage, target)
    if not moved then
        Unpack.removeTree(stage)
        return nil, merr or "it could not be put in place"
    end
    return true
end

return Unpack
