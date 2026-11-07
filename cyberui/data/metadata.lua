-- Changing a book's details: title, authors, series, series number, genres
-- and language are written as KOReader's custom metadata (the book file is
-- never touched, and the book's own details can always be brought back).

local Books = require("cyberui/data/books")
local CustomProps = require("cyberui/data/customprops")
local DocSettings = require("docsettings")
local util = require("util")
local _ = require("cyberui/gettext")

local Metadata = {}

-- The details that can be edited, in the order the editor lists them: key,
-- name, and whether it holds several values (one per line in the file, typed
-- here with semicolons between them).
Metadata.FIELDS = {
    { key = "title", name = _("Title") },
    { key = "authors", name = _("Authors"), multi = true },
    { key = "series", name = _("Series") },
    { key = "series_index", name = _("Series number") },
    { key = "keywords", name = _("Genres"), multi = true },
    { key = "language", name = _("Language") },
}

-- A field by its key.
local function field(key)
    for _i, f in ipairs(Metadata.FIELDS) do
        if f.key == key then return f end
    end
end

-- What a detail reads as to the reader: several values side by side.
function Metadata.show(key, value)
    value = value and tostring(value) or ""
    if field(key) and field(key).multi then
        local parts = {}
        for part in value:gmatch("[^\n]+") do parts[#parts + 1] = part end
        return table.concat(parts, "; ")
    end
    return value
end

-- What the reader typed as the text to keep: several values go one per line,
-- a number is kept plain. Returns nil when it is empty (the book's own detail
-- comes back), or nil and "number" when a series number is not a number.
function Metadata.parse(key, text)
    text = util.trim(text or "")
    if text == "" then return nil end
    if field(key) and field(key).multi then
        local parts = {}
        for part in text:gmatch("[^;\n]+") do
            part = util.trim(part)
            if part ~= "" then parts[#parts + 1] = part end
        end
        return #parts > 0 and table.concat(parts, "\n") or nil
    end
    if key == "series_index" then
        local n = tonumber((text:gsub(",", ".")))
        if not n then return nil, "number" end
        return n == math.floor(n) and string.format("%d", n) or tostring(n)
    end
    return text
end

-- The detail as the book now shows it, ready to read or to edit.
function Metadata.value(path, key)
    return Metadata.show(key, Books.info(path)[key])
end

-- Has the reader changed this detail (nil for the file: any detail)?
function Metadata.changed(path, key)
    local custom = Books.info(path).custom or {}
    if key then return custom[key] ~= nil end
    return next(custom) ~= nil
end

-- The book's own details, kept in the custom file so they can be restored.
local function originals(path)
    local o = Books.info(path).original or {}
    local out = {}
    for _i, k in ipairs(CustomProps.KEYS) do out[k] = o[k] end
    out.description, out.pages = o.description, o.pages
    return out
end

-- Save one detail (`value` nil takes the change back). Returns true, or false
-- when the file could not be written.
function Metadata.set(path, key, value)
    local file = DocSettings:findCustomMetadataFile(path)
    local ds = DocSettings.openSettingsFile(file)
    local props = ds:readSetting("custom_props", {})
    ds.data.custom_props = props
    if not file then ds:saveSetting("doc_props", originals(path)) end
    props[key] = value
    local saved = true
    if next(props) == nil then   -- nothing changed any more: no file at all
        if file then
            os.remove(file)
            DocSettings.removeSidecarDir(util.splitFilePathName(file))
        end
    else
        saved = ds:flushCustomMetadata(path) and true or false
    end
    Books.forget(path)
    return saved
end

-- Take every change back.
function Metadata.reset(path)
    local file = DocSettings:findCustomMetadataFile(path)
    if file then
        os.remove(file)
        DocSettings.removeSidecarDir(util.splitFilePathName(file))
    end
    Books.forget(path)
end

return Metadata
