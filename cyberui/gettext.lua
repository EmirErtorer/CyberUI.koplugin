-- CyberUI's translations. `local _ = require("cyberui/gettext")` is used as
-- KOReader's gettext is: _("Text") gives the text in the reader's language. Also
--   _.n("%d book", "%d books", n)   the form for a count (languages differ)
--   _.c("context", "Text")          one word with two meanings, told apart
-- The language is KOReader's (restarting KOReader after changing it, as KOReader
-- asks). Translations are the .po files in l10n/<language>/ (see l10n/README.md);
-- a reader's own edits go in settings/cyberui-l10n/<language>.po and win. A text
-- with no translation falls to KOReader's own translation of it (many generic
-- words such as "Cancel" have one), then to the English it was written in.
-- English loads nothing; other languages load their file once, from a compiled
-- copy kept in the settings folder when the .po has not changed.

local Plural = require("cyberui/i18n/plural")
local Po = require("cyberui/i18n/po")

local I18n = {}
I18n.root = nil   -- the folder of the language folders (tests point it elsewhere)

local language          -- the code in use ("en" for none)
local catalog           -- [key] = text, or { forms } for a plural
local plural_fn         -- count -> form (0 based)
local stock             -- KOReader's own gettext

local CTX = "\4"        -- between a context and a text in a key

-- KOReader's own gettext, for the texts it already knows.
local function koreader()
    if stock == nil then
        local ok, g = pcall(require, "gettext")
        stock = ok and g or false
    end
    return stock
end

-- The .po folder of the plugin, and the reader's own.
function I18n.dir()
    return I18n.root or require("cyberui/paths").file("l10n")
end

local function pluginFile(lang)
    return I18n.dir() .. "/" .. lang .. "/cyberui.po"
end

local function userFile(lang)
    local ok, DataStorage = pcall(require, "datastorage")
    return ok and (DataStorage:getSettingsDir() .. "/cyberui-l10n/" .. lang .. ".po") or nil
end

local function cacheFile(lang)
    local ok, DataStorage = pcall(require, "datastorage")
    return ok and (DataStorage:getSettingsDir() .. "/cyberui-l10n-" .. lang .. ".lua") or nil
end

-- Does the file exist, and what are its size and date? ("size-mtime" or nil)
local function stamp(path)
    if not path then return nil end
    local ok, lfs = pcall(require, "libs/libkoreader-lfs")
    local a = ok and lfs.attributes(path)
    return a and a.mode == "file" and (a.size .. "-" .. a.modification) or nil
end

-- The language folder to use for a KOReader language code: the code itself, its
-- language alone ("de_DE" -> "de"), or a folder for a regional form of it
-- ("it" -> "it_IT"); nil when there is none.
local function folderFor(code)
    if not code or code == "" or code == "C" or code:match("^en") then return nil end
    code = code:gsub("%..*$", "")
    local ok, lfs = pcall(require, "libs/libkoreader-lfs")
    if not ok then return nil end
    local function has(dir) return stamp(pluginFile(dir)) ~= nil end
    if has(code) then return code end
    local base = code:match("^(%a+)")
    if has(base) then return base end
    local dir = I18n.dir()
    local found
    pcall(function()
        for name in lfs.dir(dir) do
            if not found and name:match("^" .. base .. "_") and has(name) then found = name end
        end
    end)
    return found
end

-- Texts and plural forms from parsed entries into the catalogue.
local function addEntries(map, entries)
    for _i, e in ipairs(entries) do
        local key = e.ctx and (e.ctx .. CTX .. e.id) or e.id
        if not e.flags.fuzzy then
            if e.plural then
                local forms, filled = {}, true
                for i = 1, #e.str do
                    forms[i] = e.str[i]
                    if e.str[i] == "" then filled = false end
                end
                if filled and #forms > 0 then map[key] = forms end
            elseif e.str[1] and e.str[1] ~= "" then
                map[key] = e.str[1]
            end
        end
    end
end

