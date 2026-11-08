-- KOReader's book status page (the one that opens at the end of a book, or from
-- the menu) in CyberUI's style: the cover, title and how far you are, the rating,
-- the reading statistics, your review and the status. KOReader keeps the rating,
-- the review and the status in the book's settings and changes them through
-- its own methods, which the taps here call; its own page is just not drawn.

local Core = require("cyberui/skin/core")

local Skin = {}

-- The statuses KOReader knows, as its switch gives them (named in KOReader's own words).
local STATUSES = { "reading", "abandoned", "complete" }

-- Is this KOReader's book status page?
local function takes(widget)
    return require("cyberui/skin/anatomy").is(widget, "ui/widget/bookstatuswidget") and type(widget.summary) == "table"
        and widget.ui ~= nil and widget.ui.document ~= nil
end

-- The cover, then the title, the authors and the progress bar.
local function bookBlock(widget)
    local Cover = require("cyberui/ui/cover")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Progress = require("cyberui/ui/progress")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    local th = Theme.get()
    local props = widget.ui.doc_props or {}
    local fraction = math.max(0, math.min(1, (widget.ui:getCurrentPage() or 0) / math.max(1, widget.total_pages or 1)))
    local text = Layout.Column:new({ gap = th.space.s, grow = true, children = {
        Label:new({ text = tostring(props.display_title or ""), kind = "title", lines = 3 }),
        Label:new({ text = tostring(props.authors or ""), kind = "small", color = "muted", lines = 2 }),
        Progress:new({ value = fraction, segments = 20, cell_h = 12, color = "accent" }),
        Label:new({ text = string.format(_("%d%% READ"), math.floor(fraction * 100 + 0.5)), kind = "mono_small", color = "muted" }),
    } })
    return Layout.Row:new({ gap = th.space.l, children = {
        Cover:new({ path = widget.ui.document.file, width = Theme.px(110), height = Theme.px(160) }), text } })
end

-- The five stars: filled up to the rating; a tap gives the rating (KOReader takes the first star
-- again as no rating).
local function stars(widget, state)
    local Button = require("cyberui/ui/button")
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    local rating = widget.summary.rating or 0
    local row = {}
    for i = 1, 5 do
        row[i] = Button:new({ label = i <= rating and "\u{2605}" or "\u{2606}", kind = "display", variant = i <= rating and "chip_on" or "chip", grow = true,
            height = Theme.px(56), disabled = widget.readonly,
            on_tap = not widget.readonly and function()
                Core.quietly(widget.setStar, widget, i)
                state.redraw()
            end or nil })
    end
    return Layout.Row:new({ gap = Theme.get().space.s, children = row })
end

-- Days, time and pages read: tiles, as in the reading log.
local function statistics(widget)
    local Layout = require("cyberui/ui/layout")
    local StatTile = require("cyberui/ui/stattile")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    return Layout.Row:new({ gap = Theme.get().space.s, children = {
        StatTile(_("DAYS"), widget:getStatDays()),
        StatTile(_("TIME"), widget:getStatHours()),
        StatTile(_("PAGES READ"), widget:getStatReadPages()),
    } })
end

-- The review: what was written, or a nudge to write; a tap opens KOReader's dialog for it.
local function review(widget)
    local Label = require("cyberui/ui/label")
    local Panel = require("cyberui/ui/panel")
    local Theme = require("cyberui/theme")
    local gettext = require("gettext")
    local th = Theme.get()
    local note = widget.summary.note
    local has = note and #note > 0
    return Panel:new({ shape = "frame", pad = { th.space.m, th.space.m }, height = Theme.px(130),
        on_tap = not widget.readonly and function() widget:openReviewDialog() end or nil,
        child = Label:new({ text = has and note or gettext("A few words about the book"), kind = "body", color = has and "ink" or "muted", lines = 5 }) })
end

-- The status: reading, on hold or finished.
local function status(widget, state)
    local Controls = require("cyberui/ui/controls")
    local gettext = require("gettext")
    local names = { gettext("Reading"), gettext("On hold"), gettext("Finished") }
    local options, current = {}, STATUSES[1]
    for i, id in ipairs(STATUSES) do
        options[i] = { names[i], id }
        if widget.summary.status == id then current = id end
    end
    return Controls.Segmented({ options = options, value = current, kind = "label", height = require("cyberui/theme").px(48), disabled = widget.readonly,
        on_change = function(id)
            for i, s in ipairs(STATUSES) do
                if s == id then widget:onChangeBookStatus(STATUSES, i) end
            end
            state.redraw()
        end })
end

-- The page as it is now.
local function build(widget, state)
    local Fullpage = require("cyberui/skin/fullpage")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    local function section(name, element)
        return Layout.Column:new({ gap = Theme.get().space.s, children = { Label:new({ text = name, kind = "micro", color = "muted" }), element } })
    end
    local gap = Layout.Spacer:new({ height = Theme.get().space.m })
    local rows = {
        bookBlock(widget), gap,
        section(_("// RATING"), stars(widget, state)), gap,
        section(_("// STATISTICS"), statistics(widget)), gap,
        section(_("// REVIEW"), review(widget)), gap,
        section(_("// STATUS"), status(widget, state)),
    }
    return Fullpage.build({ title = _("Book status"), on_back = function() widget:onClose() end, rows = rows })
end

Core.register({
    name = "bookstatus",
    matches = takes,
    present = function(widget)
        local state = {}
        state.redraw = function() Core.redraw(widget, build(widget, state)) end
        return {
            element = build(widget, state),
            place = function() return 0, 0 end,
            on_outside = function() end,
            on_back = function() widget:onClose(); return true end,
            on_swipe = function(dir) if dir == "south" then widget:onClose() end end,
        }
    end,
})

return Skin
