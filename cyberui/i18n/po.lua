-- Reading and writing gettext .po files, the format translators already know
-- (Poedit, Weblate, any text editor). No dependencies, so the tools can use it
-- too. An entry is { ctx, id, plural, str = { [1] = msgstr or the plural forms
-- in order }, flags = { fuzzy = true }, refs = "file:line ...", notes = "..." }.

local Po = {}

-- The text of a quoted .po string, escapes undone.
local function unquote(s)
    s = s:gsub('\\(.)', function(c)
        if c == "n" then return "\n" end
        if c == "t" then return "\t" end
        if c == "r" then return "\r" end
        return c
    end)
    return s
end

-- A string as a quoted .po string.
local function quote(s)
    s = s:gsub('[\\"\n\t\r]', { ["\\"] = "\\\\", ['"'] = '\\"', ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" })
    return '"' .. s .. '"'
end

-- Parse .po text: { header = { Key = value }, entries = { ... } }. Obsolete
-- (#~) entries are skipped.
function Po.parse(text)
    local entries, header = {}, {}
    local cur, field, index
    local function finish()
        if not cur then return end
        if cur.id == "" and not cur.ctx then
            for line in (cur.str[1] or ""):gmatch("[^\n]+") do
                local k, v = line:match("^([^:]+):%s*(.*)$")
                if k then header[k] = v end
            end
        elseif cur.id then
            entries[#entries + 1] = cur
        end
        cur, field, index = nil, nil, nil
    end
    local function start()
        if not cur then cur = { str = {}, flags = {}, refs = nil, notes = nil } end
    end
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        if line == "" then
            finish()
        elseif line:sub(1, 2) == "#~" then
            cur = cur   -- obsolete entries are ignored
        elseif line:sub(1, 2) == "#:" then
            start()
            cur.refs = ((cur.refs and cur.refs .. " " or "") .. line:sub(3):match("^%s*(.-)%s*$"))
        elseif line:sub(1, 2) == "#," then
            start()
            for flag in line:sub(3):gmatch("[^,%s]+") do cur.flags[flag] = true end
        elseif line:sub(1, 2) == "#." then
            start()
            cur.notes = ((cur.notes and cur.notes .. "\n" or "") .. line:sub(3):match("^%s*(.-)%s*$"))
        elseif line:sub(1, 1) == "#" then
            start()
        else
            local key, rest = line:match("^(msg[a-z_]*)%s*(.*)$")
            local idx
            if key == "msgstr" then
                idx = rest:match("^%[(%d+)%]")
                if idx then rest = rest:gsub("^%[%d+%]%s*", "") end
            end
            if key then
                if (key == "msgctxt" or key == "msgid") and cur and cur.id ~= nil then finish() end
                start()
                local value = unquote(rest:match('^"(.*)"$') or "")
                if key == "msgctxt" then cur.ctx, field = value, "ctx"
                elseif key == "msgid" then cur.id, field = value, "id"
                elseif key == "msgid_plural" then cur.plural, field = value, "plural"
                elseif key == "msgstr" then
                    index = (tonumber(idx) or 0) + 1
                    cur.str[index] = value
                    field = "str"
                end
            else
                local more = line:match('^"(.*)"$')
                if more and cur then
                    more = unquote(more)
                    if field == "str" then cur.str[index] = (cur.str[index] or "") .. more
                    elseif field then cur[field] = (cur[field] or "") .. more end
                end
            end
        end
    end
    finish()
    return { header = header, entries = entries }
end

-- The plural rule of a header: how many forms and the C expression choosing
-- one, e.g. 3, "n%10==1 && n%100!=11 ? 0 : 1". Two forms and n != 1 when absent.
function Po.pluralRule(header)
    local forms = (header or {})["Plural-Forms"] or ""
    return tonumber(forms:match("nplurals%s*=%s*(%d+)")) or 2, forms:match("plural%s*=%s*([^;]+)") or "n != 1"
end

-- One entry as .po text.
local function writeEntry(out, e)
    if e.notes then for line in e.notes:gmatch("[^\n]+") do out[#out + 1] = "#. " .. line end end
    if e.refs then out[#out + 1] = "#: " .. e.refs end
    local flags = {}
    for flag in pairs(e.flags or {}) do flags[#flags + 1] = flag end
    if #flags > 0 then table.sort(flags); out[#out + 1] = "#, " .. table.concat(flags, ", ") end
    if e.ctx then out[#out + 1] = "msgctxt " .. quote(e.ctx) end
    out[#out + 1] = "msgid " .. quote(e.id)
    if e.plural then
        out[#out + 1] = "msgid_plural " .. quote(e.plural)
        local count = math.max(#e.str, 2)
        for i = 1, count do out[#out + 1] = string.format("msgstr[%d] %s", i - 1, quote(e.str[i] or "")) end
    else
        out[#out + 1] = "msgstr " .. quote(e.str[1] or "")
    end
    out[#out + 1] = ""
end

-- .po text for a header (an ordered list of { key, value }) and entries.
function Po.write(header, entries)
    local out = { 'msgid ""', 'msgstr ""' }
    for _i, kv in ipairs(header) do out[#out + 1] = quote(kv[1] .. ": " .. kv[2] .. "\n") end
    out[#out + 1] = ""
    for _i, e in ipairs(entries) do writeEntry(out, e) end
    return table.concat(out, "\n")
end

return Po
