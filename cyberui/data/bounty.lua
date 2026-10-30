-- The backlog as bounties: books never opened, the oldest first. A book is
-- wanted once it has sat unread for a week; its bounty grows by 10 for every
-- day since it was added, and a book the reader opens is claimed (it leaves
-- the list). The list is worked out once and kept until the library or a
-- book's state changes.

local Books = require("cyberui/data/books")
local BookList = require("ui/widget/booklist")
local Library = require("cyberui/data/library")
local Settings = require("cyberui/settings")
local lfs = require("libs/libkoreader-lfs")

local Bounty = {}

Bounty.PER_DAY = 10    -- bounty added by each day a book is idle
Bounty.GRACE_DAYS = 7  -- a new book is not wanted until it is this old

local cache         -- { all (the library list it was made from), revision, list }

-- The books the reader said are not wanted: path -> true.
local function skipped()
    return Settings.get("bounty_skipped", {})
end

-- Every wanted book, the oldest first: { path, days, reward }.
function Bounty.list()
    local all = Library.all()
    if cache and cache.all == all and cache.revision == Books.revision then return cache.list end
    local now, skip = os.time(), skipped()
    local list = {}
    for _i, path in ipairs(all) do
        if not skip[path] and not BookList.hasBookBeenOpened(path) then
            local days = math.floor((now - (lfs.attributes(path, "modification") or now)) / 86400)
            if days >= Bounty.GRACE_DAYS then list[#list + 1] = { path = path, days = days, reward = days * Bounty.PER_DAY } end
        end
    end
    table.sort(list, function(a, b)
        if a.days ~= b.days then return a.days > b.days end
        return a.path < b.path
    end)
    cache = { all = all, revision = Books.revision, list = list }
    return list
end

-- The sum of every bounty on the list.
function Bounty.total()
    local sum = 0
    for _i, b in ipairs(Bounty.list()) do sum = sum + b.reward end
    return sum
end

-- Say a book is not wanted after all.
function Bounty.skip(path)
    local skip = skipped()
    skip[path] = true
    Settings.save("bounty_skipped", skip)
    cache = nil
end

-- Bring every skipped book back.
function Bounty.reset()
    Settings.save("bounty_skipped", nil)
    cache = nil
end

return Bounty
