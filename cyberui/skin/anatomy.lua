-- Reading what a KOReader widget is made of, without knowing its layout: the
-- text, the icon and the rows of buttons are found by what they are, wherever
-- the widget keeps them, so a button KOReader adds later is drawn too.

local Anatomy = {}

-- Is `widget` of the KOReader class in module `path`, or of one made from it?
-- (Only classes already loaded are asked, so a skin never loads a widget.)
function Anatomy.is(widget, path)
    local class = _G.package.loaded[path]
    if type(class) ~= "table" then return false end
    local mt = getmetatable(widget)
    while type(mt) == "table" do
        if mt.__index == class then return true end
        mt = getmetatable(mt.__index)
    end
    return false
end

-- The first part of `widget` (itself included) for which pred(part) is true,
-- looking through its numbered children and named containers.
function Anatomy.find(widget, pred)
    local seen = {}
    local function walk(t, depth)
        if type(t) ~= "table" or seen[t] or depth > 14 then return nil end
        seen[t] = true
        if pred(t) then return t end
        for i = 1, #t do
            local f = walk(t[i], depth + 1)
            if f then return f end
        end
        for _i, key in ipairs({ "child", "movable", "dialog_frame", "vgroup", "title_group", "text_group", "button_table", "buttontable" }) do
            local f = walk(t[key], depth + 1)
            if f then return f end
        end
        return nil
    end
    return walk(widget, 0)
end

-- The rows of buttons (each { text, callback, hold_callback, enabled... }) of a widget.
function Anatomy.buttons(widget)
    if type(widget.buttons) == "table" and #widget.buttons > 0 and type(widget.buttons[1]) == "table" then return widget.buttons end
    local table_ = Anatomy.find(widget, function(t) return type(t.buttons) == "table" and t.button_by_id ~= nil end)
    return table_ and table_.buttons or {}
end

-- The text a widget shows: its `text`, else the first text box it holds.
function Anatomy.text(widget)
    if type(widget.text) == "string" then return widget.text end
    local box = Anatomy.find(widget, function(t) return type(t.text) == "string" and t.face ~= nil end)
    return box and box.text or ""
end

-- The name of the icon a widget shows beside its text, or nil.
function Anatomy.icon(widget)
    if type(widget.icon) == "string" and widget.show_icon ~= false then return widget.icon end
    local part = Anatomy.find(widget, function(t) return type(t.icon) == "string" and t.alpha ~= nil end)
    return part and part.icon or nil
end

return Anatomy
