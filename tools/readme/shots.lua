-- The README's screenshots, in the Neon scheme, dark: run with
--   tools/readme/shots.sh  (portrait and landscape, into assets/screenshots)
local H = ...
local S = 1.5
local Settings = require("cyberui/settings")
local UIManager = require("ui/uimanager")
local land = os.getenv("CYBERUI_SHOTS_LANDSCAPE") == "1"

local function shot(name)
    UIManager:forceRePaint()
    H.shot(name)
end

-- the look the README shows, and a book well under way
H.step(1, function()
    for k, v in pairs({ scheme = "neon", mode = "dark", cover_style = "ascii", ascii_set = "braille",
            progress_style = "heartbeat", fontset = "oxanium", banner_title = "online", banner_top = "device" }) do
        Settings.set(k, v)
    end
    require("cyberui/theme").refresh()
    local History = require("cyberui/data/history")
    local cur = History.current()
    if cur then
        local ds = require("docsettings"):open(cur.path)
        ds:saveSetting("percent_finished", 0.42)
        local summary = ds:readSetting("summary") or {}
        summary.status = "reading"
        ds:saveSetting("summary", summary)
        ds:flush()
        require("cyberui/data/books").forget(cur.path)
    end
    -- a folder for the library to show as a stack: two books other than the
    -- one being read
    local Files, Library = require("cyberui/data/files"), require("cyberui/data/library")
    local dir = Files.mkdir(Library.home(), "Archive")
    local moved = 0
    for _i, b in ipairs(Library.all()) do
        if dir and moved < 2 and not (cur and b == cur.path) then
            Files.moveInto(b, dir)
            moved = moved + 1
        end
    end
    Library.reset()
    H.app().open()
end)

if land then
    H.step(3, function() H.app().render("full"); shot("12-landscape") end)
    return
end

H.step(4, function() H.app().render("full"); shot("01-home") end)
H.step(S, function() H.app().go("library") end)
H.step(4, function() shot("02-library") end)
H.step(S, function() H.app().go("home"); H.app().koreaderMenu() end)
H.step(S, function() shot("03-menu"); require("cyberui/menu").current():close() end)
H.step(S, function() H.app().push("dossier", { path = require("cyberui/data/history").current().path }) end)
H.step(3, function() shot("04-details") end)
H.step(S, function() H.app().go("library"); H.app().push("search"); H.app().current():setQuery("ka") end)
H.step(4, function() shot("05-search") end)
H.step(S, function() H.app().go("collections") end)
H.step(3, function() shot("06-collections") end)
H.step(S, function() H.app().go("history") end)
H.step(S, function() shot("07-log") end)
H.step(S, function() H.app().go("home"); H.app().push("diagnostics") end)
H.step(S, function() shot("08-diagnostics") end)
H.step(S, function() H.app().go("settings") end)
H.step(S, function() shot("09-look") end)
H.step(S, function() H.app().push("fonts") end)
H.step(3, function() shot("10-fonts") end)
H.step(S, function()
    H.app().go("home")
    G_reader_settings:saveSetting("screensaver_type", "cover")
    G_reader_settings:makeFalse("screensaver_show_message")
    G_reader_settings:makeFalse("screensaver_hide_cover_in_filemanager")
    G_reader_settings:saveSetting("lastfile", require("cyberui/data/history").current().path)
    Settings.set("ascii_sleep_mode", "covers")
    local Screensaver = require("ui/screensaver")
    Screensaver:setup()
    Screensaver:show()
end)
H.step(3, function() shot("11-sleep"); require("ui/screensaver"):close() end)
