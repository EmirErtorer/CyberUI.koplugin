-- Base of every screen: holds its parameters and state between rebuilds.
-- A screen builds its element tree in build(ctx) and may handle onSwipe,
-- onRaise (shown again), onIndexed (library index ready) and onTick (each
-- minute, instead of the clock alone being redrawn).

local App = require("cyberui/app")

local Screen = {}
Screen.__index = Screen

-- Make a screen class.
function Screen:extend(cls)
    cls = cls or {}
    cls.__index = cls
    return setmetatable(cls, { __index = self })
end

-- Make a screen instance; init(params) sets up its state.
function Screen:new(params)
    local o = setmetatable({ params = params or {} }, self)
    if o.init then o:init(o.params) end
    return o
end

-- Back inside the screen (up a folder...); true when it handled it, false
-- to leave the screen.
function Screen:onBack()
    return false
end

-- Page left and right with swipes when the screen pages; true when used.
function Screen:onSwipe(dir)
    if not self.pages then return false end
    if dir == "west" then self:setPage(self.page + 1); return true end
    if dir == "east" then self:setPage(self.page - 1); return true end
    return false
end

-- Go to a page (clamped) and redraw.
function Screen:setPage(p)
    p = math.max(1, math.min(p, self.pages or 1))
    if p == self.page then return end
    self.page = p
    App.render("ui")
end

return Screen
