-- The page every skinned full-screen list is drawn on: the status bar, a header
-- with a back button, a title and its path, any action buttons, the rows, and
-- the paging row under them. A skin brings the rows and what each button does.

local Device = require("device")

local Screen = Device.screen

local Fullpage = {}

-- How much height is left for rows: the screen less the status bar, the header,
-- the paging row and the padding.
function Fullpage.room()
    local Theme = require("cyberui/theme")
    local th = Theme.get()
    return Screen:getHeight() - 2 * th.space.s - 4 * th.size.touch - 2 * th.space.m
end

-- The page from { title, path, on_back, actions = { buttons }, rows = { elements },
-- empty (what to say with no rows), page, pages, show(page) }.
function Fullpage.build(o)
    local Dialog = require("cyberui/ui/dialog")
    local Header = require("cyberui/ui/header")
    local Label = require("cyberui/ui/label")
    local Layout = require("cyberui/ui/layout")
    local Panel = require("cyberui/ui/panel")
    local StatusBar = require("cyberui/ui/statusbar")
    local Theme = require("cyberui/theme")
    local _ = require("cyberui/gettext")
    local th = Theme.get()
    local side = th.space.xl
    local kids = {
        StatusBar.build(),
        Header.build({ title = o.title, path = o.path, on_back = o.on_back, actions = o.actions }),
    }
    if #o.rows == 0 then
        kids[#kids + 1] = Label:new({ text = o.empty or _("No items"), kind = "body", color = "muted", align = "center", grow = true })
    else
        kids[#kids + 1] = Layout.Column:new({ grow = true, children = o.rows })
    end
    if (o.pages or 1) > 1 then kids[#kids + 1] = Dialog.pager(o.page, o.pages, o.show) end
    return Panel:new({ shape = "none", fill = "bg", pad = { th.space.s, side, th.space.m, side }, width = Screen:getWidth(), height = Screen:getHeight(),
        child = Layout.Column:new({ gap = th.space.m, children = kids }) })
end

return Fullpage
