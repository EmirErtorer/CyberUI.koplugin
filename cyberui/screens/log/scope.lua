-- The statistics scope sheet: count all books, or only the books in chosen
-- folders (add or remove them here).

local Actions = require("cyberui/actions")
local App = require("cyberui/app")
local Files = require("cyberui/data/files")
local Scope = require("cyberui/data/statsscope")
local Stats = require("cyberui/data/stats")
local _ = require("cyberui/gettext")

local ScopeSheet = {}

-- Keep a new list of folders and show the numbers for it.
local function apply(folders)
    Scope.set(folders)
    Stats.invalidate()
    App.update()
end

-- Open the sheet.
function ScopeSheet.open()
    local folders = {}
    for i, f in ipairs(Scope.folders()) do folders[i] = f end
    local actions = {
        { icon = "library", label = _("All books"), sub = Scope.active() and _("Count the whole library") or _("Counting the whole library"),
            on_tap = function() apply({}) end },
    }
    for i, f in ipairs(folders) do
        actions[#actions + 1] = { icon = "folder", label = Files.name(f), sub = _("Tap to stop counting it"), on_tap = function()
            local rest = {}
            for j, g in ipairs(folders) do if j ~= i then rest[#rest + 1] = g end end
            apply(rest)
        end }
    end
    actions[#actions + 1] = { icon = "plus", label = _("Add a folder"), sub = _("Count only the books in chosen folders"), on_tap = function()
        Actions.pickFolder({ title = _("Count this folder"), label = _("Count this folder"), icon = "check", on_pick = function(dir)
            folders[#folders + 1] = dir
            apply(folders)
        end })
    end }
    App.sheet({ title = _("Statistics scope"), cols = 1, actions = actions })
end

return ScopeSheet
