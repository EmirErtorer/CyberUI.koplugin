-- KOReader's file browser while CyberUI home covers it. KOReader builds the
-- browser at start and again each time a book closes, listing its folder
-- (every file checked against collections and sorted) and letting CoverBrowser
-- extract the covers of that list: all for a screen nobody sees under home.
-- While home covers it, the browser keeps its folder but leaves the list for
-- later, and makes it the moment it can be seen: when CyberUI closes, or when
-- anything paints it.

local LazyFM = {}

local armed = false   -- the browser being built now opens under home
local fill_now        -- KOReader's own refreshPath

-- Is the browser hidden under home? While one is being built for home to
-- cover (`armed`), or while CyberUI's window is open over it.
local function covered()
    if armed then return true end
    local App = _G.package.loaded["cyberui/app"]
    return App ~= nil and App.isOpen()
end

-- The browser being built next opens under home (on = true), or that is over.
function LazyFM.arm(on)
    armed = on == true
end

-- Make the list of a browser left without one (the current browser by
-- default), so it can be shown.
function LazyFM.fill(chooser)
    if not chooser then
        local fm = _G.package.loaded["apps/filemanager/filemanager"]
        chooser = fm and fm.instance and fm.instance.file_chooser
    end
    if chooser and chooser._cyberui_lazy then
        chooser._cyberui_lazy = nil
        fill_now(chooser)
    end
end

-- Has the current browser been left without its list?
function LazyFM.waiting()
    local fm = _G.package.loaded["apps/filemanager/filemanager"]
    local chooser = fm and fm.instance and fm.instance.file_chooser
    return chooser ~= nil and chooser._cyberui_lazy == true
end

-- Patch KOReader's FileChooser once: the file browser's refreshPath waits
-- while it is covered, and a paint of a browser still waiting fills it first.
function LazyFM.install()
    if fill_now then return end
    local FileChooser = require("ui/widget/filechooser")
    fill_now = FileChooser.refreshPath
    FileChooser.refreshPath = function(self, ...)
        if self.name == "filemanager" and covered() then
            self._cyberui_lazy = true
            return
        end
        self._cyberui_lazy = nil
        return fill_now(self, ...)
    end
    local paint = FileChooser.paintTo
    FileChooser.paintTo = function(self, ...)
        if self._cyberui_lazy then LazyFM.fill(self) end
        return paint(self, ...)
    end
end

return LazyFM
