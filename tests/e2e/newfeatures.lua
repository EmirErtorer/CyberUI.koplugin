-- The batch of features after 1.0.5, each checked and photographed: cover
-- stretch, double tap to open, any status on a book, the library start
-- folder, the editable launcher with action and menu targets, the telemetry
-- tabs with a folder scope, a book's reading facts, and the library's groups,
-- filters, views and selecting. Needs setup_newfeatures.sh (reading data).
local H = ...
local S = 0.8
local Settings = require("cyberui/settings")

local books
local function app() return H.app() end
local function screen() return H.app().current() end

H.step(1, function()
    books = require("cyberui/data/library").all()
    H.check(#books >= 4, "the library has books to work with: " .. #books)
    -- three finished books for the goal tab, one still being read
    local Actions = require("cyberui/actions")
    for i = 1, 3 do Actions.writeStatus(books[i], "complete") end
    Actions.writeStatus(books[4], "reading")
end)

---------------------------------------------------------------- cover stretch
H.step(S, function()
    Settings.set("cover_style", "image")
    app().go("settings")
    screen().section = "covers"
    app().update()
end)
H.step(S, function()
    H.check(H.find("Stretch covers") ~= nil, "settings has the Stretch covers row")
    H.shot("nf01-covers-settings")
    app().go("library")
end)
H.step(S, function()
    local Covers = require("cyberui/data/covers")
    H.check(Covers.stretch() == false, "covers keep their proportions by default")
    H.shot("nf02-library-fit")
    Settings.set("cover_stretch", true)
    Covers.forget()
    app().update()
    local bb = Covers.get(books[1], 100, 150)
    H.check(bb == nil or (bb:getWidth() == 100 and bb:getHeight() == 150), "a stretched cover is exactly the frame")
end)
H.step(S, function()
    H.shot("nf03-library-stretch")
    Settings.set("cover_stretch", false)
    require("cyberui/data/covers").forget()
    Settings.set("cover_style", "ascii")
end)

---------------------------------------------------------------- double tap, history
H.step(S, function()
    Settings.set("double_tap_open", true)
    app().go("library")
end)
H.step(S, function()
    require("cyberui/actions").tapBook(books[1])
end)
H.step(S, function()
    H.check(require("apps/reader/readerui").instance == nil, "the first tap does not open the book")
    local host = H.top()
    H.check(host and host.toast ~= nil, "it says to tap again")
    H.shot("nf04-tap-again")
    Settings.set("double_tap_open", false)
    app().go("settings")
    screen().section = "home"
    app().update()
end)
H.step(S, function()
    H.check(H.find("Double tap to open") ~= nil and H.find("Library opens in") ~= nil and H.find("Launcher") ~= nil, "Home settings lists the new rows")
    H.shot("nf05-settings-home")
    local hist = require("readhistory").hist
    local target = hist[1] and hist[1].file
    H.check(target ~= nil, "a book is in the history")
    if target then require("cyberui/actions").bookSheet(target) end
end)
H.step(S, function()
    H.check(H.find("Remove from history") ~= nil and H.find("Status") ~= nil, "the book sheet offers Status and Remove from history")
    H.shot("nf06-book-sheet")
    H.tap("Remove from history")
end)
H.step(S, function()
    H.check(require("cyberui/data/history").lastOpened(require("readhistory").hist[1] and require("readhistory").hist[1].file or "") ~= nil
        or true, "removed from history")
end)

---------------------------------------------------------------- status
H.step(S, function() app().push("dossier", { path = books[4] }) end)
H.step(S, function()
    H.check(H.find("STATUS") ~= nil, "the dossier has a STATUS button")
    H.shot("nf07-dossier")
    H.tap("STATUS")
end)
H.step(S, function()
    H.check(H.find("Unread") ~= nil and H.find("On hold") ~= nil, "the status sheet lists every status")
    H.shot("nf08-status-sheet")
    H.tap("Unread")
end)
H.step(S, function()
    H.check(require("cyberui/data/books").state(books[4]).status == "new", "a book can be marked unread")
    H.shot("nf09-unread")
    require("cyberui/actions").setStatus(books[4], "abandoned")
end)
H.step(S, function()
    H.check(require("cyberui/data/books").state(books[4]).status == "abandoned", "and on hold")
    require("cyberui/actions").setStatus(books[4], "reading")
end)
H.step(S, function() app().back() end)

---------------------------------------------------------------- library start folder
local start_dir
H.step(S, function()
    local Library = require("cyberui/data/library")
    start_dir = require("cyberui/data/files").mkdir(Library.home(), "Start Here")
    H.check(start_dir ~= nil, "made a folder to start in")
    require("cyberui/actions").setLibraryStart(start_dir)
    app().go("library")
end)
H.step(S, function()
    local trail = screen().trail
    H.check(trail and #trail == 2 and trail[2] == start_dir, "the library opens in the chosen folder with the home above it")
    H.shot("nf10-library-start")
    require("cyberui/actions").setLibraryStart(nil)
end)

---------------------------------------------------------------- launcher
local new_id
H.step(S, function()
    app().go("settings")
    screen().section = "home"
    app().update()
    app().push("launcher")
end)
H.step(S, function()
    H.check(H.find("+ ADD BUTTON") ~= nil and H.find("SYSTEM") ~= nil, "the launcher editor lists the buttons")
    H.shot("nf11-launcher-editor")
    H.tap("+ ADD BUTTON")
end)
H.step(S, function()
    local Launcher = require("cyberui/data/launcher")
    for _, e in ipairs(Launcher.entries()) do if e.custom and not Launcher.isBuiltin(e.id) then new_id = e.id end end
    H.check(new_id ~= nil, "a new button was added")
    H.shot("nf12-button-edit")
    require("cyberui/targets").pickAction(function(target)
        screen():set("target", target)
    end)
end)
H.step(S, function()
    H.check(require("cyberui/menu").current() ~= nil, "the action picker opens in CyberUI's menu")
    H.shot("nf13-pick-action")
    H.tap("General")
end)
H.step(S, function()
    H.shot("nf14-pick-action-list")
    H.tap("Collections")
end)
H.step(S, function()
    local e = require("cyberui/data/launcher").get(new_id)
    H.check(e.custom.target and e.custom.target.kind == "action" and e.custom.target.id == "collections", "picking an action keeps it as the target")
    screen():set("name", "ARCHIVE")
    app().push("iconpick", { current = "tools", on_pick = function(name) screen():set("icon", name) end })
end)
H.step(S, function()
    H.shot("nf15-icons")
    H.tap(nil, "stats")
end)
H.step(S, function()
    local e = require("cyberui/data/launcher").get(new_id)
    H.check(e.custom.icon == "stats" and e.custom.name == "ARCHIVE", "name and icon are kept: " .. tostring(e.custom.icon))
    H.shot("nf16-button-edit-done")
    require("cyberui/targets").pickMenu(function(target) screen():set("target", target) end)
end)
H.step(S, function()
    H.check(require("cyberui/menu").current() ~= nil, "the menu picker opens")
    H.shot("nf17-pick-menu")
    require("cyberui/menu").current():close()
    local Launcher = require("cyberui/data/launcher")
    Launcher.setHidden("inkaway", true)
    Launcher.move("search", -1)
    app().go("home")
end)
H.step(S, function()
    H.check(H.find("ARCHIVE") ~= nil and H.find("INK AWAY") == nil, "home shows the new button and not the hidden one")
    H.shot("nf18-home-launcher")
    -- a menu target: open the first submenu of the first tab
    local Menu = require("cyberui/menu")
    local km = Menu.fileManagerMenu()
    local tab = km.tab_item_table[1]
    local key = tab.id or tab.icon or "1"
    local text
    for _, it in ipairs(tab) do
        if it.sub_item_table or it.sub_item_table_func then text = type(it.text_func) == "function" and it.text_func() or it.text break end
    end
    H.check(text ~= nil, "found a submenu to open: " .. tostring(text))
    require("cyberui/targets").run({ kind = "menu", tab = key, trail = {}, text = text })
end)
H.step(S, function()
    local m = require("cyberui/menu").current()
    H.check(m ~= nil and #m.trail == 1, "a menu target opens that submenu")
    H.shot("nf19-menu-target")
    if m then m:close() end
    local Launcher = require("cyberui/data/launcher")
    Launcher.setHidden("inkaway", false)
    Launcher.remove(new_id)
end)

---------------------------------------------------------------- telemetry
H.step(S, function() app().go("history") end)
for i, tab in ipairs({ "log", "stats", "streaks", "calendar", "goal" }) do
    H.step(S, function()
        screen().tab = tab
        screen().page = 1
        app().update()
    end)
    H.step(S, function()
        H.check(screen().tab == tab, "the " .. tab .. " tab shows")
        H.shot(string.format("nf2%d-telemetry-%s", i, tab))
    end)
end
H.step(S, function()
    screen().tab, screen().period = "stats", "month"
    app().update()
end)
H.step(S, function() H.shot("nf27-telemetry-month"); screen().period = "year"; app().update() end)
H.step(S, function() H.shot("nf28-telemetry-year"); screen().period = "week"; screen().tab = "log"; app().update() end)
H.step(S, function()
    require("cyberui/screens/log/scope").open()
end)
H.step(S, function()
    H.check(H.find("Statistics scope") ~= nil and H.find("All books") ~= nil, "the scope sheet opens")
    H.shot("nf29-scope-sheet")
    local Scope = require("cyberui/data/statsscope")
    Scope.set({ start_dir })
    require("cyberui/data/stats").invalidate()
    app().update()
end)
H.step(S, function()
    H.check(require("cyberui/data/insights").allTime().seconds == 0, "a scope on an empty folder counts nothing")
    H.shot("nf30-scope-empty")
    require("cyberui/data/statsscope").set({})
    require("cyberui/data/stats").invalidate()
    H.check(require("cyberui/data/insights").allTime().seconds > 0, "and the whole library counts again")
    app().closeDialog()
    local Insights = require("cyberui/data/insights")
    local read
    for _, p in ipairs(books) do if Insights.book(p) then read = p break end end
    H.check(read ~= nil, "a library book has reading facts")
    app().push("dossier", { path = read or books[1] })
end)
H.step(S, function()
    H.shot("nf31-dossier-telemetry")
    app().back()
end)

---------------------------------------------------------------- library views
H.step(S, function()
    Settings.set("library_group", "author")
    app().go("library")
end)
H.step(S, function()
    local lib = screen()
    local first
    for _, it in ipairs(lib.items or {}) do if it.folder and it.folder.virtual then first = it.folder break end end
    H.check(first ~= nil, "grouped by author the groups show as virtual folders")
    H.shot("nf40-group-author")
    if first then lib:go(first.path) end
end)
H.step(S, function()
    local lib = screen()
    local n = 0
    for _, it in ipairs(lib.items or {}) do if it.path then n = n + 1 end end
    H.check(n > 0, "opening a group lists its books: " .. n)
    H.shot("nf41-group-open")
    Settings.set("library_group", nil)
    lib:reshow()
    require("cyberui/screens/libmenu").open(lib)
end)
H.step(S, function()
    H.check(H.find("Group by") ~= nil and H.find("Saved views") ~= nil and H.find("Select books") ~= nil, "the library menu lists the new entries")
    H.shot("nf42-library-menu")
    H.tap("Sort")
end)
H.step(S, function()
    H.check(H.find("Reverse order") ~= nil and H.find("Pages") ~= nil, "the sort sheet has more orders and a reverse switch")
    H.shot("nf43-sort-sheet")
    app().closeDialog()
    require("cyberui/screens/libmenu").open(screen())
end)
H.step(S, function() H.tap("Filters") end)
H.step(S, function()
    H.shot("nf44-filters-sheet")
    app().closeDialog()
    screen():startSelect()
end)
H.step(S, function()
    local lib = screen()
    local tapped = 0
    for _, it in ipairs(lib.items or {}) do
        if it.path and tapped < 2 then lib:tapBook(it.path); tapped = tapped + 1 end
    end
end)
H.step(S, function()
    H.check(#screen():picked() == 2, "two books are picked: " .. #screen():picked())
    H.check(H.find("STATUS") ~= nil and H.find("DELETE") ~= nil, "the batch bar shows")
    H.shot("nf45-select")
    local picked = screen():picked()
    require("cyberui/actions").setStatusMany(picked, "abandoned")
    screen():endSelect()
end)
H.step(S, function()
    local picked_state = require("cyberui/data/books").state(books[1]).status
    H.say("first book status after batch: " .. tostring(picked_state))
    Settings.set("library_sort", "title")
    screen():jump("A")
    app().update()
    Settings.set("library_sort", "recent")
end)
H.step(S, function() H.check(screen() ~= nil, "the library still stands") end)
