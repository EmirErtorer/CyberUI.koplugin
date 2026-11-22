-- Gigs: reading as paid work. Every book pays a little as it is read; the
-- board offers a few unopened books at a much better rate. A gig is a book
-- from the board: opening it takes the gig and fixes the price, reading pays
-- out as you go (a tenth of the half for every 10% of the book, the other
-- half when it is finished). The board holds a few slots filled at random and
-- drawn anew every week or so; a slot can be rolled for eddies. Payouts go in
-- the signed ledger (see Ledger), and so do the quotes and what has been seen
-- of each book, kept here:
-- quotes = { path -> { price, days, t, sig } } (days 0 is a book read at the
-- plain rate), seen = { path -> { bits, sig } }, board = { t, slots = { path } },
-- pace = { path -> { words, counted, quick } } (the words measured in the book,
-- see Pace, and how many pages counted or were turned too quickly to count).

local Books = require("cyberui/data/books")
local Economy = require("cyberui/data/economy")
local BookList = require("ui/widget/booklist")
local Library = require("cyberui/data/library")
local Settings = require("cyberui/settings")
local Ledger = require("cyberui/data/ledger")
local Pace = require("cyberui/data/pace")
local lfs = require("libs/libkoreader-lfs")

local Gigs = {}

Gigs.GRACE_DAYS = 1     -- a new book is not a gig until it has sat this long
Gigs.WEEK_BONUS = 0.25  -- a gig's price grows by this much for each idle week...
Gigs.MAX_FACTOR = 2     -- ...up to this many times the base price (after four weeks)
Gigs.PAGE_RATE = 0.2    -- eddies per page for a gig, before the age bonus
Gigs.BASE_RATE = 0.1    -- eddies per page for any other book
Gigs.ROLL_COST = 20     -- eddies to swap a gig on the board for another
Gigs.SLOTS = { 3, 5, 10 }
Gigs.ROTATIONS = { 3, 7, 14 }
Gigs.NEEDED = 0.7       -- the share of a stretch of book that must have been seen to count as read
Gigs.MIN_PAGES = 50     -- shorter files (pictures, one-page documents) are not books that pay
Gigs.MEASURE_AFTER = 3  -- seconds after a book opens that its words are measured (see Pace)
Gigs.MAX_ESTIMATE = 800 -- the most pages guessed for a book from the size of its file

-- Rough kilobytes of file per page, by kind of file, for books never opened.
local KB_PER_PAGE = { pdf = 60, djvu = 60, djv = 60, cbz = 300, cbr = 300 }
local TEXT_KB_PER_PAGE = 2
-- Files that are pictures, not books: they never pay, whatever their size.
local PICTURES = { png = true, jpg = true, jpeg = true, gif = true, webp = true, bmp = true, tif = true, tiff = true, svg = true }

-- The time now in seconds, to the millisecond, on a clock that stops while
-- the device sleeps (the tests replace it to set the pace of reading).
Gigs.clock = function()
    local time = require("ui/time")
    return time.to_s(time.now())
end

local cache         -- { all, revision, list }: the board
local cur           -- the book being read: { path, bits (table of 100), total, quote, pace, shown }
local receipt       -- what was paid since the reader last looked: { total, finished }

---------------------------------------------------------------- storage

local data, sign = Ledger.data, Ledger.sign

-- The payloads the quote and seen records are signed over.
local function quoteText(path, q) return table.concat({ "q", path, q.price, q.days, q.t }, "|") end
local function seenText(path, s) return "v|" .. path .. "|" .. s.bits end

-- Forget everything worked out (the stored data changed behind our back).
function Gigs.reload()
    cache, cur, receipt = nil, nil, nil
    Ledger.reload()
end

-- The latest payouts (not purchases), newest first.
function Gigs.recent(count)
    return Ledger.recent(count, "mfne")
end

---------------------------------------------------------------- price

-- How many pages a book is: what CoverBrowser knows, else a guess from the
-- size of the file (a book never opened has no page count yet).
function Gigs.pages(path)
    local known = Books.info(path).pages
    if known and known > 0 then return known end
    local ext = (path:match("%.(%w+)$") or ""):lower()
    local kb = (lfs.attributes(path, "size") or 0) / 1024
    return math.min(Gigs.MAX_ESTIMATE, math.floor(kb / (KB_PER_PAGE[ext] or TEXT_KB_PER_PAGE) + 0.5))
