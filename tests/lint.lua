-- Lint the plugin code (plain luajit, from the plugin folder):
--   luajit tests/lint.lua
-- Fails on reads or writes of globals outside the standard library (a typo or
-- a local used before it is defined) and on loops that name a variable `_`,
-- which hides gettext's `_` in the rest of the loop.

local allowed = {}
for n in ("_G assert bit collectgarbage coroutine debug error getmetatable io ipairs jit load loadfile "
    .. "loadstring math next os pairs pcall print rawequal rawget rawlen rawset require select "
    .. "setfenv getfenv setmetatable string table tonumber tostring type unpack xpcall "
    .. "G_reader_settings"):gmatch("%S+") do allowed[n] = true end

local bad = 0
for f in io.popen("find cyberui -name '*.lua' | sort; echo main.lua; echo _meta.lua"):lines() do
    for line in io.popen("luajit -bl " .. f):lines() do
        local name = line:match('G[GS]ET%s.-; "([%a_][%w_]*)"')
        if name and not allowed[name] then
            bad = bad + 1
            print("LINT: global '" .. name .. "' in " .. f)
        end
    end
    local n = 0
    for src in io.lines(f) do
        n = n + 1
        if src:match("for%s+_%s*,") or src:match("local%s+_%s*,") or src:match("function%s*%(_[,%)]") then
            bad = bad + 1
            print(string.format("LINT: '_' hides gettext at %s:%d", f, n))
        end
    end
end
-- Calls into CyberUI's plain modules (a `local M = {}` table) must name
-- something the module defines: a misspelt or missing function would only
-- fail when that button is pressed.
local defs = {}   -- module path -> { name = true }, for plain modules only
local function read(f)
    local h = io.open(f)
    if not h then return nil end
    local src = h:read("*a")
    h:close()
    return src
end
for f in io.popen("find cyberui -name '*.lua' | sort"):lines() do
    local src = read(f)
    local tname = src:match("\nreturn%s+([%a_][%w_]*)%s*$")
    if tname and src:match("local%s+" .. tname .. "%s*=%s*{") then
        local names = {}
        for n in src:gmatch("function%s+" .. tname .. "[.:]([%a_][%w_]*)") do names[n] = true end
        for n in src:gmatch("\n" .. tname .. "%.([%a_][%w_]*)%s*=") do names[n] = true end
        for n in src:gmatch("%s([%a_][%w_]*)%s*=%s*[^=]") do if src:match("local%s+" .. tname .. "%s*=%s*{[^}]*" .. n) then names[n] = true end end
        defs[f:gsub("%.lua$", "")] = names
    end
end
for f in io.popen("find cyberui -name '*.lua' | sort; echo main.lua"):lines() do
    local src = read(f)
    for var, mod in src:gmatch("local%s+([%a_][%w_]*)%s*=%s*require%(\"(cyberui/[%w_/]+)\"%)") do
        local names = defs[mod]
        if names then
            for field in src:gmatch("[^%w_.]" .. var .. "[.:]([%a_][%w_]*)") do
                if not names[field] then
                    bad = bad + 1
                    print(string.format("LINT: %s uses %s.%s, which %s does not define", f, var, field, mod))
                end
            end
        end
    end
end
print(string.format("lint: %d problems", bad))
os.exit(bad == 0 and 0 or 1)
