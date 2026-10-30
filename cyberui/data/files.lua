-- Moving, renaming and making folders the way KOReader does it: a book's
-- reading data (its .sdr sidecar), its place in the history and its
-- collections follow it, so nothing is lost. Errors come back as text for
-- CyberUI's own dialogs.

local DocSettings = require("docsettings")
local ReadCollection = require("readcollection")
local ReadHistory = require("readhistory")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local Books = require("cyberui/data/books")
local Library = require("cyberui/data/library")
local _ = require("cyberui/gettext")

local Files = {}

-- Does anything exist at `path`?
function Files.exists(path)
    return lfs.attributes(path, "mode") ~= nil
end

-- Is `path` a folder?
function Files.isDir(path)
    return lfs.attributes(path, "mode") == "directory"
end

-- The last part of a path.
function Files.name(path)
    local _dir, name = util.splitFilePathName(path:gsub("/+$", ""))
    return name
end

-- The folder a path is in, without a trailing slash.
function Files.parent(path)
    local dir = util.splitFilePathName(path:gsub("/+$", ""))
    return (dir:gsub("/+$", ""))
end

-- A file name with no folder parts and nothing a file system refuses.
local function cleanName(name)
    name = util.trim(name or "")
    if name == "" or name == "." or name == ".." or name:find("/", 1, true) then return nil end
    return name
end

-- Move or rename `from` to the full path `to`. Returns true, or nil and why.
function Files.move(from, to)
    if from == to then return true end
    if Files.exists(to) then
        return nil, string.format(_("There is already something called \u{201C}%s\u{201D} there."), Files.name(to))
    end
    local is_file = not Files.isDir(from)
    -- KOReader's history and collections keep fully resolved paths
    local real_from = ffiUtil.realpath(from) or from
    local ok = os.rename(from, to)
    if not ok then
        -- another storage (an SD card): let mv copy it across
        ok = ffiUtil.execute("/bin/mv", from, to) == 0
    end
    if not ok then return nil, _("It could not be moved.") end
    local real_to = ffiUtil.realpath(to) or to
    if is_file then
        DocSettings.updateLocation(from, to)
        ReadHistory:updateItem(real_from, real_to)
        ReadCollection:updateItem(real_from, real_to)
        Books.forget(from)
    else
        ReadHistory:updateItemsByPath(real_from, real_to)
        ReadCollection:updateItemsByPath(real_from, real_to)
    end
    Library.reset()
    return true
end

-- Rename `path` to `new_name` in the same folder. Returns the new path, or
-- nil and why.
function Files.rename(path, new_name)
    new_name = cleanName(new_name)
    if not new_name then return nil, _("That name cannot be used.") end
    local to = Files.parent(path) .. "/" .. new_name
    local ok, err = Files.move(path, to)
    if not ok then return nil, err end
    return to
end

-- Move `path` into folder `dir`. Returns the new path, or nil and why.
function Files.moveInto(path, dir)
    if dir == path or dir:sub(1, #path + 1) == path .. "/" then
        return nil, _("A folder cannot go inside itself.")
    end
    local to = dir .. "/" .. Files.name(path)
    local ok, err = Files.move(path, to)
    if not ok then return nil, err end
    return to
end

-- Make folder `name` in `dir`. Returns its path, or nil and why.
function Files.mkdir(dir, name)
    name = cleanName(name)
    if not name then return nil, _("That name cannot be used.") end
    local path = dir .. "/" .. name
    if Files.exists(path) then
        return nil, string.format(_("There is already something called \u{201C}%s\u{201D} here."), name)
    end
    if not lfs.mkdir(path) then return nil, _("The folder could not be made.") end
    Library.reset()
    return path
end

return Files
