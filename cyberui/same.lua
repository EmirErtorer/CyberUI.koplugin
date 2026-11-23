-- Do two builds of a screen paint the same pixels? They do when their element
-- trees hold the same values (each element's class, values and children) and
-- what painting reads outside the tree (theme, settings, book facts, covers,
-- text) has not changed between the builds. Then the second needs no paint.

local Books = require("cyberui/data/books")
local Covers = require("cyberui/data/covers")
local Settings = require("cyberui/settings")
local Text = require("cyberui/gfx/text")
local Theme = require("cyberui/theme")

local Same = {}

local BUDGET = 4000   -- values compared at most; a bigger tree counts as changed
local DEPTH = 40      -- nesting at most

-- Set when painting: where it was, not what.
local PLACE = { x = true, y = true }

-- Functions that answer touches or build children (whose result is in the
-- tree already), never paint. Any other function must be the same one.
local function behaviour(k)
    return type(k) == "string" and (k:sub(1, 3) == "on_" or k == "make" or k == "make_pager" or k == "text_fn")
end

-- A table compared value by value: a plain one or an element (an instance of
-- a class with paint). Any other (a screen, a colour) must be the same one.
local function compared(t)
    local mt = getmetatable(t)
    return mt == nil or type(mt.paint) == "function"
end

local budget
local done   -- new table -> the old one it was found equal to (shared subtrees once)

-- Do a and b hold the same values (nested tables compared too)?
local function equal(a, b, depth)
    if depth > DEPTH or getmetatable(a) ~= getmetatable(b) then return false end
    local n = 0
    for k, v in pairs(b) do
        if not PLACE[k] then
            n = n + 1
            budget = budget - 1
            if budget < 0 then return false end
            local o = rawget(a, k)
            local tv = type(v)
            if tv == "table" and compared(v) then
                if type(o) ~= "table" then return false end
                if not (rawequal(o, v) or done[v] == o) then
                    if not equal(o, v, depth + 1) then return false end
                    done[v] = o
                end
            elseif tv == "function" and behaviour(k) then
                if type(o) ~= "function" then return false end
            elseif not rawequal(o, v) then
                return false
            end
        end
    end
    for k in pairs(a) do
        if not PLACE[k] then n = n - 1 end
    end
    return n == 0
end

-- The versions of what painting reads besides the tree, taken when a tree is
-- built, to compare with a later build's.
function Same.state()
    return Theme.get().version .. "/" .. Settings.revision .. "/" .. Books.revision
        .. "/" .. Covers.revision .. "/" .. Text.revision
end

-- Does tree b (built at state sb) paint the same as tree a (built at sa)?
function Same.trees(a, sa, b, sb)
    if not (a and b and sa and sa == sb) then return false end
    budget, done = BUDGET, {}
    local same = equal(a, b, 0)
    done = nil
    return same
end

return Same
