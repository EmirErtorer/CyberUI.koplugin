-- A book's dossier: cover and facts, progress, synopsis, annotation counts
-- and every action on the book (open, status, collections, folder, delete).

local Actions = require("cyberui/actions")
local App = require("cyberui/app")
local Books = require("cyberui/data/books")
local Button = require("cyberui/ui/button")
local Collections = require("cyberui/data/collections")
local Cover = require("cyberui/ui/cover")
local Format = require("cyberui/format")
local Frame = require("cyberui/screens/frame")
local History = require("cyberui/data/history")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Panel = require("cyberui/ui/panel")
local Progress = require("cyberui/ui/progress")
local Screen = require("cyberui/screens/screen")
local ScrollText = require("cyberui/ui/scrolltext")
local Theme = require("cyberui/theme")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local _ = require("gettext")

local Dossier = Screen:extend()

-- Reading status as the dossier names it.
local STATUS = { new = _("NEW"), reading = _("READING"), complete = _("DONE"), abandoned = _("ON HOLD") }

-- Highlights, notes and bookmarks saved for the book.
local function annotationCounts(path)
    local counts = { highlights = 0, notes = 0, bookmarks = 0 }
    if not Books.state(path).opened then return counts end
    local DocSettings = require("docsettings")
    local ok, ds = pcall(DocSettings.open, DocSettings, path)
    local list = ok and ds:readSetting("annotations") or {}
    for _i, a in ipairs(list) do
        if a.drawer then counts.highlights = counts.highlights + 1 else counts.bookmarks = counts.bookmarks + 1 end
        if a.note and a.note ~= "" then counts.notes = counts.notes + 1 end
    end
    return counts
end

-- A label / value pair for the facts table.
local function fact(k, v)
    return Layout.Row:new({ gap = Theme.get().space.s, children = {
        Label:new({ text = k, kind = "mono_small", color = "muted", width = Theme.px(64) }),
        Label:new({ text = v, kind = "mono_small", grow = true }),
    } })
end

-- Swipe up and down to page through a long synopsis.
function Dossier:onSwipe(dir)
    if not self.synopsis then return false end
    if dir == "north" then return self.synopsis:turn(1) end
    if dir == "south" then return self.synopsis:turn(-1) end
    return false
end

-- Build the dossier.
function Dossier:build()
    local th = Theme.get()
    self.synopsis_page = self.synopsis_page or {}
    local path = self.params.path
    local info, st = Books.info(path), Books.state(path)
    local dir, file = util.splitFilePathName(path)
    local ext = (file:match("%.([^.]+)$") or "?"):upper()
    local attr = lfs.attributes(path) or {}
    local who = info.author or _("Unknown author")
    if info.series then who = who .. " · " .. info.series .. (info.series_index and (" #" .. info.series_index) or "") end
    local held = Collections.holding(path)

    local head = Layout.Row:new({ gap = th.space.l, valign = "top", children = {
        Cover:new({ path = path, width = Theme.px(128), height = Theme.px(188) }),
        Layout.Column:new({ grow = true, gap = th.space.s, children = {
            Label:new({ text = info.title, kind = "display", lines = 3 }),
            Label:new({ text = who, kind = "body", color = "muted", lines = 2 }),
            fact(_("FORMAT"), ext .. " // " .. Format.size(attr.size)),
            fact(_("PAGES"), st.pages and tostring(st.pages) or (info.pages and tostring(info.pages)) or "?"),
            fact(_("ADDED"), attr.modification and os.date("%Y-%m-%d", attr.modification) or "?"),
            fact(_("OPENED"), Format.ago(History.lastOpened(path))),
            fact(_("CACHES"), #held > 0 and table.concat(held, ", ") or "—"),
        } }),
    } })

    local pct = math.floor(st.percent * 100 + 0.5)
    local progress = Layout.Column:new({ gap = th.space.xs, children = {
        Layout.Row:new({ children = {
            Label:new({ text = string.format(_("DECRYPTED %d%%"), pct), kind = "mono", grow = true }),
            Label:new({ text = STATUS[st.status] or "", kind = "mono", color = "muted" }),
        } }),
        Progress:new({ value = st.percent, segments = 30, book = true }),
    } })

    local synopsis = Panel:new({ shape = "brackets", label = _("SYNOPSIS"), pad = th.space.l, grow = true,
        child = ScrollText:new({ text = info.description and util.htmlToPlainTextIfHtml(info.description) or _("No description in this book's details."),
            color = info.description and "ink" or "muted", state = self.synopsis_page, on_turn = function() App.update() end }) })
    self.synopsis = synopsis.child

    local c = annotationCounts(path)
    local function count(n, label) return Button:new({ label = string.format("%02d", n), sub = label, kind = "number", grow = true, height = Theme.px(64) }) end
    local counts = Layout.Row:new({ gap = th.space.m, children = {
        count(c.highlights, _("HIGHLIGHTS")), count(c.notes, _("NOTES")), count(c.bookmarks, _("BOOKMARKS")),
    } })

    local done = st.status == "complete"
    -- after a rename or move the dossier follows the book to its new path
    local function moved(to) self.params.path = to; App.update() end
    local actions = Layout.Column:new({ gap = th.space.s, children = {
        Button:new({ label = _("OPEN FILE"), icon = "forward", variant = "primary", corners = "tb", on_tap = function() Actions.open(path) end }),
        Layout.Row:new({ gap = th.space.s, children = {
            Button:new({ label = done and _("MARK READING") or _("MARK DONE"), grow = true,
                on_tap = function() Actions.setStatus(path, done and "reading" or "complete") end }),
            Button:new({ label = _("COLLECTION +"), grow = true, on_tap = function() Actions.collect(path) end }),
        } }),
        Layout.Row:new({ gap = th.space.s, children = {
            Button:new({ label = _("SHOW FOLDER"), grow = true, on_tap = function() Actions.showFolder(path) end }),
        } }),
        Layout.Row:new({ gap = th.space.s, children = {
            Button:new({ label = _("RENAME"), icon = "edit", grow = true, on_tap = function() Actions.rename(path, moved) end }),
            Button:new({ label = _("MOVE TO"), icon = "move", grow = true, on_tap = function() Actions.move(path, moved) end }),
            Button:new({ label = _("DELETE"), icon = "trash", variant = "danger", grow = true,
                on_tap = function() Actions.delete(path, function() App.back() end) end }),
        } }),
    } })

    return Frame.page({
        screen = self, title = _("File dossier"), path = filemanagerutil.abbreviate(dir), tab = "library",
        body = Layout.Column:new({ gap = th.space.l, children = { head, progress, synopsis, counts, actions } }),
    })
end

return Dossier