end

-- Is this file a book that can pay: not a picture, and long enough?
function Gigs.eligible(path)
    local ext = (path:match("%.(%w+)$") or ""):lower()
    return not PICTURES[ext] and Gigs.pages(path) >= Gigs.MIN_PAGES
end

-- A price in whole eddies, at least one.
local function priced(eddies)
    return math.max(1, math.floor(eddies + 0.5))
end

-- The price of a gig that has sat `days` days: its pages at the gig rate, up
-- by a quarter for every idle week to twice at most.
function Gigs.price(pages, days)
    local factor = math.min(Gigs.MAX_FACTOR, 1 + Gigs.WEEK_BONUS * math.floor(days / 7))
    return priced(pages * Gigs.PAGE_RATE * factor)
end

-- What any other book pays in all: its pages at the plain rate.
function Gigs.basePrice(pages)
    return priced(pages * Gigs.BASE_RATE)
end

-- What the first half of a price has paid once `n` of the ten tenths are read
-- (whole eddies, spread as evenly as they go), and the rest, paid at the finish.
function Gigs.paidAt(price, n)
    return math.floor(n * math.floor(price / 2) / 10)
end

-- What tenth number `k` pays.
function Gigs.milestone(price, k)
    return Gigs.paidAt(price, k) - Gigs.paidAt(price, k - 1)
end

-- What finishing pays: the half of the price that the tenths did not.
function Gigs.finish(price)
    return price - math.floor(price / 2)
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

-- How many gigs the board holds, and how many days it lasts.
function Gigs.slots() return Settings.get("gig_slots", 5) end
function Gigs.rotation() return Settings.get("gig_rotation", 7) end

