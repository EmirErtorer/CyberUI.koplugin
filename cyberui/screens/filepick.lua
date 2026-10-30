-- Choosing a file from the device: the folders and the files of a kind (pictures)
-- in a paged list, starting where the caller says. Back goes up a folder until
-- the start, then leaves. params: { dir, title, exts = { png = true }, on_pick(path) }.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Files = require("cyberui/data/files")
local Format = require("cyberui/format")
local Frame = require("cyberui/screens/frame")
local Grid = require("cyberui/ui/grid")
local Label = require("cyberui/ui/label")
local Layout = require("cyberui/ui/layout")
local ListRow = require("cyberui/ui/listrow")
local Screen = require("cyberui/screens/screen")
local Theme = require("cyberui/theme")
local lfs = require("libs/libkoreader-lfs")
local _ = require("gettext")

local FilePick = Screen:extend()

-- Start at the first page of the starting folder.
function FilePick:init(params)
    self.page = 1
    self.dir = params.dir
    self.start = params.dir
end

-- The folders (first) and the wanted files in `dir`, by name.
local function entries(dir, exts)
    local folders, found = {}, {}
    local ok, iter, state = pcall(lfs.dir, dir)
    if ok then
        for name in iter, state do
            if name:sub(1, 1) ~= "." then
                local path = dir .. "/" .. name
                local attr = lfs.attributes(path)
                if attr and attr.mode == "directory" and not name:match("%.sdr$") then
                    folders[#folders + 1] = { name = name, path = path, dir = true }
                elseif attr and attr.mode == "file" and exts[(name:match("%.(%w+)$") or ""):lower()] then
                    found[#found + 1] = { name = name, path = path, size = attr.size }
                end
            end
        end
    end
    local function byName(a, b) return a.name:lower() < b.name:lower() end
    table.sort(folders, byName)
    table.sort(found, byName)
    for _i, f in ipairs(found) do folders[#folders + 1] = f end
    return folders
end

-- Show another folder from its first page.
function FilePick:cd(dir)
    self.dir, self.page = dir, 1
    App.update()
end

-- Up a folder while below the start; false (leave) at the start.
function FilePick:onBack()
    if self.dir ~= self.start and self.dir ~= "/" then
        self:cd(Files.parent(self.dir))
        return true
    end
    return false
end

-- Build the list.
function FilePick:build()
    local th = Theme.get()
    local params = self.params
    local up = Button:new({ icon = "up", variant = "icon", width = th.size.touch, disabled = self.dir == "/",
        on_tap = function() self:cd(Files.parent(self.dir)) end })
    local items = entries(self.dir, params.exts)
    local grid = Grid:new({
        grow = true, items = items, page = self.page, cols = 1, cell_h = Theme.px(54), gap = 0, row_gap = 0,
        make = function(e)
            return ListRow.build({ icon = e.dir and "folder" or "image", title = e.name, title_kind = "body",
                meta = e.dir and _("FOLDER") or Format.size(e.size),
                on_tap = function()
                    if e.dir then self:cd(e.path) else params.on_pick(e.path) end
                end })
        end,
        on_layout = function(_cap, pages, page) self.pages, self.page = pages, page end,
    })
    local body = { Label:new({ text = self.dir, kind = "mono_small", color = "muted" }), grid,
        Frame.pager(self, _("FILES"), function(p) self:setPage(p) end) }
    if #items == 0 then
        table.insert(body, 2, Label:new({ text = _("No pictures or folders here."), kind = "small", color = "muted" }))
    end
    return Frame.page({ screen = self, title = params.title or _("Choose a file"), path = "PICK // FILE", tab = "settings",
        actions = { up }, body = Layout.Column:new({ gap = th.space.m, children = body }) })
end

return FilePick