-- The language's catalogue as { rule = expression, map = {...} }, from the
-- compiled copy when the .po is unchanged, else from the .po (and the copy is
-- rewritten).
local function load(lang)
    local po = pluginFile(lang)
    local st = stamp(po)
    if not st then return nil end
    local cache = cacheFile(lang)
    if cache then
        local ok, data = pcall(loadfile(cache) or error)
        if ok and type(data) == "table" and data.stamp == st and data.version == 1 then return data end
    end
    local f = io.open(po, "r")
    if not f then return nil end
    local parsed = Po.parse(f:read("*a"))
    f:close()
    local data = { version = 1, stamp = st, rule = select(2, Po.pluralRule(parsed.header)), map = {} }
    addEntries(data.map, parsed.entries)
    if cache then
        pcall(function()
            local out = io.open(cache, "w")
            if not out then return end
            out:write("return { version = 1, stamp = ", string.format("%q", st), ", rule = ", string.format("%q", data.rule), ", map = {\n")
            for k, v in pairs(data.map) do
                if type(v) == "table" then
                    local parts = {}
                    for i, form in ipairs(v) do parts[i] = string.format("%q", form) end
                    out:write("[", string.format("%q", k), "] = { ", table.concat(parts, ", "), " },\n")
                else
                    out:write("[", string.format("%q", k), "] = ", string.format("%q", v), ",\n")
                end
            end
            out:write("} }\n")
            out:close()
        end)
    end
    return data
end

-- The pseudo-language for finding layout trouble: accented letters, 40% longer,
-- placeholders kept. Not a real language, no file.
local PSEUDO = {}
for plain, accented in pairs({ a = "à", e = "é", i = "ï", o = "ô", u = "ü", A = "Å", E = "É", I = "Ï", O = "Ö", U = "Û", c = "ç", n = "ñ", s = "š", y = "ý" }) do
    PSEUDO[plain] = accented
end
local function pseudo(text)
    local out, i = {}, 1
    while i <= #text do
        local spec = text:match("^%%[%d%.]*[%%dsfx]", i)
        if spec then
            out[#out + 1] = spec
            i = i + #spec
        else
            local c = text:sub(i, i)
            out[#out + 1] = PSEUDO[c] or c
            i = i + 1
        end
    end
    local s = table.concat(out)
    local extra = math.floor(#text * 0.4)
    return "[" .. s .. string.rep("~", extra) .. "]"
end

-- Use a language: a KOReader code ("de", "pt_BR"), "en_XA" (the pseudo-language) or nil/"C"
-- for English. Called at start with KOReader's own language; tests call it too.
function I18n.use(code)
    language, catalog, plural_fn = "en", {}, nil
    if code == "en_XA" then
        language = "en_XA"
        return language
    end
    local folder = folderFor(code)
    if not folder then return language end
    local data = load(folder)
    if not data then return language end
    language, catalog = folder, data.map
    plural_fn = Plural.compile(data.rule)
    -- the reader's own edits
    local user = userFile(folder)
    if stamp(user) then
        local f = io.open(user, "r")
        if f then
            addEntries(catalog, Po.parse(f:read("*a")).entries)
            f:close()
        end
    end
    return language
end

-- The language code in use ("en" when none).
function I18n.language()
    if not language then I18n.use(os.getenv("CYBERUI_LANG") or (G_reader_settings and G_reader_settings:readSetting("language"))) end
    return language
end

-- The catalogue (loaded on first use).
local function entries()
    if not language then I18n.language() end
    return catalog
end

-- A text in the reader's language.
local function translate(_self, msgid)
    local found = entries()[msgid]
    if found then return type(found) == "table" and found[1] or found end
    if language == "en_XA" then return pseudo(msgid) end
    local k = koreader()
    return k and k(msgid) or msgid
end

-- The text for a count: the form the language uses for that number.
function I18n.n(singular, plural, n)
    local found = entries()[singular]
    if type(found) == "table" and plural_fn then
        return found[plural_fn(n) + 1] or found[#found]
    end
    local text = n == 1 and singular or plural
    if language == "en_XA" then return pseudo(text) end
    return text
end

-- A text told apart by its context.
function I18n.c(context, msgid)
    local found = entries()[context .. CTX .. msgid]
    if found then return type(found) == "table" and found[1] or found end
    return translate(nil, msgid)
end

return setmetatable(I18n, { __call = translate })
