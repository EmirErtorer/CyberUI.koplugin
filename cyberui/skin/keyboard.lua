-- KOReader's on-screen keyboard in CyberUI's style, whatever layout the reader
-- chose (letters of any script, numbers, symbols, accents): the rows of keys
-- come from the keyboard itself, so each layout and each key KOReader adds is
-- drawn as it describes it. A tap runs the key's own tap, so shift, layers,
-- the language key and typing stay KOReader's; only the drawing is CyberUI's.
-- The popup of a key (its other letters, shown by holding it) is drawn the
-- same way.

local Anatomy = require("cyberui/skin/anatomy")
local Core = require("cyberui/skin/core")
local Device = require("device")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")

local Screen = Device.screen

local Skin = {}

-- KOReader draws a few keys with glyphs from its own symbol font, which
-- CyberUI's fonts lack: they become CyberUI icons.
local ICONS = { ["\u{E76D}"] = "backspace", ["\u{2190}"] = "back", ["\u{2192}"] = "forward", ["\u{2B90}"] = "forward" }

-- Is a key lit (shift or a symbol layer switched on)? KOReader paints such a key grey.
local function lit(key)
    local frame = key[1]
    local bg = frame and frame.background
    if not bg then return false end   -- (a colour is never compared with nil: that raises)
    return bg == require("ffi/blitbuffer").COLOR_LIGHT_GRAY
end

-- What a described key (a KOReader VirtualKey) shows and does, as a key of the grid.
-- `after` runs once its own tap has been run.
local function describe(key, after)
    local kb = key.keyboard or {}
    local label = key.label
    local k = {
        weight = key.width,
        kind = "mono",
        variant = lit(key) and "chip_on" or "soft",
        on_tap = function()
            key:onTapSelect(true)
            if after then after() end
        end,
    }
    local function has(set) return type(set) == "table" and (set[label] ~= nil or (key.key and set[key.key] ~= nil)) end
    if has(kb.shiftmode_keys) then
        k.label = "\u{21E7}"
        if k.variant ~= "chip_on" then k.variant = "secondary" end
    elseif has(kb.symbolmode_keys) then
        k.label = key.alt_label or "SYM"
        if k.variant ~= "chip_on" then k.variant = "secondary" end
    elseif has(kb.utf8mode_keys) then
        k.label = "\u{25CE}"
    elseif key.key == "\n" then
        k.icon = "forward"
        k.variant = "primary"
    elseif key.key == " " then
        k.label = "// " .. require("cyberui/gettext")("space") .. " //"
        k.kind = "mono_small"
        k.variant = "ghost"
    elseif ICONS[label] then
        k.icon = ICONS[label]
        if ICONS[label] == "backspace" then k.variant = "danger" end   -- the key that takes things away
    else
        k.label = label
        -- the digits are outlined plates, the letters filled ones
        if type(label) == "string" and label:match("^%d$") and k.variant == "soft" then k.variant = "chip" end
    end
    -- holding a key shows its other letters, placed by where the key is
    if key.hold_callback then
        k.on_hold = function(el)
            key.dimen = Geom:new({ x = el.x, y = el.y, w = el.w, h = el.h })
            key.hold_callback()   -- not onHoldSelect: its feedback repaints the key KOReader drew, which is not drawn
        end
    end
    return k
end

-- The grid of keys of a keyboard (or key popup): its rows, one entry per key.
local function grid(board, after)
    local Keyboard = require("cyberui/ui/keyboard")
    local Theme = require("cyberui/theme")
    local rows = {}
    for _i, row in ipairs(board.layout or {}) do
        local keys = {}
        for _j, key in ipairs(row) do keys[#keys + 1] = describe(key, after) end
        rows[#rows + 1] = keys
    end
    return Keyboard.grid(rows, { key_h = Theme.px(48) })
end

-- The keyboard docked to the bottom edge.
local function keyboard(vk, redraw)
    local Dialog = require("cyberui/ui/dialog")
    local Theme = require("cyberui/theme")
    local layout = vk.layout
    local th = Theme.get()
    local keys = grid(vk, function()
        if vk.layout ~= layout then redraw() end   -- a layer or language change made new keys
    end)
    -- a slim strip over the keys: what it is, and a handle that puts the keyboard away
    local Button = require("cyberui/ui/button")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local _ = require("cyberui/gettext")
    local strip = Layout.Row:new({ gap = th.space.s, pad = { 0, th.space.s }, children = {
        Label:new({ text = _("// KEYBOARD"), kind = "micro", color = "muted", grow = true }),
        Button:new({ label = _("HIDE"), icon = "down", variant = "chip", icon_size = 16, kind = "micro", height = Theme.px(34),
            on_tap = function() Skin.hide(vk) end }),
    } })
    return Dialog.docked({ strip, keys }, "bottom", Screen:getWidth(), th.space.s)
end

-- Put the keyboard away, as a tap beside it does: the window it types into stays.
function Skin.hide(vk)
    local parent = vk.inputbox and vk.inputbox.parent
    if parent and parent.onCloseKeyboard and not parent.deny_keyboard_hiding then
        parent:onCloseKeyboard()
    elseif vk.onClose then
        vk:onClose()
    end
end

Core.register({
    name = "keyboard",
    matches = function(widget) return Anatomy.is(widget, "ui/widget/virtualkeyboard") and widget.layout ~= nil end,
    present = function(vk)
        local function redraw() Core.redraw(vk, keyboard(vk, redraw)) end
        -- the keyboard rebuilds its keys on a layer or language change
        local add_keys = vk.addKeys
        vk.addKeys = function(self, ...)
            local r = add_keys(self, ...)
            if self._cyber_popup then redraw() end
            return r
        end
        local parent = vk.inputbox and vk.inputbox.parent
        local function relayout()
            if parent and parent._cyber_relayout then parent._cyber_relayout() end
        end
        return {
            element = keyboard(vk, redraw),
            under = function() return parent and parent._cyber_popup end,
            on_back = function() vk:onCloseWithKey(); return true end,
            on_shown = relayout,
            on_close = relayout,
        }
    end,
})

-- The other letters of a held key: a small card above the key.
Core.register({
    name = "keypopup",
    matches = function(widget) return widget.parent_key ~= nil and widget.layout ~= nil and Anatomy.is(widget, "ui/widget/virtualkeyboard") == false end,
    present = function(popup)
        local key = popup.parent_key
        local Panel = require("cyberui/ui/panel")
        local Theme = require("cyberui/theme")
        local th = Theme.get()
        local element = Panel:new({ shape = "chamfer", corners = "tb", fill = "bg", pad = th.space.s, child = grid(popup) })
        element.width = math.min(Screen:getWidth(), math.max(1, #(popup.layout[1] or {})) * Theme.px(72) + 2 * th.space.s)
        return {
            element = element,
            place = function(el)
                local x = math.max(0, math.min(key.dimen.x + math.floor(key.dimen.w / 2) - math.floor(el.w / 2), Screen:getWidth() - el.w))
                local y = math.max(0, key.dimen.y - el.h - th.space.s)
                return x, y
            end,
            on_outside = function() UIManager:close(popup) end,
        }
    end,
})

return Skin
