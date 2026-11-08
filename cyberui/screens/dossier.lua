-- A book's dossier: who the book is, the synopsis with the room that is left, the
-- saved highlights, notes and bookmarks as buttons to their lists, and the actions.

local Actions = require("cyberui/actions")
local Annotations = require("cyberui/data/annotations")
local App = require("cyberui/app")
local Books = require("cyberui/data/books")
local Button = require("cyberui/ui/button")
local Collections = require("cyberui/data/collections")
local Deco = require("cyberui/ui/deco")
local Cover = require("cyberui/ui/cover")
local Format = require("cyberui/format")
local Frame = require("cyberui/screens/frame")
local Gigs = require("cyberui/data/gigs")
local History = require("cyberui/data/history")
local Insights = require("cyberui/data/insights")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local Progress = require("cyberui/ui/progress")
local Screen = require("cyberui/screens/screen")
local ScrollText = require("cyberui/ui/scrolltext")
local Theme = require("cyberui/theme")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local _ = require("cyberui/gettext")

local Dossier = Screen:extend()

-- Reading status as the dossier names it.
local STATUS = { new = _("NEW"), reading = _("READING"), complete = _("DONE"), abandoned = _("ON HOLD") }

-- Swipe up and down to page through a long synopsis.
function Dossier:onSwipe(dir)
    if not self.synopsis then return false end
    if dir == "north" then return self.synopsis:turn(1) end
    if dir == "south" then return self.synopsis:turn(-1) end
    return false
end

-- One line of small grey facts.
local function line(text)
    return Label:new({ text = text, kind = "mono_small", color = "muted", lines = 2 })
end

-- Format, size and pages of the book on one line.
local function formatLine(path, info, st)
    local _dir, file = util.splitFilePathName(path)
    local ext = (file:match("%.([^.]+)$") or "?"):upper()
    local parts = { ext, Format.size((lfs.attributes(path) or {}).size) }
    local pages = st.pages or info.pages
    if pages then parts[#parts + 1] = string.format("%d PG", pages) end
    return table.concat(parts, " \u{B7} ")
end

-- When the book was added and last opened.
local function datesLine(path)
    local added = (lfs.attributes(path) or {}).modification
    return string.format(_("ADDED %s // OPENED %s"), added and os.date("%Y-%m-%d", added) or "?", Format.ago(History.lastOpened(path)))
end

-- How far the book is read: one line of numbers over the bar (nothing for a book not started).
local function progress(path, st)
    local th = Theme.get()
    local pct = math.floor(st.percent * 100 + 0.5)
    local text = string.format(_("DECRYPTED %d%%"), pct)
    local t = Insights.book(path)
    if t and t.seconds > 0 then
        local left = st.status == "complete" and 0 or math.max(0, t.total_pages - t.pages) * t.per_page
        text = text .. string.format(" // %s", Format.duration(t.seconds))
        if left > 0 then text = text .. string.format(_(" // %s LEFT"), Format.duration(left)) end
    end
    return Layout.Column:new({ gap = th.space.xs, children = {
        Label:new({ text = text, kind = "mono_small", lines = 2 }),
        Progress:new({ value = st.percent, segments = 30, book = true }),
    } })
end

-- Build the dossier: who the book is, the synopsis with all the room that is left, and a short row of actions.
function Dossier:build()
    local th = Theme.get()
    self.synopsis_page = self.synopsis_page or {}
    local path = self.params.path
    local info, st = Books.info(path), Books.state(path)
    local dir = util.splitFilePathName(path)
    local who = info.author or _("Unknown author")
    if info.series then who = who .. " \u{B7} " .. info.series .. (info.series_index and (" #" .. info.series_index) or "") end
    local held = Collections.holding(path)
    -- after a rename or move the dossier follows the book to its new path
    local function moved(to) self.params.path = to; App.update() end

    local chips = Layout.Row:new({ gap = th.space.s, children = {
        Button:new({ label = string.format("%s \u{B7} %s", _("STATUS"), STATUS[st.status] or ""), variant = "chip", kind = "mono_small",
            on_tap = function() Actions.statusSheet(path) end }),
        Button:new({ label = #held > 0 and string.format(_("CACHES \u{B7} %d"), #held) or _("+ CACHE"), variant = "chip", kind = "mono_small",
            on_tap = function() Actions.collect(path) end }),
    } })
    local facts = { Label:new({ text = info.title, kind = "display", lines = 3 }),
        Label:new({ text = who, kind = "body", color = "muted", lines = 2 }) }
    if info.genres and #info.genres > 0 then facts[#facts + 1] = line(table.concat(info.genres, " \u{B7} "):upper()) end
    facts[#facts + 1] = line(formatLine(path, info, st))
    facts[#facts + 1] = line(datesLine(path))
    facts[#facts + 1] = chips
    local head = Layout.Row:new({ gap = th.space.l, valign = "top", children = {
        Cover:new({ path = path, width = Theme.px(110), height = Theme.px(162) }),
        Layout.Column:new({ grow = true, gap = th.space.s, children = facts }),
    } })

    local synopsis = Layout.Column:new({ grow = true, gap = th.space.s, children = {
        Layout.Row:new({ gap = th.space.m, children = {
            Label:new({ text = _("SYNOPSIS"), kind = "micro", color = "muted" }),
            Deco.Divider:new({ grow = true }),
        } }),
        ScrollText:new({ grow = true, text = info.description and util.htmlToPlainTextIfHtml(info.description) or _("No description in this book's details."),
            color = info.description and "ink" or "muted", state = self.synopsis_page, on_turn = function() App.update() end }),
    } })
    self.synopsis = synopsis.children[2]

    -- the saved items as three buttons, each opening its list
    local kinds = Annotations.kinds(path)
    local function count(kind, label)
        return Button:new({ label = string.format("%02d", #kinds[kind]), sub = label, kind = "number", grow = true, height = Theme.px(64),
            on_tap = function() App.push("annotations", { path = path, kind = kind }) end })
    end
    local counts = Layout.Row:new({ gap = th.space.m, children = {
        count("highlights", _("HIGHLIGHTS")), count("notes", _("NOTES")), count("bookmarks", _("BOOKMARKS")),
    } })

    local offer = Gigs.offer(path)
    local main = offer
        and Button:new({ label = _("TAKE GIG"), sub = Format.credits(offer.price), icon = "forward", variant = "primary", corners = "tb", grow = true,
            on_tap = function() Actions.open(path) end })
        or Button:new({ label = _("OPEN FILE"), icon = "forward", variant = "primary", corners = "tb", grow = true, on_tap = function() Actions.open(path) end })
    local actions = Layout.Row:new({ gap = th.space.s, height = Theme.px(64), children = {
        main,
        Button:new({ label = _("EDIT INFO"), icon = "edit", variant = "tab", kind = "mono_small", on_tap = function() Actions.editDetails(path) end }),
        Button:new({ label = _("MORE"), icon = "menu", variant = "tab", kind = "mono_small", on_tap = function() Actions.moreSheet(path, moved) end }),
    } })

    local kids = { head }
    if st.opened then kids[#kids + 1] = progress(path, st) end
    kids[#kids + 1] = synopsis
    kids[#kids + 1] = counts
    kids[#kids + 1] = actions
    return Frame.page({
        screen = self, title = _("File dossier"), path = filemanagerutil.abbreviate(dir), tab = "library",
        body = Layout.Column:new({ gap = th.space.l, children = kids }),
    })
end

return Dossier
