-- Gigs: the backlog as paid work. A book that has sat unopened for a week is
-- a gig with a price; opening it takes the gig and fixes the price, reading
-- pays out as you go (a tenth of the half for every 10% of the book, the other
-- half when it is finished). Eddies earned are kept as a ledger of signed
-- entries, and the balance is only ever worked out from the entries that still
-- check, so editing the settings file cannot make money. (The code is open, so
-- this stops casual edits, not a determined one.) Spending is meant to be one
-- more kind of entry later; nothing here changes for that.
--
-- Stored under one setting "gigs": { quotes = { path -> { price, days, t, sig } },
-- seen = { path -> { bits, sig } }, ledger = { { k, p, n, a, t, sig } } },
-- k being "m" (a milestone), "f" (the finish) or later "s" (spent).

local Books = require("cyberui/data/books")
local BookList = require("ui/widget/booklist")
local Library = require("cyberui/data/library")
local Profile = require("cyberui/data/profile")
local Settings = require("cyberui/settings")
local lfs = require("libs/libkoreader-lfs")
local sha2 = require("ffi/sha2")

local Gigs = {}

Gigs.GRACE_DAYS = 7     -- a new book is not a gig until it has sat this long
Gigs.WEEK_BONUS = 0.10  -- the price grows by this much for each idle week...
Gigs.MAX_FACTOR = 2     -- ...up to this many times the base price
Gigs.PAGE_RATE = 0.2    -- eddies per page before the age bonus
Gigs.STEP = 20          -- prices are whole multiples of this, so a tenth of the half is whole
Gigs.NEEDED = 0.7       -- the share of a stretch of book that must have been seen to count as read
local SALT = "cyberui-gigs-1"   -- part of every signature: never change it, or earned eddies stop checking

-- Rough kilobytes of file per page, by kind of file, for books never opened.
local KB_PER_PAGE = { pdf = 60, djvu = 60, djv = 60, cbz = 300, cbr = 300 }
local TEXT_KB_PER_PAGE = 2

local cache         -- { all, revision, list }: the board
local state         -- the verified ledger: { balance, paid (key -> true), earned, done, bad }
local cur           -- the book being read: { path, bits (table of 100), total, quote }
local receipt       -- what was paid since the reader last looked: { total, finished }

---------------------------------------------------------------- storage

-- The stored data, made on first use.
local function data()
    local d = Settings.get("gigs")
    if not d then
        d = { quotes = {}, seen = {}, ledger = {} }
        Settings.set("gigs", d)
    end
    return d
end

-- The signature of a payload: tied to this device's seed.
local function sign(payload)
    return sha2.sha256(SALT .. Profile.seed() .. payload):sub(1, 24)
end

-- The payload each kind of record is signed over.
local function entryText(e) return table.concat({ e.k, e.p, e.n or 0, e.a, e.t }, "|") end
local function quoteText(path, q) return table.concat({ "q", path, q.price, q.days, q.t }, "|") end
local function seenText(path, s) return "v|" .. path .. "|" .. s.bits end

---------------------------------------------------------------- ledger

-- Go through the ledger once and keep what checks: the balance, which
-- payouts were made, the lifetime total and how many gigs were finished.
local function verified()
    if state then return state end
    local d = data()
    state = { balance = 0, earned = 0, done = 0, paid = {}, bad = 0 }
    for _i, e in ipairs(d.ledger) do
        local key = e.k .. "|" .. e.p .. "|" .. (e.n or 0)
        if type(e.a) == "number" and e.sig == sign(entryText(e)) and not state.paid[key] then
            state.paid[key] = true
            state.balance = state.balance + e.a
            if e.a > 0 then state.earned = state.earned + e.a end
            if e.k == "f" then state.done = state.done + 1 end
        else
            state.bad = state.bad + 1
        end
    end
    return state
end

-- Forget everything worked out (the stored data changed behind our back).
function Gigs.reload()
    cache, state, cur, receipt = nil, nil, nil, nil
end

-- The eddies the reader has now.
function Gigs.balance()
    return verified().balance
end

