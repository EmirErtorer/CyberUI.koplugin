-- The details a reader has changed by hand (KOReader's "custom metadata"):
-- title, authors, series, series number, genres and language, kept beside
-- the book and laid over what the book itself says. KOReader's own screens
-- and other plugins read the same file.

local DocSettings = require("docsettings")

local CustomProps = {}

-- The details that can be changed, with the names KOReader keeps them under.
CustomProps.KEYS = { "title", "authors", "series", "series_index", "keywords", "language" }

-- The custom details of a book: { key = value } (empty when it has none).
function CustomProps.read(path)
    local ok, file = pcall(DocSettings.findCustomMetadataFile, DocSettings, path)
    if not ok or not file then return {} end
    local read, ds = pcall(DocSettings.openSettingsFile, file)
    return read and ds:readSetting("custom_props") or {}
end

return CustomProps
