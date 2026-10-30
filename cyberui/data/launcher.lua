-- The home launcher's buttons: which are shown, in what order, and the ones
-- the reader made or changed. The list is kept in the settings; a built-in
-- button missing from it (a new version added one) is appended.

local Settings = require("cyberui/settings")

local Launcher = {}

-- The built-in buttons, in their default order, and the one that always
-- stays so the settings can always be reached.
Launcher.BUILTIN = { "library", "collections", "history", "search", "gigs", "shards", "inkaway", "settings" }

-- Built-in buttons that start hidden (the reader can show them in the editor).
Launcher.HIDDEN_AT_FIRST = { shards = true }
Launcher.FIXED = "settings"

local MAX = 12   -- buttons the home screen has room for

local builtin = {}
for _i, id in ipairs(Launcher.BUILTIN) do builtin[id] = true end

-- The saved entries, valid ones only, with every built-in present:
-- { id, hidden, custom = { name, icon, target } }.
function Launcher.entries()
    local out, seen = {}, {}
    for _i, e in ipairs(Settings.get("launcher", {})) do
        if type(e) == "table" and e.id == "bounty" then e.id = "gigs" end   -- its old name
        if type(e) == "table" and (builtin[e.id] or e.custom) and not seen[e.id] then
            seen[e.id] = true
            out[#out + 1] = e
        end
    end
    for _i, id in ipairs(Launcher.BUILTIN) do
        if not seen[id] then out[#out + 1] = { id = id, hidden = Launcher.HIDDEN_AT_FIRST[id] or nil } end
    end
    return out
end

-- The entries that are shown.
function Launcher.visible()
    local out = {}
    for _i, e in ipairs(Launcher.entries()) do
        if not e.hidden then out[#out + 1] = e end
    end
    return out
end

-- Write the list.
local function save(list)
    Settings.save("launcher", list)
end

-- Change the entry with this id by `fn(entry, list, index)`, then save.
local function change(id, fn)
    local list = Launcher.entries()
    for i, e in ipairs(list) do
        if e.id == id then
            fn(e, list, i)
            save(list)
            return true
        end
    end
    return false
end

-- Move an entry up (-1) or down (1).
function Launcher.move(id, delta)
    change(id, function(_e, list, i)
        local j = i + delta
        if list[j] then list[i], list[j] = list[j], list[i] end
    end)
end

-- Show or hide an entry (the settings button cannot be hidden).
function Launcher.setHidden(id, hidden)
    if id == Launcher.FIXED then return end
    change(id, function(e) e.hidden = hidden or nil end)
end

-- Give an entry its own name, icon and target (a built-in too: it then
-- stands for that instead).
function Launcher.setCustom(id, custom)
    change(id, function(e) e.custom = custom end)
end

-- Remove a button the reader made, or undo the changes to a built-in one.
function Launcher.remove(id)
    change(id, function(e, list, i)
        if builtin[id] then e.custom = nil else table.remove(list, i) end
    end)
end

-- Is there room for one more button?
function Launcher.canAdd()
    return #Launcher.entries() < MAX
end

-- Add a new button of the reader's own; returns its id.
function Launcher.add()
    local n = Settings.get("launcher_next", 1)
    Settings.set("launcher_next", n + 1)
    local id = "c" .. n
    local list = Launcher.entries()
    list[#list + 1] = { id = id, custom = { name = "NEW BUTTON", icon = "tools" } }
    save(list)
    return id
end

-- The entry with this id, or nil.
function Launcher.get(id)
    for _i, e in ipairs(Launcher.entries()) do
        if e.id == id then return e end
    end
    return nil
end

-- Is this a built-in button?
function Launcher.isBuiltin(id)
    return builtin[id] == true
end

return Launcher
