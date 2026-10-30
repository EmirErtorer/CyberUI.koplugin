-- Plural rules from a .po header: the C expression ("n%10==1 && n%100!=11 ?
-- 0 : ...") compiled to a function from a count to a form number (0 based).
-- Only digits, n and arithmetic and logic operators are accepted, so nothing
-- but arithmetic can run.

local Plural = {}

-- The tokens of an expression, or nil when it has anything else in it.
local function tokenize(expr)
    local tokens, i = {}, 1
    while i <= #expr do
        local c = expr:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c:match("%d") then
            local num = expr:match("^%d+", i)
            tokens[#tokens + 1] = num
            i = i + #num
        elseif c == "n" then
            tokens[#tokens + 1] = "n"
            i = i + 1
        else
            local two = expr:sub(i, i + 1)
            if two == "&&" or two == "||" or two == "==" or two == "!=" or two == "<=" or two == ">=" then
                tokens[#tokens + 1] = two
                i = i + 2
            elseif c:match("[%%<>!?:()+%-*/]") then
                tokens[#tokens + 1] = c
                i = i + 1
            else
                return nil
            end
        end
    end
    return tokens
end

-- Lua source for the expression, every value a number (comparisons give 1 or 0
-- as in C), or nil when it does not parse.
local function translate(tokens)
    local pos = 1
    local function peek() return tokens[pos] end
    local function take() pos = pos + 1; return tokens[pos - 1] end
    local ternary
    local function primary()
        local t = take()
        if t == "n" then return "n" end
        if t and t:match("^%d+$") then return t end
        if t == "(" then
            local inner = ternary()
            if take() ~= ")" then error("missing )") end
            return "(" .. inner .. ")"
        end
        error("unexpected " .. tostring(t))
    end
    local function unary()
        if peek() == "!" then take(); return "((" .. unary() .. ") == 0 and 1 or 0)" end
        return primary()
    end
    local function binary(next_level, ops)
        return function()
            local left = next_level()
            while ops[peek()] do
                local op = take()
                local right = next_level()
                left = ops[op](left, right)
            end
            return left
        end
    end
    local function cmp(lua_op) return function(a, b) return "((" .. a .. ") " .. lua_op .. " (" .. b .. ") and 1 or 0)" end end
    local mul = binary(unary, {
        ["*"] = function(a, b) return "(" .. a .. " * " .. b .. ")" end,
        ["/"] = function(a, b) return "math.floor(" .. a .. " / " .. b .. ")" end,
        ["%"] = function(a, b) return "(" .. a .. " % " .. b .. ")" end,
    })
    local add = binary(mul, {
        ["+"] = function(a, b) return "(" .. a .. " + " .. b .. ")" end,
        ["-"] = function(a, b) return "(" .. a .. " - " .. b .. ")" end,
    })
    local rel = binary(add, { ["<"] = cmp("<"), ["<="] = cmp("<="), [">"] = cmp(">"), [">="] = cmp(">=") })
    local eq = binary(rel, { ["=="] = cmp("=="), ["!="] = cmp("~=") })
    local land = binary(eq, { ["&&"] = function(a, b) return "(((" .. a .. ") ~= 0 and (" .. b .. ") ~= 0) and 1 or 0)" end })
    local lor = binary(land, { ["||"] = function(a, b) return "(((" .. a .. ") ~= 0 or (" .. b .. ") ~= 0) and 1 or 0)" end })
    function ternary()
        local cond = lor()
        if peek() == "?" then
            take()
            local yes = ternary()
            if take() ~= ":" then error("missing :") end
            local no = ternary()
            return "((" .. cond .. ") ~= 0 and (" .. yes .. ") or (" .. no .. "))"
        end
        return cond
    end
    local code = ternary()
    if pos <= #tokens then error("trailing " .. tostring(peek())) end
    return code
end

-- A function from a count to its form (0 based) for the rule `expr`; the
-- English rule (n != 1) when the expression cannot be used.
function Plural.compile(expr)
    local tokens = tokenize(expr or "")
    if tokens then
        local ok, code = pcall(translate, tokens)
        if ok then
            local fn = loadstring("return function(n) return " .. code .. " end")
            if fn then return fn() end
        end
    end
    return function(n) return n ~= 1 and 1 or 0 end
end

return Plural