-- All eddies ever earned, and the number of gigs finished.
function Gigs.totals()
    local s = verified()
    return s.earned, s.done
end

-- How many ledger entries did not check (the file was edited).
function Gigs.rejected()
    return verified().bad
end

-- Add a signed entry to the ledger.
local function pay(kind, path, n, amount)
    local e = { k = kind, p = path, n = n, a = amount, t = os.time() }
    e.sig = sign(entryText(e))
    local d = data()
    d.ledger[#d.ledger + 1] = e
    state = nil
    return e
end

-- The latest payouts, newest first: { { kind, path, n, amount, t } }, at most `count`.
function Gigs.recent(count)
    local out = {}
    local ledger = data().ledger
    verified()
    for i = #ledger, 1, -1 do
        local e = ledger[i]
        if e.sig == sign(entryText(e)) then
            out[#out + 1] = { kind = e.k, path = e.p, n = e.n, amount = e.a, t = e.t }
            if #out >= count then break end
        end
    end
    return out
end

---------------------------------------------------------------- price

-- How many pages a book is: what CoverBrowser knows, else a guess from the
-- size of the file (a book never opened has no page count yet).
function Gigs.pages(path)
    local known = Books.info(path).pages
    if known and known > 0 then return known end
    local ext = (path:match("%.(%w+)$") or ""):lower()
    local kb = (lfs.attributes(path, "size") or 0) / 1024
    return math.max(30, math.min(1200, math.floor(kb / (KB_PER_PAGE[ext] or TEXT_KB_PER_PAGE) + 0.5)))
end

-- The price of a book that has sat `days` days: its pages at a fixed rate, up
-- by a tenth for every idle week to twice at most, in whole steps of 20.
function Gigs.price(pages, days)
    local factor = math.min(Gigs.MAX_FACTOR, 1 + Gigs.WEEK_BONUS * math.floor(days / 7))
    return math.max(Gigs.STEP, math.floor(pages * Gigs.PAGE_RATE * factor / Gigs.STEP + 0.5) * Gigs.STEP)
end

-- What a price pays: each 10% of the book, and the finish.
function Gigs.split(price)
    return price / 20, price / 2
end

-- Days since a file was added.
local function daysIdle(path)
    return math.floor((os.time() - (lfs.attributes(path, "modification") or os.time())) / 86400)
end

---------------------------------------------------------------- the board

-- The books the reader said are not wanted: path -> true.
local function skipped()
    return Settings.get("bounty_skipped", {})
end

-- Every open gig, the oldest first: { path, days, pages, price }.
function Gigs.board()
    local all = Library.all()
    if cache and cache.all == all and cache.revision == Books.revision then return cache.list end
    local skip, quotes = skipped(), data().quotes
    local list = {}
    for _i, path in ipairs(all) do
        if not skip[path] and not quotes[path] and not BookList.hasBookBeenOpened(path) then
            local days = daysIdle(path)
            if days >= Gigs.GRACE_DAYS then
                local pages = Gigs.pages(path)
                list[#list + 1] = { path = path, days = days, pages = pages, price = Gigs.price(pages, days) }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.days ~= b.days then return a.days > b.days end
        return a.path < b.path
    end)
    cache = { all = all, revision = Books.revision, list = list }
    return list
end

-- The sum of every open gig's price.
function Gigs.total()
    local sum = 0
    for _i, g in ipairs(Gigs.board()) do sum = sum + g.price end
    return sum
end

-- Say a book is not wanted after all.
function Gigs.skip(path)
    local skip = skipped()
    skip[path] = true
    Settings.save("bounty_skipped", skip)
    cache = nil
end

-- Bring every skipped book back.
function Gigs.reset()
    Settings.save("bounty_skipped", nil)
    cache = nil
end

-- Take the gig on a book that is about to be opened for the first time: the
-- price is fixed as the board showed it. Does nothing for any other book.
function Gigs.accept(path)
    local d = data()
    if d.quotes[path] or skipped()[path] or BookList.hasBookBeenOpened(path) then return end
    local days = daysIdle(path)
    if days < Gigs.GRACE_DAYS then return end
    local q = { price = Gigs.price(Gigs.pages(path), days), days = days, t = os.time() }
    q.sig = sign(quoteText(path, q))
    d.quotes[path] = q
    d.seen[path] = nil
    cache = nil
    Settings.save("gigs", d)
end

-- The price of an accepted gig, or nil when the book is not one (or its
-- record was edited).
function Gigs.quote(path)
    local q = data().quotes[path]
    if q and q.sig == sign(quoteText(path, q)) then return q end
end

---------------------------------------------------------------- reading

-- What has been seen of a book: a string of 100 digits, one per percent.
local function loadBits(path)
    local s = data().seen[path]
    local bits = {}
    local text = (s and s.sig == sign(seenText(path, s))) and s.bits or string.rep("0", 100)
    for i = 1, 100 do bits[i] = text:byte(i) == 49 end
    return bits
end

-- Start following the open book if it is an accepted gig. Cheap for any other.
function Gigs.follow(path)
    if cur and cur.path == path then return end
    local q = Gigs.quote(path)
    cur = q and { path = path, quote = q, bits = loadBits(path), total = 0 } or nil
end

-- A page of the followed book was shown: mark the percents it covers.
function Gigs.page(page, total)
    if not cur or not total or total < 1 then return end
    cur.total = total
    local lo = math.floor((page - 1) * 100 / total) + 1
    local hi = math.max(lo, math.floor(page * 100 / total))
    for i = math.max(1, lo), math.min(100, hi) do cur.bits[i] = true end
end

-- Has the first `upto` percent been reached, and enough of it seen to count
-- as read?
local function read(bits, upto)
    local seen = 0
    for i = 1, upto do if bits[i] then seen = seen + 1 end end
    return seen >= upto * Gigs.NEEDED and (bits[upto] or bits[upto - 1] or bits[math.min(100, upto + 1)] or false)
end

-- Pay what the followed book has earned so far (the book is closed, or the
-- device sleeps) and keep what was seen. Returns the eddies paid.
function Gigs.settle()
    if not cur then return 0 end
    local d = data()
    local paid = verified().paid
    local milestone, finish = Gigs.split(cur.quote.price)
    local total, finished = 0, false
    for k = 1, 10 do
        if not paid["m|" .. cur.path .. "|" .. k] and read(cur.bits, k * 10) then
            pay("m", cur.path, k, milestone)
            total = total + milestone
            paid["m|" .. cur.path .. "|" .. k] = true
        end
    end
    local complete = Books.state(cur.path).status == "complete" or cur.bits[100] or cur.bits[99]
    if not paid["f|" .. cur.path .. "|0"] and paid["m|" .. cur.path .. "|10"] and complete then
        pay("f", cur.path, 0, finish)
        total, finished = total + finish, true
    end
    local chars = {}
    for i = 1, 100 do chars[i] = cur.bits[i] and "1" or "0" end
    local s = { bits = table.concat(chars) }
    s.sig = sign(seenText(cur.path, s))
    d.seen[cur.path] = s
    Settings.save("gigs", d)
    if total > 0 then
        receipt = receipt or { total = 0, finished = false }
        receipt.total, receipt.finished = receipt.total + total, receipt.finished or finished
    end
    return total
end

-- What was paid since the last call: { total, finished }, or nil.
function Gigs.takeReceipt()
    local r = receipt
    receipt = nil
    return r
end

-- The accepted gigs not yet finished, the most advanced first:
-- { path, price, milestones (paid), percent }.
function Gigs.active()
    local d = data()
    local paid = verified().paid
    local list = {}
    for path in pairs(d.quotes) do
        local q = Gigs.quote(path)
        if q and not paid["f|" .. path .. "|0"] then
            local n = 0
            for k = 1, 10 do if paid["m|" .. path .. "|" .. k] then n = k end end
            list[#list + 1] = { path = path, price = q.price, milestones = n, percent = Books.state(path).percent }
        end
    end
    table.sort(list, function(a, b)
        if a.milestones ~= b.milestones then return a.milestones > b.milestones end
        return a.path < b.path
    end)
    return list
end

return Gigs
