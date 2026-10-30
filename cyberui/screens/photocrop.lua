-- Framing a picture for the photo: the picture is shown in a square window
-- the reader drags and zooms, so they see what they are choosing and how it
-- will sit. params: { path, on_done(ok, reason) }.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Controls = require("cyberui/ui/controls")
local Frame = require("cyberui/screens/frame")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local PhotoWindow = require("cyberui/ui/photowindow")
local Profile = require("cyberui/data/profile")
local Screen = require("cyberui/screens/screen")
local Theme = require("cyberui/theme")
local _ = require("gettext")

local PhotoCrop = Screen:extend()

-- Read the picture; the window is made when the screen is first built (it
-- needs the room there is).
function PhotoCrop:init(params)
    self.img, self.err = Profile.load(params.path, Profile.PHOTO_MAX)
end

-- The window's side for the room there is: most of the width, at most about
-- half of the height (beside the controls on a wide screen).
local function windowSide()
    local screen = require("device").screen
    local th = Theme.get()
    local w, h = screen:getWidth(), screen:getHeight()
    if w > h then return math.floor(math.min(h * 0.62, w * 0.5)) end
    return math.floor(math.min(w - 4 * th.space.xl, h * 0.5))
end

-- Give the picture's memory back.
function PhotoCrop:release()
    if self.win then self.win:release(); self.win = nil
    elseif self.img then self.img:free() end
    self.img = nil
end

-- Leaving by Back frees the picture.
function PhotoCrop:onBack()
    self:release()
    return false
end

-- Keep what is in the window as the photo.
function PhotoCrop:use()
    local x, y, side = self.win:crop()
    local ok, err = Profile.savePhoto(self.win.img, x, y, side)
    self:release()
    self.params.on_done(ok, err)
end

-- Build the screen.
function PhotoCrop:build()
    local th = Theme.get()
    if not self.img then
        return Frame.page({ screen = self, title = _("Photo"), path = "PICK // FRAME", tab = "settings",
            body = Label:new({ text = self.err or _("Nothing to show"), kind = "body", lines = 3 }) })
    end
    if not self.win then
        local side = windowSide()
        self.win = PhotoWindow:new({ img = self.img, size = side, width = side, height = side })
    end
    local win = self.win
    local percent = math.floor(win.zoom / (math.max(win.img:getWidth(), win.img:getHeight()) / math.min(win.img:getWidth(), win.img:getHeight())) * 100 + 0.5)
    local fill = math.max(win.img:getWidth(), win.img:getHeight()) / math.min(win.img:getWidth(), win.img:getHeight())
    local controls = Layout.Column:new({ grow = true, gap = th.space.m, children = {
        Label:new({ text = _("DRAG THE PICTURE TO MOVE IT"), kind = "mono_small", color = "muted", lines = 2 }),
        Layout.Row:new({ gap = th.space.m, valign = "center", children = {
            Label:new({ text = _("ZOOM"), kind = "micro", color = "muted" }),
            Controls.Stepper({ value = percent, min = math.floor(100 / fill), max = math.floor(win:maxZoom() / fill * 100), step = 20,
                format = function(v) return v .. "%" end,
                on_change = function(v) win:setZoom(v / 100 * fill); App.update() end }),
            Button:new({ label = _("CENTRE"), on_tap = function() win:centre(); App.update() end }),
        } }),
        Layout.Spacer:new({ grow = true }),
        Button:new({ label = _("USE THIS PHOTO"), icon = "check", variant = "primary", corners = "tb", on_tap = function() self:use() end }),
    } })
    local screen = require("device").screen
    local body
    if screen:getWidth() > screen:getHeight() then
        body = Layout.Row:new({ gap = th.space.xl, valign = "stretch", children = { win, controls } })
    else
        body = Layout.Column:new({ gap = th.space.m, children = {
            Layout.Row:new({ children = { Layout.Spacer:new({ grow = true }), win, Layout.Spacer:new({ grow = true }) } }), controls } })
    end
    return Frame.page({ screen = self, title = _("Frame your photo"), path = "PICK // FRAME", tab = "settings", body = body })
end

return PhotoCrop
