-- The things a reader does with their operator profile: change or remove the
-- photo (picked from any folder of the device), edit the handle, and save the
-- card as a picture.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local IdCard = require("cyberui/ui/idcard")
local Layout = require("cyberui/ui/layout")
local Blitbuffer = require("ffi/blitbuffer")
local DataStorage = require("datastorage")
local Library = require("cyberui/data/library")
local Paint = require("cyberui/gfx/paint")
local Profile = require("cyberui/data/profile")
local Settings = require("cyberui/settings")
local Theme = require("cyberui/theme")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local _ = require("cyberui/gettext")

local ProfileFlow = {}

-- Picture types KOReader can draw.
local PICTURES = { png = true, jpg = true, jpeg = true, gif = true, bmp = true, webp = true }

-- Pick a picture anywhere on the device (starting in the library), frame it
-- in the photo window and keep it as the photo; after() runs when that is done.
function ProfileFlow.pickPhoto(after)
    if type(after) ~= "function" then after = nil end
    App.push("filepick", { dir = Library.home(), title = _("Photo"), exts = PICTURES, on_pick = function(path)
        App.push("photocrop", { path = path, on_done = function(ok, err)
            App.pop()
            App.pop()
            App.toast(ok and _("Photo changed") or err)
            App.update()
            if after then after() end
        end })
    end })
end

-- The photo sheet: choose a picture from the device, or go back to the glyph.
function ProfileFlow.photo(after)
    if type(after) ~= "function" then after = nil end   -- a tap hands over the element instead
    local actions = { { icon = "image", label = _("Choose a picture"), sub = _("From any folder on this device"),
        on_tap = function() ProfileFlow.pickPhoto(after) end } }
    if Profile.hasPhoto() then
        actions[#actions + 1] = { icon = "trash", label = _("Remove photo"), sub = _("Use the generated glyph"), danger = true, on_tap = function()
            Profile.clearPhoto()
            App.toast(_("Photo removed"))
            App.update()
            if after then after() end
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

-- The card floating over the screen, with its ways to change it. Each one
-- closes the card and brings it back when it is done.
function ProfileFlow.card()
    local th = Theme.get()
    App.dialog(function(close, screen_w)
        local function then_card(fn) return function() close(); fn(ProfileFlow.card) end end
        local footer = Layout.Row:new({ gap = th.space.s, children = {
            Button:new({ icon = "image", label = _("PHOTO"), variant = "soft", grow = true, on_tap = then_card(ProfileFlow.photo) }),
            Button:new({ icon = "edit", label = _("HANDLE"), variant = "soft", grow = true, on_tap = then_card(ProfileFlow.editHandle) }),
            Button:new({ icon = "download", label = _("SAVE"), variant = "soft", grow = true, on_tap = function()
                local file, err = ProfileFlow.export(IdCard.full({}))
                App.toast(file and string.format(_("Saved %s"), file:match("[^/]+$")) or err)
            end }),
            Button:new({ icon = "close", variant = "icon", width = th.size.touch, on_tap = close }),
        } })
        return IdCard.full({ width = math.min(screen_w - 2 * th.space.xl, Theme.px(560)), footer = footer,
            on_photo = then_card(ProfileFlow.photo), on_handle = then_card(ProfileFlow.editHandle) })
    end)
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
