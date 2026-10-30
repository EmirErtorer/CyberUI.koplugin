-- Intel shards: every highlight in the reader's books, as fragments to browse.
-- They live in each book's reading data, so they are collected lazily: an
-- index in the settings folder remembers, per book, when its reading data was
-- last read and the highlights found; a pass over the library does a few books
-- at a time while the device is idle and skips books that have not changed.
-- The book just closed is read at once.

local DataStorage = require("datastorage")
local Library = require("cyberui/data/library")
local LuaSettings = require("luasettings")
local Profile = require("cyberui/data/profile")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")

local Shards = {}

-- Where the index is kept; a test sets another file before first use.
Shards.file = nil

local MAX_TEXT = 400        -- characters of a highlight kept
local PER_BOOK = 80         -- highlights kept from one book
local BATCH = 3             -- books read per idle tick
local TICK = 0.25           -- seconds between ticks

local store                 -- the index file, opened on first use
local queue, running, done  -- books waiting for a pass, whether one is going, what to call at its end
local flat                  -- every shard in one list, rebuilt when the index changes
local shown                 -- the shard on home until it is opened again: shard or false

-- The index: path -> { stamp (the reading data file's modification time), list }.
local function books()
    if not store then store = LuaSettings:open(Shards.file or (DataStorage:getSettingsDir() .. "/cyberui-shards.lua")) end
    local b = store:readSetting("books")
    if not b then b = {}; store:saveSetting("books", b) end
    return b
end

-- The reading data file of a book, or nil.
local function sidecar(path)
    local ok, file = pcall(function() return require("docsettings"):findSidecarFile(path) end)
    return ok and file or nil
end

-- A shard from one saved highlight.
local function make(path, a)
    local text = util.trim((a.text:gsub("%s+", " ")))
    if #text > MAX_TEXT then text = text:sub(1, MAX_TEXT):gsub("[\128-\191]*$", "") .. "..." end
    return {
        id = string.format("%08X", Profile.hash(path .. "|" .. text)), text = text, path = path,
        note = a.note and a.note ~= "" and a.note or nil, chapter = a.chapter, date = a.datetime, page = a.page, pos0 = a.pos0,
    }
end

-- The highlights saved in a book's reading data (this KOReader's list, and the
-- older per-page one), as shards.
function Shards.of(path)
    local ds = require("docsettings"):open(path)
    local out = {}
    for _i, a in ipairs(ds:readSetting("annotations") or {}) do
        if a.text and a.text ~= "" then out[#out + 1] = make(path, a) end
    end
    for page, list in pairs(ds:readSetting("highlight") or {}) do
        for _i, a in ipairs(list) do
            if a.text and a.text ~= "" then out[#out + 1] = make(path, { text = a.text, note = a.notes, chapter = a.chapter, datetime = a.datetime, page = page }) end
        end
    end
    return out
end

-- Read one book into the index when its reading data changed; true if it did.
local function read(path)
    local file = sidecar(path)
    local index = books()
    if not file then
        if index[path] then index[path] = nil; flat = nil; return true end
        return false
    end
    local stamp = lfs.attributes(file, "modification")
    if index[path] and index[path].stamp == stamp then return false end
    local list = Shards.of(path)
    while #list > PER_BOOK do list[#list] = nil end
    index[path] = { stamp = stamp, list = list }
    flat = nil
    return true
end

-- Take a book's highlights into the index now (it was just read).
function Shards.refresh(path)
    if read(path) then store:flush() end
end

-- Do a few books of the pass, then ask for the next tick.
local function tick()
    local n = 0
    while n < BATCH and #queue > 0 do
        read(table.remove(queue))
        n = n + 1
    end
    if #queue > 0 then
        UIManager:scheduleIn(TICK, tick)
    else
        running = false
        store:flush()
        if done then done() end
    end
end

-- Start (or keep going with) the pass over the whole library. It does nothing
-- more once every book has been looked at, until the library changes.
function Shards.collect(on_done)
    if running then return end
    done = on_done
    queue = {}
    local index = books()
    for _i, path in ipairs(Library.all()) do
        local file = sidecar(path)
        local entry = index[path]
        if file and not (entry and entry.stamp == lfs.attributes(file, "modification")) then queue[#queue + 1] = path end
    end
    if #queue == 0 then return end
    running = true
    UIManager:scheduleIn(TICK, tick)
end

-- Every shard, the newest first.
function Shards.all()
    if not flat then
        flat = {}
        for _path, entry in pairs(books()) do
            for _i, s in ipairs(entry.list) do flat[#flat + 1] = s end
        end
        table.sort(flat, function(a, b)
            if (a.date or "") ~= (b.date or "") then return (a.date or "") > (b.date or "") end
            return a.id < b.id
        end)
    end
    return flat
end

-- How many shards there are.
function Shards.count()
    return #Shards.all()
end

-- The shards of one book, in the order of the book.
function Shards.ofBook(path)
    local entry = books()[path]
    return entry and entry.list or {}
end

-- The books that have shards: { path, count }, the one with the most first.
function Shards.booksWith()
    local out = {}
    for path, entry in pairs(books()) do
        if #entry.list > 0 then out[#out + 1] = { path = path, count = #entry.list } end
    end
    table.sort(out, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.path < b.path
    end)
    return out
end

-- Pick another shard for home next time it is needed.
function Shards.shuffle()
    shown = nil
end

-- Pick another shard and give it (see Shards.random).
function Shards.another()
    shown = nil
    return Shards.random()
end

-- The shard on home and its place in the list: { shard, number, of }, or nil
-- when there is none.
function Shards.random()
    if shown == nil then
        local all = Shards.all()
        shown = #all > 0 and math.random(#all) or false
    end
    local all = Shards.all()
    if not shown or not all[shown] then return nil end
    return { shard = all[shown], number = shown, of = #all }
end

-- Forget what was read (tests).
function Shards.reset()
    store, queue, running, flat, shown = nil, nil, false, nil, nil
end

return Shards
