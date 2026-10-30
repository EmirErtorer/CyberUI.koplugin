-- The things a reader does with their operator profile: change or remove the
-- photo (picked from any folder of the device), edit the handle, and save the
-- card as a picture.

local App = require("cyberui/app")
local Blitbuffer = require("ffi/blitbuffer")
local DataStorage = require("datastorage")
local Library = require("cyberui/data/library")
local Paint = require("cyberui/gfx/paint")
local Profile = require("cyberui/data/profile")
local Settings = require("cyberui/settings")
local Theme = require("cyberui/theme")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local _ = require("gettext")

local ProfileFlow = {}

-- Picture types KOReader can draw.
local PICTURES = { png = true, jpg = true, jpeg = true, gif = true, bmp = true, webp = true }

-- Pick a picture anywhere on the device (starting in the library) and keep it
-- as the photo.
function ProfileFlow.pickPhoto()
    App.push("filepick", { dir = Library.home(), title = _("Photo"), exts = PICTURES, on_pick = function(path)
        local ok, err = Profile.setPhoto(path)
        App.pop()
        App.toast(ok and _("Photo changed") or err)
        App.update()
    end })
end

-- The photo sheet: choose a picture from the device, or go back to the glyph.
function ProfileFlow.photo()
    local actions = { { icon = "image", label = _("Choose a picture"), sub = _("From any folder on this device"), on_tap = ProfileFlow.pickPhoto } }
    if Profile.hasPhoto() then
        actions[#actions + 1] = { icon = "trash", label = _("Remove photo"), sub = _("Use the generated glyph"), danger = true, on_tap = function()
            Profile.clearPhoto()
            App.toast(_("Photo removed"))
            App.update()
        end }
    end
    App.sheet({ title = _("Your photo"), sub = _("Shown on your ID card"), cols = 1, actions = actions })
end

-- Ask for the reader's handle, then call after().
function ProfileFlow.editHandle(after)
    App.input(_("Your handle"), Settings.get("handle", ""), function(text)
        Settings.save("handle", util.trim(text or ""))
        if after then after() end
        App.update()
    end, _("Save"), { placeholder = Profile.handle() })
end

-- Save the card as a picture in KOReader's screenshots folder (`ProfileFlow.dir`
-- when a test sets one); `card` is the
-- full card element. Returns the file, or nil and a reason.
function ProfileFlow.export(card)
    local th = Theme.get()
    local dir = ProfileFlow.dir or (DataStorage:getDataDir() .. "/screenshots")
    lfs.mkdir(dir)
    local width = require("device").screen:getWidth() - 2 * th.space.xl
    card:layout(width, nil)
    local pad = th.space.xl
    local bb = Blitbuffer.new(width + 2 * pad, card.h + 2 * pad, Blitbuffer.TYPE_BBRGB32)
    Paint.fill(bb, 0, 0, bb:getWidth(), bb:getHeight(), Theme.color("bg"))
    card:paint(bb, pad, pad)
    local file = string.format("%s/cyberui-id-%s.png", dir, Profile.id())
    local ok = pcall(bb.writePNG, bb, file)
    bb:free()
    if not ok then return nil, _("The card could not be saved") end
    return file
end

return ProfileFlow
