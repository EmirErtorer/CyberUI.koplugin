-- KOReader's dictionary window in CyberUI's style, in a book: the word, the dictionary and its definition, KOReader's own buttons
-- (next dictionary...), a tap that pages the definition, a hold that looks a word up, a tap outside that closes it.
local H = ...
local UIManager = require("ui/uimanager")
local S = 1.5
local ui, dict

H.step(1, function() H.app().openBook(require("cyberui/data/library").all()[1]) end)
H.step(5, function()
    ui = require("apps/reader/readerui").instance
    local long = {}
    for i = 1, 40 do long[#long + 1] = "Sense " .. i .. ": a fortunate discovery made by accident while looking for something quite different." end
    ui.dictionary:showDict("serendipity", {
        { dict = "Oxford Test Dictionary", word = "serendipity", definition = table.concat(long, "\n") },
        { dict = "Second Test Dictionary", word = "serendipity", definition = "The occurrence of events by chance in a happy way." },
    }, nil)
end)
H.step(S, function()
    for _i, e in ipairs(UIManager._window_stack) do if e.widget._cyber_popup and e.widget.definition then dict = e.widget end end
    H.check(dict ~= nil, "the dictionary window is drawn by CyberUI")
    H.check(H.find("serendipity") ~= nil and H.find("// LOOKUP") ~= nil, "it shows the word")
    H.check(H.find("1 / 2") ~= nil, "and the result counter")
    H.shot("1-dictionary")
    ui.dictionary.test_lookup = nil
    dict.lookupDictionaryOrWikipedia = function(_, word) dict._looked = word; return true end
    local body = H.findWhere(function(e) return e.all ~= nil and e.state ~= nil end)
    H.check(body ~= nil and body.pages > 1, "a long definition pages")
    H.tapAt(body.x + body.w - 10, body.y + 20)
end)
H.step(S, function()
    local body = H.findWhere(function(e) return e.all ~= nil and e.state ~= nil end)
    H.check(body.state.page == 2, "a tap on the right pages the definition")
    H.shot("2-dictionary-page2")
    -- hold on the first word of the first line
    H.holdAt(body.x + 20, body.y + 10)
end)
H.step(S, function()
    H.tap(nil, "forward")
end)
H.step(S, function()
    H.check(dict.dict_index == 2 and H.find("Second Test Dictionary") ~= nil, "the arrow after the dictionary's name goes to the next dictionary, through KOReader")
    H.check(H.find("1 / 2") ~= nil or H.find("2 / 2") ~= nil, "and the counter follows")
    H.tap(nil, "back")
end)
H.step(S, function()
    H.check(dict.dict_index == 1, "the arrow before it goes back")
    H.check(dict._looked ~= nil and dict._looked:find("^%a+") ~= nil, "holding on a word looks it up through KOReader: " .. tostring(dict._looked))
    H.swipe("west", 600, 700)
end)
H.step(S, function()
    H.check(dict.dict_index == 2 and H.find("Second Test Dictionary") ~= nil, "a swipe changes dictionary, through KOReader")
    H.shot("3-dictionary-second")
    H.tapAt(8, 8)
end)
H.step(S, function()
    H.check(not UIManager:isWidgetShown(dict) and dict._cyber_popup == nil, "a tap outside closes it, as in KOReader")
end)
