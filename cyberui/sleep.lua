-- The ASCII sleep screen: whatever sleep screen KOReader is set to show is
-- drawn as character art, as chosen in System > Covers: book covers only
-- (the default), custom and random images only, everything (also the book
-- status page, reading progress and other plugins' sleep screens), or off.
-- KOReader builds its sleep screen as a main picture with the message and
-- any overlay message on top; only the main picture is redrawn, so those
-- messages stay crisp text, and it is still a single screen refresh.

local Settings = require("cyberui/settings")
local _ = require("cyberui/gettext")

local Sleep = {}

-- The choices, in menu order.
Sleep.MODES = {
    { id = "covers", name = _("Book covers") },
    { id = "images", name = _("Custom images") },
    { id = "all", name = _("Everything") },
    { id = "off", name = _("Off") },
}

local installed = false

-- The chosen mode (an older on/off setting turned off means off).
function Sleep.mode()
    local m = Settings.get("ascii_sleep_mode")
    if m then return m end
    return Settings.get("ascii_sleep", true) == false and "off" or "covers"
end

-- Is this sleep screen one the mode redraws?
local function wanted(saver_type, mode)
    if mode == "all" then return true end
    if mode == "covers" then return saver_type == "cover" end
    if mode == "images" then return saver_type == "random_image" end
    return false
end

-- The main picture inside the sleep screen's layers, and the layer holding
-- it (nil when it is the top widget). Messages sit above it in the layers.
local function mainOf(widget)
    local OverlapGroup = require("ui/widget/overlapgroup")
    local parent, w = nil, widget
    while w and getmetatable(w) == OverlapGroup do parent, w = w, w[1] end
    return w, parent
end

-- Draw the main picture as ASCII and put it in its place.
local function redraw(widget, holder, see_through)
    local Blitbuffer = require("ffi/blitbuffer")
    local Screen = require("device").screen
    local ImageWidget = require("ui/widget/imagewidget")
    local w, h = Screen:getWidth(), Screen:getHeight()
    local main, parent = mainOf(widget)
    -- a message alone (no picture under it) stays as it is
    if not main or main.vertical_position then return end
    -- drawn on white and on black: where the two differ the picture is
    -- see-through (a transparent PNG), and the art leaves those parts empty
    local bb = Blitbuffer.new(w, h, Screen.bb:getType())
    bb:fill(Blitbuffer.COLOR_WHITE)
    main:paintTo(bb, 0, 0)
    local on_black = Blitbuffer.new(w, h, Screen.bb:getType())
    on_black:fill(Blitbuffer.COLOR_BLACK)
    main:paintTo(on_black, 0, 0)
    local title
    local lastfile = G_reader_settings:readSetting("lastfile")
    if lastfile then title = require("cyberui/data/books").info(lastfile).title end
    -- see-through parts show the screen as it is (the book, or home)
    local art, transparent = require("cyberui/gfx/ascii").render(bb, w, h,
        { size = 9, title = title, on_black = see_through and on_black or nil, backdrop = see_through and Screen.bb or nil })
    bb:free()
    on_black:free()
    if main.free then main:free() end
    local image = ImageWidget:new({ image = art, image_disposable = true, width = w, height = h, alpha = transparent })
    if transparent then holder.background = nil end
    if parent then parent[1] = image else holder.widget = image end
end

-- Redraw KOReader's sleep screen as it is about to be shown (once per start).
function Sleep.install()
    if installed then return end
    installed = true
    local Screensaver = require("ui/screensaver")
    local ScreenSaverWidget = require("ui/widget/screensaverwidget")
    local show = Screensaver.show
    Screensaver.show = function(saver, ...)
        local mode = Sleep.mode()
        if not wanted(saver.screensaver_type, mode) then return show(saver, ...) end
        -- KOReader wipes the screen to its sleep background before drawing an
        -- image; skipped here (its anti-ghosting refresh stays), as the art
        -- covers the screen, or shows it through a transparent picture
        saver.screensaver_background = "none"
        local new = ScreenSaverWidget.new
        ScreenSaverWidget.new = function(cls, o)
            if o and o.widget then
                -- only custom images can be see-through; a book cover drawn
                -- smaller than the screen just has margins
                local ok, err = pcall(redraw, o.widget, o, saver.screensaver_type == "random_image")
                if not ok then require("logger").warn("CyberUI sleep screen:", err) end
            end
            return new(cls, o)
        end
        local ok, err = pcall(show, saver, ...)
        ScreenSaverWidget.new = new
        if not ok then error(err) end
    end
end

return Sleep
