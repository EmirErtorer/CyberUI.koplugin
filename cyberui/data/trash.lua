-- The trash: deleted books and folders wait in KOReader's data folder for
-- KEEP_DAYS days, with their reading data, and can be put back where they
-- were, back in their collections and history. Older ones go for good. Each
-- item keeps its own name inside a folder of its own, as KOReader names a
-- book's reading data after the book's file name.

local DataStorage = require("datastorage")
local DocSettings = require("docsettings")
local LuaSettings = require("luasettings")
local ReadCollection = require("readcollection")
local ReadHistory = require("readhistory")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local Collections = require("cyberui/data/collections")
local Files = require("cyberui/data/files")
local Library = require("cyberui/data/library")
local _ = require("gettext")

local Trash = {}

Trash.KEEP_DAYS = 30

local index   -- LuaSettings with { items = { id = item } }

-- The folder trashed things are kept in.
function Trash.dir()
    local dir = DataStorage:getDataDir() .. "/cyberui-trash"
    if not Files.isDir(dir) then lfs.mkdir(dir) end
    return dir
end

-- The list of what is in the trash, kept next to KOReader's settings.
local function store()
    if not index then index = LuaSettings:open(DataStorage:getSettingsDir() .. "/cyberui_trash.lua") end
    return index
end

-- Every trashed item, newest first: { id, name, origin, time, dir, collections }.
function Trash.list()
    local items = store():readSetting("items") or {}
    local out = {}
    for _id, it in pairs(items) do out[#out + 1] = it end
    table.sort(out, function(a, b) return a.time > b.time end)
    return out
end

-- How many things are in the trash.
function Trash.count()
    return #Trash.list()
end

-- Save the item list.
local function save(items)
    store():saveSetting("items", items)
    store():flush()
end

-- Put `path` in the trash. Returns true, or nil and why.
function Trash.put(path)
    local items = store():readSetting("items") or {}
    local now = os.time()
    local id = now .. "-" .. math.random(1000, 9999)
    local is_dir = Files.isDir(path)
    local held = is_dir and {} or Collections.holding(path)
    local hist = ReadHistory:getIndexByFile(ffiUtil.realpath(path) or path)
    local opened = hist and ReadHistory.hist[hist].time or nil
    local slot = Trash.dir() .. "/" .. id
    if not lfs.mkdir(slot) then return nil, _("The trash could not be written to.") end
    local to = slot .. "/" .. Files.name(path)
    local ok, err = Files.move(path, to)
    if not ok then lfs.rmdir(slot); return nil, err end
    to = ffiUtil.realpath(to) or to   -- as history and collections now hold it
    -- out of the history and collections while it waits (put back on restore);
    -- the history entries are dropped by hand, as KOReader's folderDeleted
    -- would also remove reading data kept outside the books' folders
    if is_dir then
        for i = #ReadHistory.hist, 1, -1 do
            local file = ReadHistory.hist[i].file
            if file and file:sub(1, #to + 1) == to .. "/" then ReadHistory:removeItem(ReadHistory.hist[i], i, true) end
        end
        ReadHistory:_flush()
        ReadCollection:removeItemsByPath(to)
    else
        ReadHistory:removeItemByPath(to)
        ReadCollection:removeItem(to)
    end
    items[id] = { id = id, name = Files.name(path), origin = path, time = now, dir = is_dir,
        collections = held, opened = opened }
    save(items)
    return true
end

-- Put a trashed item back where it was (or beside it when that name is
-- taken again). Returns the path it went to, or nil and why.
function Trash.restore(id)
    local items = store():readSetting("items") or {}
    local it = items[id]
    if not it then return nil, _("It is not in the trash any more.") end
    local parent = Files.parent(it.origin)
    if not Files.isDir(parent) then return nil, _("Its folder is gone. Restore that first.") end
    local to = it.origin
    local n = 1
    while Files.exists(to) do
        n = n + 1
        local base, ext = it.name:match("^(.-)(%.[^.]*)$")
        if not base or it.dir then base, ext = it.name, "" end
        to = string.format("%s/%s (%d)%s", parent, base, n, ext)
    end
    local slot = Trash.dir() .. "/" .. id
    local ok, err = Files.move(slot .. "/" .. it.name, to)
    if not ok then return nil, err end
    lfs.rmdir(slot)
    if not it.dir then
        for _i, name in ipairs(it.collections or {}) do
            if ReadCollection.coll[name] then Collections.toggle(to, name) end
        end
        if it.opened then ReadHistory:addItem(to, it.opened) end
    end
    items[id] = nil
    save(items)
    return to
end

-- Delete a trashed item for good.
function Trash.purge(id)
    local items = store():readSetting("items") or {}
    local it = items[id]
    if not it then return end
    local slot = Trash.dir() .. "/" .. id
    local path = slot .. "/" .. it.name
    if not it.dir and Files.exists(path) then
        DocSettings.updateLocation(path)   -- removes reading data kept elsewhere too
    end
    ffiUtil.purgeDir(slot)
    items[id] = nil
    save(items)
    Library.reset()
end

-- Delete everything in the trash for good.
function Trash.empty()
    for _i, it in ipairs(Trash.list()) do Trash.purge(it.id) end
end

-- Delete what has waited longer than KEEP_DAYS.
function Trash.sweep()
    local limit = os.time() - Trash.KEEP_DAYS * 86400
    for _i, it in ipairs(Trash.list()) do
        if it.time < limit then Trash.purge(it.id) end
    end
end

return Trash