-- The books that could be on the board now: never opened, not taken, not
-- turned down, and in the library for at least GRACE_DAYS. Returns them as a
-- set and as a list.
local function candidates(all)
    local skip, quotes = skipped(), data().quotes
    local set, list = {}, {}
    for _i, path in ipairs(all) do
        if not skip[path] and not quotes[path] and not BookList.hasBookBeenOpened(path) and daysIdle(path) >= Gigs.GRACE_DAYS and Gigs.eligible(path) then
            set[path] = true
            list[#list + 1] = path
        end
    end
    return set, list
end

-- Up to `count` of the books in `list` that are not in `taken`, at random.
local function draw(list, taken, count)
    local free = {}
    for _i, path in ipairs(list) do
        if not taken[path] then free[#free + 1] = path end
    end
    local out = {}
    for _i = 1, math.min(count, #free) do out[#out + 1] = table.remove(free, math.random(#free)) end
    return out
end

-- The stored board brought up to date: a slot whose book is no longer a
-- candidate goes, and a board that has lasted its days (or has nothing left)
-- is drawn anew. The slots do not refill in between, so there is no use in
-- changing the settings or opening books to get a fresh pick.
local function restock(set, list)
    local d = data()
    local board = d.board or { slots = {} }
    local before, stamp = table.concat(board.slots, "\0"), board.t
    local slots = {}
    for _i, path in ipairs(board.slots) do
        if set[path] and #slots < Gigs.slots() then slots[#slots + 1] = path end
    end
    local expired = not board.t or os.time() - board.t >= Gigs.rotation() * 86400
    if expired or #slots == 0 then
        local fresh = draw(list, {}, Gigs.slots())
        if expired or #fresh > 0 then slots, board.t = fresh, os.time() end
    end
    board.slots = slots
    if not d.board or board.t ~= stamp or table.concat(slots, "\0") ~= before then
        d.board = board
        Settings.save("gigs", d)
    end
    return slots
end

-- The gigs on the board, the oldest first: { path, days, pages, price }.
function Gigs.board()
    if not Economy.on() then return {} end
    local all = Library.all()
    if cache and cache.all == all and cache.revision == Books.revision then return cache.list end
    local set, pool = candidates(all)
    local list = {}
    for _i, path in ipairs(restock(set, pool)) do
        local days = daysIdle(path)
        local pages = Gigs.pages(path)
        list[#list + 1] = { path = path, days = days, pages = pages, price = Gigs.price(pages, days) }
    end
    table.sort(list, function(a, b)
        if a.days ~= b.days then return a.days > b.days end
        return a.path < b.path
    end)
    cache = { all = all, revision = Books.revision, list = list, pool = pool }
    return list
end

-- How many gigs are open, for the home screen: before the library has been
-- looked through this session (a moment after the first screen), the board
-- as it was last drawn.
function Gigs.openCount()
    if not Economy.on() then return 0 end
    if Library.stale() then
        local board = data().board
        return board and #(board.slots or {}) or 0
    end
    return #Gigs.board()
end

-- The open gig on this book, or nil.
function Gigs.offer(path)
    for _i, g in ipairs(Gigs.board()) do
        if g.path == path then return g end
    end
end

-- Days until the board is drawn anew, or nil when there is no board yet.
function Gigs.rotatesIn()
    local board = data().board
    if not (board and board.t) then return nil end
    return math.max(0, math.ceil((board.t + Gigs.rotation() * 86400 - os.time()) / 86400))
end

-- Take a book off the board for good: its slot stays empty until the board
-- is drawn anew.
function Gigs.skip(path)
    local skip = skipped()
    skip[path] = true
    Settings.save("bounty_skipped", skip)
    local d = data()
    for i, slot in ipairs(d.board and d.board.slots or {}) do
        if slot == path then table.remove(d.board.slots, i); break end
    end
    Settings.save("gigs", d)
    cache = nil
end

-- Swap the gig on this book for another book, for ROLL_COST eddies: true and
-- the new path, or false and why ("off", "slot", "none", "short").
function Gigs.roll(path)
    if not Economy.on() then return false, "off" end
    Gigs.board()
    local d = data()
    local index
    for i, slot in ipairs(d.board.slots) do
        if slot == path then index = i end
    end
    if not index then return false, "slot" end
    local taken = {}
    for _i, slot in ipairs(d.board.slots) do taken[slot] = true end
    local pick = draw(cache.pool, taken, 1)[1]
    if not pick then return false, "none" end
    local n = 1
    while Ledger.has("s", "roll", n) do n = n + 1 end
    local ok, why = Ledger.spend("roll", Gigs.ROLL_COST, n)
    if not ok then return false, why end
    d.board.slots[index] = pick
    Settings.save("gigs", d)
    cache = nil
    return true, pick
end

-- Take the gig on a book that is about to be opened for the first time: the
-- price is fixed as the board showed it. Does nothing for any other book.
function Gigs.accept(path)
    if not Economy.on() then return end
    -- only a book on the board as it was last drawn can be taken: most books
    -- opened never are, and need no look at the whole library
    local board = data().board
    local listed = false
    for _i, p in ipairs(board and board.slots or {}) do
        if p == path then listed = true; break end
    end
    if not listed then return end
    local g = Gigs.offer(path)
    if not g then return end
    local d = data()
    local q = { price = g.price, days = g.days, t = os.time() }
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

-- The quote for a book read at the plain rate, made when it is first
-- followed. Only a book started from the beginning joins: one read well
-- into before could never be paid for fairly.
local function plainQuote(path)
    local state = Books.state(path)
    if state.status == "complete" or state.percent > 0.1 or not Gigs.eligible(path) then return nil end
    local q = { price = Gigs.basePrice(Gigs.pages(path)), days = 0, t = os.time() }
    q.sig = sign(quoteText(path, q))
    local d = data()
    d.quotes[path] = q
    d.seen[path] = nil
    Settings.save("gigs", d)
    return q
end

-- What is kept on how a book is read: { words, counted, quick } (see Pace).
local function paceRecord(path)
    local d = data()
    d.pace = d.pace or {}
    d.pace[path] = d.pace[path] or { counted = 0, quick = 0 }
    return d.pace[path]
end

-- Start following the open book: the gig taken on it, or else the plain rate.
function Gigs.follow(path)
    if not Economy.on() or not path then cur = nil; return end
    if cur and cur.path == path then return end
    local q = Gigs.quote(path) or plainQuote(path)
    if not q then cur = nil; return end
    local kept = (data().pace or {})[path]
    cur = { path = path, quote = q, bits = loadBits(path), total = 0, pace = Pace.new(kept and kept.words) }
end

-- Does the followed book still need measuring (see Gigs.measure)?
function Gigs.needsMeasure()
    return cur ~= nil and cur.pace.words == nil
end

-- Measure the open document of the followed book, once for good: the words
-- in it set how long its pages must stay to count. Done a moment after the
-- book opens, never on a page turn. Returns the words (0 for a picture book).
function Gigs.measure(doc)
    if not (cur and doc and doc.file == cur.path and cur.pace.words == nil) then return nil end
    local words = Pace.measure(doc)
    if words == nil then return nil end
    cur.pace.words = words
    paceRecord(cur.path).words = words
    Settings.save("gigs", data())
    return words
end

-- Mark the percents a page covers as seen.
local function see(page, total)
    local lo = math.floor((page - 1) * 100 / total) + 1
    local hi = math.max(lo, math.floor(page * 100 / total))
    for i = math.max(1, lo), math.min(100, hi) do cur.bits[i] = true end
end

-- Count the page on screen if it has stayed long enough to have been read
-- (its words at a speed no one reads faster, see Pace). `left` says the page
-- was turned: its time is final, so it adds to the reader's usual pace, and a
-- page turned before it could be read is told apart from one still being read.
local function readIfStayed(shown, now, left)
    if not shown then return end
    local stayed = now - shown.t
    local need = Pace.need(cur.pace, shown.total, shown.unsettled)
    if left and Pace.note(cur.pace, stayed) and not shown.counted and stayed < need then
        cur.quick = (cur.quick or 0) + 1
    end
    if not shown.counted and stayed >= need then
        shown.counted = true
        cur.counted = (cur.counted or 0) + 1
        see(shown.page, shown.total)
    end
end

-- A page of the followed book was shown (`unsettled`: while the book is being
-- laid out anew, see Pace.need). The one before counts as read if it stayed
-- long enough, so turning through a book pays nothing.
function Gigs.page(page, total, unsettled)
    if not cur or not total or total < 1 then return end
    cur.total = total
    local now = Gigs.clock()
    if cur.shown and cur.shown.page == page and cur.shown.total == total then return end
    readIfStayed(cur.shown, now, true)
    cur.shown = { page = page, total = total, t = now, unsettled = unsettled or nil }
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
    if not cur or not Economy.on() then return 0 end
    local d = data()
    local paid = Ledger.verified().paid
    readIfStayed(cur.shown, Gigs.clock(), false)
    local price = cur.quote.price
    local gig = cur.quote.days > 0
    local mk, fk = gig and "m" or "n", gig and "f" or "e"   -- the entry kinds: gig, or plain rate
    local total, finished = 0, false
    for k = 1, 10 do
        if not paid[mk .. "|" .. cur.path .. "|" .. k] and read(cur.bits, k * 10) then
            local pay = Gigs.milestone(price, k)   -- a tenth of a small price can pay nothing: no entry then
            if pay > 0 then
                Ledger.add(mk, cur.path, k, pay)
                total = total + pay
                paid[mk .. "|" .. cur.path .. "|" .. k] = true
            end
        end
    end
    local complete = Books.state(cur.path).status == "complete" or cur.bits[100] or cur.bits[99]
    if not paid[fk .. "|" .. cur.path .. "|0"] and paid[mk .. "|" .. cur.path .. "|10"] and complete then
        Ledger.add(fk, cur.path, 0, Gigs.finish(price))
        total, finished = total + Gigs.finish(price), true
    end
    local chars = {}
    for i = 1, 100 do chars[i] = cur.bits[i] and "1" or "0" end
    local s = { bits = table.concat(chars) }
    s.sig = sign(seenText(cur.path, s))
    d.seen[cur.path] = s
    -- the pages counted and turned too quickly since the last settle are kept with the book
    local rec = paceRecord(cur.path)
    rec.counted, rec.quick = rec.counted + (cur.counted or 0), rec.quick + (cur.quick or 0)
    cur.counted, cur.quick = 0, 0
    Settings.save("gigs", d)
    if total > 0 then
        receipt = receipt or { total = 0, finished = false, gig = false }
        receipt.total, receipt.finished, receipt.gig = receipt.total + total, receipt.finished or finished, receipt.gig or gig
    end
    return total
end

-- What was paid since the last call: { total, finished, gig }, or nil.
function Gigs.takeReceipt()
    local r = receipt
    receipt = nil
    return r
end

-- How a book pays and how far it has, for the dossier and the Gigs page:
-- { state, gig, price, earned, left, finish, finish_paid, seen (0 to 1),
-- tenths = { the share of each tenth counted }, paid = { true or false for
-- each tenth }, next = { k, pay } or nil,
-- counted, quick, mode ("words", "pace" or nil) }. `state` is "paying" (its
-- price is fixed), "offer" (not started: what it would pay; `price` is the
-- board's for a gig), "started" (begun before eddies, so it cannot pay),
-- "short" (not a book that pays) or "off" (eddies switched off).
function Gigs.earnings(path)
    if not Economy.on() then return { state = "off" } end
    local q = Gigs.quote(path)
    if not q then
        if not Gigs.eligible(path) then return { state = "short" } end
        local st = Books.state(path)
        if st.status == "complete" or st.percent > 0.1 then return { state = "started" } end
        local offer = Gigs.offer(path)
        local price = offer and offer.price or Gigs.basePrice(Gigs.pages(path))
        return { state = "offer", gig = offer ~= nil, price = price, earned = 0, left = price, finish = Gigs.finish(price), seen = 0, tenths = {}, paid = {} }
    end
    local gig = q.days > 0
    local mk, fk = gig and "m" or "n", gig and "f" or "e"
    local paid_keys = Ledger.verified().paid
    local bits = (cur and cur.path == path) and cur.bits or loadBits(path)
    local seen, tenths = 0, {}
    for i = 1, 100 do
        if bits[i] then
            seen = seen + 1
            local k = math.ceil(i / 10)
            tenths[k] = (tenths[k] or 0) + 0.1
        end
    end
    local e = { state = "paying", gig = gig, price = q.price, seen = seen / 100, tenths = tenths, paid = {}, finish = Gigs.finish(q.price) }
    local n = 0
    for k = 1, 10 do
        e.paid[k] = paid_keys[mk .. "|" .. path .. "|" .. k] == true
        if e.paid[k] then n = k end
        -- (a tenth too small to pay anything never gets an entry: it counts as paid once read)
        if not e.paid[k] and Gigs.milestone(q.price, k) == 0 and read(bits, k * 10) then e.paid[k] = true; n = k end
        if not e.paid[k] and not e.next and Gigs.milestone(q.price, k) > 0 then e.next = { k = k, pay = Gigs.milestone(q.price, k) } end
    end
    e.finish_paid = paid_keys[fk .. "|" .. path .. "|0"] == true
    e.earned = 0
    for k = 1, 10 do if paid_keys[mk .. "|" .. path .. "|" .. k] then e.earned = e.earned + Gigs.milestone(q.price, k) end end
    if e.finish_paid then e.earned = e.earned + e.finish end
    e.left = q.price - e.earned
    e.milestones = n
    local rec = (data().pace or {})[path] or {}
    local live = (cur and cur.path == path) and cur or {}
    e.counted = (rec.counted or 0) + (live.counted or 0)
    e.quick = (rec.quick or 0) + (live.quick or 0)
    local words = (live.pace and live.pace.words) or rec.words
    if words ~= nil then e.mode = words > 0 and "words" or "pace" end
    return e
end

-- The books paying now and not finished: the gigs first, then the books at
-- the plain rate (there may be many: every book opened joins), each group the
-- most advanced first: { path, gig, price, milestones (paid), earned, seen }.
function Gigs.active()
    local d = data()
    local list = {}
    for path in pairs(d.quotes) do
        local q = Gigs.quote(path)
        if q then
            local e = Gigs.earnings(path)
            if e.state == "paying" and not e.finish_paid then
                list[#list + 1] = { path = path, gig = e.gig, price = e.price, milestones = e.milestones, earned = e.earned, seen = e.seen }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.gig ~= b.gig then return a.gig end
        if a.milestones ~= b.milestones then return a.milestones > b.milestones end
        if a.seen ~= b.seen then return a.seen > b.seen end
        return a.path < b.path
    end)
    return list
end

return Gigs
