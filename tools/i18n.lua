-- The translation tool. Run from the repo root with LuaJIT (the emulator's, or any):
--   luajit tools/i18n.lua extract            rewrite l10n/cyberui.pot from the source
--   luajit tools/i18n.lua sync               extract, then bring every language up to date (new texts empty)
--   luajit tools/i18n.lua check              what the test suite runs; exit 1 with the problems listed
--   luajit tools/i18n.lua new <lang> <n> <rule>   start a language, e.g. new ru 3 "n%10==1 && n%100!=11 ? 0 : ..."
--   luajit tools/i18n.lua export <lang> [from [to]]   the texts still to translate (or a range), numbered
--   luajit tools/i18n.lua import <lang> <file>        numbered lines "N<TAB>translation" into the language
-- The texts are every _("..."), _.n("...", "...", n) and _.c("context", "...") in
-- the code. A translation is complete when it is there, not fuzzy, keeps the
-- placeholders (%d, %s...) in the same order and keeps the capitals of the English.

package.path = "./?.lua;" .. package.path
local Case = require("cyberui/i18n/case")
local Po = require("cyberui/i18n/po")

local POT = "l10n/cyberui.pot"
local ROLES = { ink = true, muted = true, accent = true, accent2 = true, on_ink = true, on_accent = true, on_accent2 = true,
    bg = true, soft = true, line = true }
local FIELDS = { text = true, label = true, title = true, sub = true, meta = true, placeholder = true, detail = true,
    tagline = true, description = true, title_right = true, path = true, note = true, hint = true, ok = true, cancel = true }

local function read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function write(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end

---------------------------------------------------------------- scanning the source

-- The Lua source files that have texts, sorted.
local function sourceFiles()
    local out = { "main.lua", "_meta.lua" }
    local p = io.popen("find cyberui -name '*.lua' | sort")
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    table.sort(out)
    return out
end

-- A string literal starting at i: its value and the index after it, or nil.
local function literal(src, i)
    local c = src:sub(i, i)
    local stop
    if c == '"' or c == "'" then
        local j = i + 1
        while j <= #src do
            local d = src:sub(j, j)
            if d == "\\" then j = j + 2 elseif d == c then stop = j; break else j = j + 1 end
        end
    else
        local eq = src:match("^%[(=*)%[", i)
        if not eq then return nil end
        local close = "]" .. eq .. "]"
        local e = src:find(close, i, true)
        if not e then return nil end
        stop = e + #close - 1
    end
    if not stop then return nil end
    local fn = loadstring("return " .. src:sub(i, stop))
    if not fn then return nil end
    local ok, value = pcall(fn)
    if not ok or type(value) ~= "string" then return nil end
    return value, stop + 1
end

-- Whitespace skipped from i, with the lines counted.
local function skip(src, i)
    local j = i
    while src:sub(j, j):match("%s") do j = j + 1 end
    return j
end

-- Scan one file: texts = { { kind, ctx, id, plural, line } }, problems = { "file:line: text" }.
local function scan(path)
    local src = read(path)
    local texts, problems = {}, {}
    local line, i = 1, 1
    local line_has_keep = {}
    for n, text in ipairs((function() local t = {} for l in (src .. "\n"):gmatch("(.-)\n") do t[#t + 1] = l end return t end)()) do
        if text:find("i18n: keep", 1, true) then line_has_keep[n] = true end
    end
    local function problem(msg) problems[#problems + 1] = string.format("%s:%d: %s", path, line, msg) end
    local function newlines(a, b) local _, n = src:sub(a, b):gsub("\n", "") return n end
    while i <= #src do
        local c = src:sub(i, i)
        if c == "\n" then
            line, i = line + 1, i + 1
        elseif src:sub(i, i + 1) == "--" then
            local eq = src:match("^%-%-%[(=*)%[", i)
            if eq then
                local close = "]" .. eq .. "]"
                local e = src:find(close, i, true) or #src
                line = line + newlines(i, e)
                i = e + #close
            else
                local e = src:find("\n", i, true) or #src + 1
                i = e
            end
        elseif c == '"' or c == "'" or src:match("^%[=*%[", i) then
            local value, after = literal(src, i)
            if not value then i = i + 1 else
                line = line + newlines(i, after - 1)
                i = after
            end
        elseif c:match("[%a_]") then
            local id = src:match("^[%w_]+", i)
            local prev = src:sub(i - 1, i - 1)
            local after = i + #id
            if id == "_" and not prev:match("[%w_.:]") then
                local kind, j
                if src:sub(after, after) == "(" then kind, j = "s", after + 1
                elseif src:sub(after, after + 2) == ".n(" then kind, j = "n", after + 3
                elseif src:sub(after, after + 2) == ".c(" then kind, j = "c", after + 3 end
                if kind then
                    local entry = { kind = kind, line = line }
                    local k = skip(src, j)
                    local first, e1 = literal(src, k)
                    if not first then
                        problem("a text must be a plain string, not a variable")
                    else
                        local second
                        if kind ~= "s" then
                            local e = skip(src, e1)
                            if src:sub(e, e) == "," then
                                second = literal(src, skip(src, e + 1))
                            end
                            if not second then problem("both texts of a plural or context must be plain strings") end
                        end
                        if kind == "s" then entry.id = first
                        elseif kind == "n" then entry.id, entry.plural = first, second
                        else entry.ctx, entry.id = first, second end
                        -- after the closing parenthesis of the call
                        local depth, k2 = 1, j
                        while k2 <= #src and depth > 0 do
                            local ch = src:sub(k2, k2)
                            if ch == '"' or ch == "'" or src:match("^%[=*%[", k2) then
                                local _v, nxt = literal(src, k2)
                                k2 = nxt or k2 + 1
                            else
                                if ch == "(" then depth = depth + 1 elseif ch == ")" then depth = depth - 1 end
                                k2 = k2 + 1
                            end
                        end
                        local rest = skip(src, k2)
                        if src:sub(rest, rest + 1) == ".." then problem("a text is joined to other text; make it one text with a placeholder") end
                        -- text joined on the left?
                        local b = i - 1
                        while b > 0 and src:sub(b, b):match("%s") do b = b - 1 end
                        if src:sub(b - 1, b) == ".." then problem("a text is joined to other text; make it one text with a placeholder") end
                        if entry.id and (kind ~= "n" or entry.plural) and (kind ~= "c" or entry.ctx) then texts[#texts + 1] = entry end
                    end
                end
            elseif FIELDS[id] and not prev:match("[%w_.]") then
                local k = skip(src, after)
                if src:sub(k, k) == "=" and src:sub(k + 1, k + 1) ~= "=" then
                    local value = literal(src, skip(src, k + 1))
                    if value and value:find("%a%a") and not ROLES[value] and not line_has_keep[line]
                        and (value:find("%s") or not value:find("[/%.:@~_]")) then
                        problem(string.format("%s = %q is shown to the reader but not translatable (wrap it in _(), or mark the line -- i18n: keep)", id, value))
                    end
                end
            end
            i = after
        else
            i = i + 1
        end
    end
    return texts, problems
end

-- Every text of the code, in order, and the problems found: { list = { {ctx, id, plural, refs} }, problems = {...} }.
local function extract()
    local list, byKey, problems = {}, {}, {}
    for _i, path in ipairs(sourceFiles()) do
        local texts, found = scan(path)
        for _j, p in ipairs(found) do problems[#problems + 1] = p end
        for _j, t in ipairs(texts) do
            local key = (t.ctx and t.ctx .. "\4" or "") .. t.id
            local e = byKey[key]
            if not e then
                e = { ctx = t.ctx, id = t.id, plural = t.plural, refs = {}, files = {} }
                byKey[key] = e
                list[#list + 1] = e
            end
            if t.plural and not e.plural then e.plural = t.plural end
            if not e.files[path] then
                e.files[path] = true
                e.refs[#e.refs + 1] = path
            end
        end
    end
    return list, problems
end

---------------------------------------------------------------- the .pot and the languages

local POT_HEADER = {
    { "Project-Id-Version", "CyberUI" },
    { "Report-Msgid-Bugs-To", "https://github.com/EmirErtorer/CyberUI.koplugin/issues" },
    { "MIME-Version", "1.0" },
    { "Content-Type", "text/plain; charset=UTF-8" },
    { "Content-Transfer-Encoding", "8bit" },
}

-- The extracted texts as .po entries (no translations yet).
local function potEntries(list)
    local out = {}
    for i, t in ipairs(list) do
        local shown = {}
        for k = 1, math.min(#t.refs, 4) do shown[k] = t.refs[k] end
        out[i] = { ctx = t.ctx, id = t.id, plural = t.plural, str = {}, flags = {}, refs = table.concat(shown, " ") .. (#t.refs > 4 and " ..." or "") }
    end
    return out
end

local function potText(list)
    return Po.write(POT_HEADER, potEntries(list))
end

local function languages()
    local out = {}
    local p = io.popen("ls l10n")
    for name in p:lines() do
        if read("l10n/" .. name .. "/cyberui.po") then out[#out + 1] = name end
    end
    p:close()
    table.sort(out)
    return out
end

local function headerList(header)
    local order = { "Project-Id-Version", "Language", "MIME-Version", "Content-Type", "Content-Transfer-Encoding", "Plural-Forms" }
    local out, seen = {}, {}
    for _i, k in ipairs(order) do
        if header[k] then out[#out + 1] = { k, header[k] }; seen[k] = true end
    end
    local extra = {}
    for k in pairs(header) do if not seen[k] then extra[#extra + 1] = k end end
    table.sort(extra)
    for _i, k in ipairs(extra) do out[#out + 1] = { k, header[k] } end
    return out
end

local function keyOf(e) return (e.ctx and e.ctx .. "\4" or "") .. e.id end

-- Rewrite a language's file in the order of the .pot, keeping what is translated.
local function syncLanguage(lang, list)
    local path = "l10n/" .. lang .. "/cyberui.po"
    local parsed = Po.parse(read(path))
    local have = {}
    for _i, e in ipairs(parsed.entries) do have[keyOf(e)] = e end
    local entries = potEntries(list)
    for _i, e in ipairs(entries) do
        local old = have[keyOf(e)]
        if old then
            e.str = old.str
            e.flags = old.flags
            e.notes = old.notes
            if e.plural and old.plural ~= e.plural then e.flags.fuzzy = true end
        end
    end
    write(path, Po.write(headerList(parsed.header), entries))
end

---------------------------------------------------------------- checking

-- The placeholders of a text in order: "%d", "%s", "%.1f", "%02d", "%%".
local function placeholders(s)
    local out = {}
    for spec in s:gmatch("%%[%d%.]*[%%a-zA-Z]") do out[#out + 1] = spec end
    return table.concat(out, " ")
end

-- Is the English all capitals (it has letters and no lower-case ones)?
local function isShouting(s)
    local plain = s:gsub("%%[%d%.]*[%%a-zA-Z]", ""):gsub("\\[%a]", "")
    return plain:find("%u%u") ~= nil and not plain:find("%l")
end

-- Names that are never translated: a text that has one must keep it, as written
-- (in capitals where the text is in capitals).
local BRANDS = { "CyberUI", "KOReader", "Ink Away", "Wi-Fi", "GitHub", "ZenOS", "Calibre", "Hardcover", "Bookshelf", "Oxanium",
    "Chakra Petch", "Rajdhani", "Orbitron", "Exo 2", "JetBrains Mono", "Share Tech", "Turret Road", "Michroma", "Electrolize",
    "Audiowide", "Wallpoet", "Russo One", "Iceland", "VT323", "Press Start 2P", "OPDS", "USB", "EPUB", "PDF" }

-- The problems of one language.
local function checkLanguage(lang, list)
    local problems = {}
    local function bad(msg) problems[#problems + 1] = string.format("l10n/%s: %s", lang, msg) end
    local parsed = Po.parse(read("l10n/" .. lang .. "/cyberui.po"))
    local nplurals = Po.pluralRule(parsed.header)
    local have = {}
    for _i, e in ipairs(parsed.entries) do have[keyOf(e)] = e end
    local code = lang:match("^%a+")
    local missing, count = 0, 0
    for _i, t in ipairs(list) do
        local e = have[keyOf(t)]
        local shown = string.format("%q", t.id)
        if not e then
            missing = missing + 1
        else
            have[keyOf(t)] = nil
            local forms = t.plural and nplurals or 1
            local filled = true
            for f = 1, forms do if not e.str[f] or e.str[f] == "" then filled = false end end
            if not filled then
                missing = missing + 1
            elseif e.flags.fuzzy then
                bad("fuzzy (needs a look): " .. shown)
            else
                count = count + 1
                for f = 1, forms do
                    local want = placeholders(f == 1 and t.id or (t.plural or t.id))
                    -- every plural form may leave the number out; all other placeholders stay
                    local got = placeholders(e.str[f])
                    if t.plural and f > 1 or t.plural then
                        local a, b = placeholders(t.id), placeholders(t.plural)
                        if got ~= a and got ~= b and got ~= "" then bad("placeholders differ in " .. shown .. " form " .. f) end
                    elseif want ~= got then
                        bad(string.format("placeholders differ in %s: %q", shown, e.str[f]))
                    end
                    for _b, brand in ipairs(BRANDS) do
                        local plain, mine = t.id:lower(), e.str[f]:lower()
                        if plain:find(brand:lower(), 1, true) and not mine:find(brand:lower(), 1, true) and not (Case.upper(brand, code) and mine:find(Case.upper(brand, code):lower(), 1, true)) then
                            bad(string.format("the name %s must stay as it is in: %s", brand, shown))
                        end
                    end
                    if e.str[f]:find("%%%d+%$") then bad("positional placeholders are not used: " .. shown) end
                    if isShouting(t.id) and not Case.isUpper(e.str[f], code) then
                        bad(string.format("capitals expected (the English is capitals): %s -> %q", shown, e.str[f]))
                    end
                    if e.str[f]:find("^%s") ~= t.id:find("^%s") or e.str[f]:find("%s$") ~= t.id:find("%s$") then
                        if (e.str[f]:find("^%s") ~= nil) ~= (t.id:find("^%s") ~= nil) or (e.str[f]:find("%s$") ~= nil) ~= (t.id:find("%s$") ~= nil) then
                            bad("leading or trailing space differs: " .. shown)
                        end
                    end
                end
            end
        end
    end
    for _k, e in pairs(have) do bad("a text no longer in the code: " .. string.format("%q", e.id)) end
    if missing > 0 then bad(string.format("%d of %d texts are not translated", missing, #list)) end
    return problems, count
end

---------------------------------------------------------------- commands

local command = arg[1]
local list, found = extract()

if command == "extract" then
    write(POT, potText(list))
    print(string.format("%d texts in %s", #list, POT))
elseif command == "sync" then
    write(POT, potText(list))
    for _i, lang in ipairs(languages()) do syncLanguage(lang, list) end
    print(string.format("%d texts; %d languages synced", #list, #languages()))
elseif command == "check" then
    local problems = {}
    for _i, p in ipairs(found) do problems[#problems + 1] = p end
    if read(POT) ~= potText(list) then problems[#problems + 1] = POT .. " is out of date: run  luajit tools/i18n.lua sync" end
    for _i, lang in ipairs(languages()) do
        local p, count = checkLanguage(lang, list)
        for _j, m in ipairs(p) do problems[#problems + 1] = m end
        print(string.format("%-6s %d / %d translated", lang, count, #list))
    end
    for _i, m in ipairs(problems) do print(m) end
    print(string.format("i18n: %d texts, %d problems", #list, #problems))
    os.exit(#problems == 0 and 0 or 1)
elseif command == "new" then
    local lang, n, rule = arg[2], arg[3], arg[4]
    assert(lang and n and rule, "usage: new <lang> <nplurals> <rule>")
    os.execute("mkdir -p l10n/" .. lang)
    local header = { { "Project-Id-Version", "CyberUI" }, { "Language", lang }, { "MIME-Version", "1.0" },
        { "Content-Type", "text/plain; charset=UTF-8" }, { "Content-Transfer-Encoding", "8bit" },
        { "Plural-Forms", string.format("nplurals=%d; plural=%s;", tonumber(n), rule) } }
    write("l10n/" .. lang .. "/cyberui.po", Po.write(header, {}))
    syncLanguage(lang, list)
    print("started l10n/" .. lang)
elseif command == "export" then
    local lang = arg[2]
    local parsed = Po.parse(read("l10n/" .. lang .. "/cyberui.po"))
    local have = {}
    for _i, e in ipairs(parsed.entries) do have[keyOf(e)] = e end
    local from, to = tonumber(arg[3]) or 1, tonumber(arg[4]) or #list
    local n = Po.pluralRule(parsed.header)
    for i = from, math.min(to, #list) do
        local t = list[i]
        local e = have[keyOf(t)]
        local done = e and e.str[1] and e.str[1] ~= ""
        if not done or arg[5] == "all" then
            local line = string.format("%d\t%s%s\t[%s]", i, t.ctx and ("(" .. t.ctx .. ") ") or "", t.id, table.concat(t.refs, " "):gsub("cyberui/", ""):gsub("%.lua", ""))
            if t.plural then line = line .. "\tPLURAL: " .. t.plural .. string.format("\t(%d forms)", n) end
            print(line)
        end
    end
elseif command == "import" then
    local lang, file = arg[2], arg[3]
    local path = "l10n/" .. lang .. "/cyberui.po"
    local parsed = Po.parse(read(path))
    local have = {}
    for _i, e in ipairs(parsed.entries) do have[keyOf(e)] = e end
    local nplurals = Po.pluralRule(parsed.header)
    local done, bad = 0, 0
    for row in (read(file) or ""):gmatch("[^\n]+") do
        local idx, rest = row:match("^(%d+)\t(.*)$")
        local t = idx and list[tonumber(idx)]
        if t then
            local forms = {}
            for form in (rest .. "\t"):gmatch("(.-)\t") do forms[#forms + 1] = form end
            local e = have[keyOf(t)]
            if e then
                e.str = forms
                e.flags.fuzzy = nil
                done = done + 1
                if t.plural and #forms ~= nplurals then bad = bad + 1; print("wrong number of forms at " .. idx) end
            end
        else
            print("skipped: " .. row:sub(1, 60))
        end
    end
    local entries = {}
    for _i, t in ipairs(potEntries(list)) do
        local e = have[keyOf(t)] or t
        e.refs = t.refs
        entries[#entries + 1] = e
    end
    write(path, Po.write(headerList(parsed.header), entries))
    print(string.format("imported %d (%d wrong)", done, bad))
else
    print("usage: luajit tools/i18n.lua extract | sync | check | new | export | import")
    os.exit(2)
end
