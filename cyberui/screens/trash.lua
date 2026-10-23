-- The trash: what was deleted, from where and when. Tap an item to put it
-- back or delete it for good; Empty clears everything. Items older than
-- Trash.KEEP_DAYS go by themselves when the trash is opened.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Format = require("cyberui/format")
local Frame = require("cyberui/screens/frame")
local Grid = require("cyberui/ui/grid")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local ListRow = require("cyberui/ui/listrow")
local Screen = require("cyberui/screens/screen")
local Theme = require("cyberui/theme")
local Trash = require("cyberui/data/trash")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local _ = require("gettext")

local TrashScreen = Screen:extend()

-- Clear out old items and start on the first page.
function TrashScreen:init()
    Trash.sweep()
    self.page = 1
end

-- Restore or delete one item.
local function itemSheet(it)
    App.sheet({ title = it.name, sub = string.format(_("From %s"), filemanagerutil.abbreviate(it.origin)), actions = {
        { icon = "restore", label = _("Put back"), on_tap = function()
            local to, err = Trash.restore(it.id)
            if not to then return App.confirm({ title = _("That did not work"), text = err, ok = _("OK") }) end
            App.toast(_("Put back"))
            App.update()
        end },
        { icon = "trash", label = _("Delete for good"), danger = true, on_tap = function()
            App.confirm({ danger = true, title = _("Attention"), detail = it.name, ok = _("Delete"), cancel = _("Keep"),
                text = _("It goes for good, with its reading data. This cannot be undone."),
                on_ok = function() Trash.purge(it.id); App.update() end })
        end },
    } })
end

-- Build the trash list.
function TrashScreen:build()
    local th = Theme.get()
    local items = Trash.list()
    local body = {}
    if #items == 0 then
        body[1] = Label:new({ grow = true, text = string.format(_("The trash is empty. Deleted books and folders wait here for %d days."),
            Trash.KEEP_DAYS), kind = "body", color = "muted", align = "center", lines = 3 })
    else
        body[1] = Grid:new({ grow = true, items = items, page = self.page, cols = 1, cell_h = Theme.px(58), row_gap = 0,
            make = function(it)
                return ListRow.build({ icon = it.dir and "folder" or "book", title = it.name,
                    meta = filemanagerutil.abbreviate(it.origin), value = Format.ago(it.time), on_tap = function() itemSheet(it) end })
            end,
            on_layout = function(_c, pages, page) self.pages, self.page = pages, page end })
    end
    body[#body + 1] = Frame.pager(self, _("BIN"), function(p) self:setPage(p) end)
    local actions = {}
    if #items > 0 then
        actions[1] = Button:new({ label = _("Empty"), variant = "danger", on_tap = function()
            App.confirm({ danger = true, title = _("Attention"), ok = _("Empty"), cancel = _("Keep"),
                text = string.format(_("All %d items go for good. This cannot be undone."), #items),
                on_ok = function() Trash.empty(); App.update() end })
        end })
    end
    return Frame.page({ screen = self, title = _("Trash"), path = string.format(_("KEPT %d DAYS"), Trash.KEEP_DAYS),
        tab = "library", actions = actions, body = Layout.Column:new({ gap = th.space.m, children = body }) })
end

return TrashScreen
