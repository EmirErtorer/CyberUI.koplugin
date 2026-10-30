-- The signed ledger of eddies. Every record kept under the setting "gigs" (a
-- price quote, what has been seen of a book, a payout, a purchase) is signed
-- with a hash tied to this device's seed, and the balance and what is owned
-- are worked out only from entries that still check, so editing the settings
-- file cannot make money or unlock anything. (The code is open, so this stops
-- casual edits, not a determined one.)
--
-- Entry kinds: "m" a milestone payout, "f" a finish payout, "s" a purchase (a
-- negative amount, `p` the id of the style bought).
-- Stored as { quotes = {}, seen = {}, ledger = { { k, p, n, a, t, sig } } }.

local Profile = require("cyberui/data/profile")
local Settings = require("cyberui/settings")
local sha2 = require("ffi/sha2")

local Ledger = {}

local SALT = "cyberui-gigs-1"   -- part of every signature: never change it, or earned eddies stop checking
local state                     -- the verified ledger: { balance, paid (key -> true), earned, done, bad }

-- The stored data, made on first use.
function Ledger.data()
    local d = Settings.get("gigs")
    if not d then
        d = { quotes = {}, seen = {}, ledger = {} }
        Settings.set("gigs", d)
    end
    return d
end

-- Write the stored data to disk.
function Ledger.save()
    Settings.save("gigs", Ledger.data())
end

-- The signature of a payload: tied to this device's seed.
function Ledger.sign(payload)
    return sha2.sha256(SALT .. Profile.seed() .. payload):sub(1, 24)
end

-- The payload an entry is signed over.
local function entryText(e) return table.concat({ e.k, e.p, e.n or 0, e.a, e.t }, "|") end

-- The key an entry is remembered by: one payout or purchase happens once.
local function keyOf(kind, id, n) return kind .. "|" .. id .. "|" .. (n or 0) end

-- Forget what was worked out (the stored data or an entry changed).
function Ledger.reload()
    state = nil
end

-- Go through the ledger once and keep what checks: the balance, which
-- entries were made, the lifetime total and how many gigs were finished.
local function verified()
    if state then return state end
    state = { balance = 0, earned = 0, done = 0, paid = {}, bad = 0 }
    for _i, e in ipairs(Ledger.data().ledger) do
        local key = type(e.k) == "string" and type(e.p) == "string" and keyOf(e.k, e.p, e.n)
        local sane = type(e.a) == "number" and ((e.k == "s") == (e.a < 0))
        if key and sane and e.sig == Ledger.sign(entryText(e)) and not state.paid[key] then
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
Ledger.verified = verified

-- The eddies the reader has now.
function Ledger.balance()
    return math.max(0, verified().balance)
end

-- All eddies ever earned, and the number of gigs finished.
function Ledger.totals()
    local s = verified()
    return s.earned, s.done
end

-- How many entries did not check (the file was edited).
function Ledger.rejected()
    return verified().bad
end

-- Was this entry made (and does it check)?
function Ledger.has(kind, id, n)
    return verified().paid[keyOf(kind, id, n)] == true
end

-- Add a signed entry; the caller saves.
function Ledger.add(kind, id, n, amount)
    local e = { k = kind, p = id, n = n, a = amount, t = os.time() }
    e.sig = Ledger.sign(entryText(e))
    local d = Ledger.data()
    d.ledger[#d.ledger + 1] = e
    state = nil
    return e
end

-- Buy something for `price` eddies: false and a reason when it is already
-- owned or the balance would go below zero.
function Ledger.spend(id, price)
    if type(price) ~= "number" or price <= 0 then return false, "price" end
    if Ledger.has("s", id) then return false, "owned" end
    if verified().balance < price then return false, "short" end
    Ledger.add("s", id, 0, -price)
    Ledger.save()
    return true
end

-- The latest entries that check, newest first, at most `count`: { kind, path (id), n, amount, t }.
function Ledger.recent(count, kinds)
    local out = {}
    local ledger = Ledger.data().ledger
    verified()
    for i = #ledger, 1, -1 do
        local e = ledger[i]
        if type(e.k) == "string" and (not kinds or kinds:find(e.k, 1, true)) and e.sig == Ledger.sign(entryText(e)) then
            out[#out + 1] = { kind = e.k, path = e.p, n = e.n, amount = e.a, t = e.t }
            if #out >= count then break end
        end
    end
    return out
end

return Ledger
