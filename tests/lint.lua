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
print(string.format("lint: %d problems", bad))
os.exit(bad == 0 and 0 or 1)
