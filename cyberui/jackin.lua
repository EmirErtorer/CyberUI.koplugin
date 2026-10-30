-- The jack-in card: what the screen shows while a book opens, in place of the
-- small "Opening file" message KOReader would draw over the screen. The load blocks,
-- so nothing on the card can move and it shows no made-up progress: the book
-- (cover, title, where reading resumes) and a striped "working" bar. It is
-- painted once, just before the load starts, and costs one small paint.

local Books = require("cyberui/data/books")
local Cover = require("cyberui/ui/cover")
local Deco = require("cyberui/ui/deco")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Settings = require("cyberui/settings")
local Theme = require("cyberui/theme")
local UIManager = require("ui/uimanager")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local lfs = require("libs/libkoreader-lfs")
local _ = require("cyberui/gettext")

local JackIn = {}

-- Is the card on, and is there a file to open?
function JackIn.wanted(path)
    return Settings.get("jack_in", true) and lfs.attributes(path, "mode") == "file"
end

-- The card for a book: a floating panel, shown over whatever screen the book
-- was opened from.
function JackIn.card(path)
    local th = Theme.get()
    local info, st = Books.info(path), Books.state(path)
    local lines = {
        Label:new({ text = info.title, kind = "display", lines = 3 }),
        Label:new({ text = info.author or "", kind = "body", color = "muted" }),
        Layout.Spacer:new({ height = th.space.s }),
        Label:new({ text = st.percent > 0 and string.format(_("RESUMING AT %d%%"), math.floor(st.percent * 100 + 0.5)) or _("FIRST OPEN"),
            kind = "mono" }),
        Label:new({ text = _("[OK] MOUNT FILE // [OK] READ INDEX"), kind = "mono_small", color = "muted" }),
        Label:new({ text = _("[..] RENDERING PAGE"), kind = "mono_small" }),
        Layout.Spacer:new({ height = th.space.s }),
        Deco.Stripes:new({ dir = "d", height = Theme.px(14), color = "ink" }),
    }
    return Panel:new({ shape = "header", title = _("JACK-IN"), title_right = _("DECRYPTING..."), pad = th.space.l, fill = "bg",
        width = math.min(require("device").screen:getWidth() - 2 * th.space.xl, Theme.px(560)),
        child = Layout.Row:new({ gap = th.space.l, valign = "stretch", children = {
            Cover:new({ path = path, width = Theme.px(112), height = Theme.px(164) }),
            Layout.Column:new({ grow = true, gap = th.space.xs, children = lines }),
        } }) })
end

-- Run show() (the call that opens the book) with KOReader's own "Opening file"
-- message kept off the screen, so the card stays alone. Anything else shown on
-- the way (a question about restoring the book's notes) is let through.
function JackIn.silenced(path, show)
    local abbreviated = filemanagerutil.abbreviate(path)
    local original = UIManager.show
    local function quiet(self, widget, ...)
        if widget and widget.timeout == 0 and type(widget.text) == "string" and widget.text:find(abbreviated, 1, true) then
            return
        end
        return original(self, widget, ...)
    end
    UIManager.show = quiet
    local ok, err = pcall(show)
    if UIManager.show == quiet then UIManager.show = original end
    if not ok then error(err, 0) end
end

return JackIn
