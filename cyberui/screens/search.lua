-- Search: the library browser over every book whose title, author or file
-- name matches the query. Opens the keyboard at once when there is no query.

local App = require("cyberui/app")
local Button = require("cyberui/ui/button")
local Library = require("cyberui/screens/library")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Search = Library:extend()

-- Start with the given query, or ask for one as soon as the screen is up.
function Search:init(params)
    Library.init(self)
    params.query = params.query or ""
    if params.query == "" then UIManager:nextTick(function() self:ask() end) end
end

-- Set the query and show its results.
function Search:setQuery(text)
    self.params.query = text or ""
    self.page = 1
    App.update()
end

-- Type a new query; the results follow every letter.
function Search:ask()
    App.input(_("Search the library"), self.params.query, function(text) self:setQuery(text) end, _("Search"),
        { placeholder = _("title, author or file name"), live = function(text) self:setQuery(text) end })
end

-- The query field: tap it to type a new search.
function Search:topRow()
    local q = self.params.query
    return Button:new({ label = "> " .. (q ~= "" and q or _("type to search")), kind = "mono", align = "left",
        variant = "secondary", on_tap = function() self:ask() end })
end

return Search
