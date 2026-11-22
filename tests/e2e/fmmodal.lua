-- KOReader started with a notice up (CoverBrowser says its database was
-- updated, on a fresh or updated KOReader): CyberUI shows the notice as its
-- own popup, and the file browser is built while the popup is open. The file
-- browser must not be made modal for it, or CyberUI's home lands underneath
-- it and KOReader opens to the plain file browser (seen on a Kindle Scribe and
-- in a benchmark on KOReader 2026.07.2).
local H = ...
local UIManager = require("ui/uimanager")
local FileManager = require("apps/filemanager/filemanager")
local notice

local function stack()
    local t = {}
    for i, w in ipairs(UIManager._window_stack) do
        local name = w.widget.name or (w.widget == FileManager.instance and "filemanager-window") or "?"
        t[#t + 1] = i .. ":" .. tostring(name) .. (w.widget.modal and "(modal)" or "")
    end
    return table.concat(t, " ")
end

H.step(2, function()
    local App = H.app()
    -- the moment before KOReader's start shows its file browser: only the notice is up
    notice = require("ui/widget/infomessage"):new({ text = "Book info cache database updated." })
    UIManager:show(notice)
    App.close()
    local old = FileManager.instance
    if old then UIManager:close(old) end
end)
H.step(1, function()
    H.check(H.top() ~= nil and H.top().name == "cyberui_popup", "the notice shows as CyberUI's popup: " .. stack())
    -- KOReader builds the file browser now, then CyberUI opens as the start screen
    FileManager:showFiles(G_reader_settings:readSetting("home_dir"))
end)
H.step(1, function()
    local fm = FileManager.instance
    H.check(fm ~= nil and not fm.modal, "the file browser shown under the notice is not made modal: " .. stack())
    H.app().open()
end)
H.step(1, function()
    UIManager:close(notice)
end)
H.step(1, function()
    H.check(H.cyberTop(), "once the notice is gone, CyberUI's home is on top of the file browser: " .. stack())
    H.shot("fm01-home")
end)
