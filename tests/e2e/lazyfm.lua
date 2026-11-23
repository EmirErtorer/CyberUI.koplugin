-- KOReader's file browser under CyberUI home: built at start and after each
-- book without its list (home covers it), and listed the moment it shows.
-- Needs setup_cyberui.sh (KOReader starts with CyberUI).
local H = ...
local LazyFM = require("cyberui/lazyfm")
local UIManager = require("ui/uimanager")
local book
local gc_seen, gc_looked

local function fm() return require("apps/filemanager/filemanager").instance end
local function listed()
    local f = fm()
    return f ~= nil and not f.file_chooser._cyberui_lazy and #f.file_chooser.item_table > 0
end
local function inReader() local t = H.top(); return t ~= nil and t.document ~= nil and t.view ~= nil end

H.step(3, function()
    H.check(H.cyberTop() and H.screen() == "home", "KOReader starts on CyberUI home")
    H.check(fm() ~= nil and LazyFM.waiting(), "the file browser under home has not listed its folder")
    H.check(not jit or jit.status(), "LuaJIT's compiler is back on once home is up")
    local lfs = require("libs/libkoreader-lfs")
    local dir = G_reader_settings:readSetting("home_dir")
    for f in lfs.dir(dir) do
        if not book and f:match("%.epub$") then book = dir .. "/" .. f end
    end
    H.app().fileBrowser()
end)
H.step(1.5, function()
    H.check(H.top() == fm(), "leaving CyberUI shows the file browser")
    H.check(listed(), "which lists its folder as it shows")
    H.shot("lazy1-browser")
    H.app().open()
end)
H.step(1.5, function()
    H.check(H.cyberTop(), "CyberUI opens over the file browser again")
    fm():onRefresh()
    H.check(LazyFM.waiting(), "a refresh while home covers it waits")
    -- (with parking on, a closed book stays open under home and no browser is built)
    require("cyberui/settings").set("park_reader", false)
    H.app().openBook(book)
    -- CoverBrowser's collection after a browser closes frees its covers: the
    -- waiting browser had none, so none is scheduled (looked at once the
    -- reader has replaced the browser, before the collection would run)
    UIManager:tickAfterNext(function()
        gc_seen = false
        for _, task in ipairs(UIManager._task_queue) do
            local info = type(task.action) == "function" and debug.getinfo(task.action, "S")
            if info and info.source:find("covermenu", 1, true) then gc_seen = true end
        end
        gc_looked = fm() == nil
    end)
end)
H.step(4, function()
    H.check(gc_looked and gc_seen == false, "opening a book from home schedules no collection for the browser that never listed")
    H.check(inReader(), "a book opens from home")
    H.event("Home")
end)
H.step(2, function()
    H.check(H.cyberTop() and H.screen() == "home", "closing it lands on home")
    H.check(fm() ~= nil and LazyFM.waiting(), "the file browser rebuilt under home waits for its list")
    H.app().close()
end)
H.step(1.5, function()
    H.check(H.top() == fm() and listed(), "closing CyberUI lists the folder before the browser shows")
    H.shot("lazy2-browser")
    -- the safety net: a browser shown over home while waiting lists itself when painted
    H.app().open()
end)
H.step(1.5, function()
    fm().file_chooser:refreshPath()
    H.check(LazyFM.waiting(), "waiting again under home")
    UIManager:show(require("ui/widget/container/framecontainer"):new({ covers_fullscreen = true, fm().file_chooser }))
end)
H.step(1.5, function()
    H.check(listed(), "painting the waiting browser lists it first")
    UIManager:close(H.top())
end)
