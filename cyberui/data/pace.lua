-- How long a page must stay on screen to count as read, so that eddies pay for
-- reading and not for turning pages, whatever the font size or reading speed.
--
-- A book with text is measured once: a few pages are read for their words when
-- it is first followed, giving the words in the whole book. A page then counts
-- when it stayed long enough to be read at READ_WPM words a minute, far faster
-- than anyone reads; the words on a page follow from the words in the book and
-- the page count, so a change of font size needs no new measuring. Page turns
-- themselves do no more than a subtraction and a comparison.
--
-- A book with too little text to measure (comics, scans, picture books) is
-- judged by the reader's own pace in it instead: a page counts when it stayed
-- at least a third of the reader's usual time per page there.

local Pace = {}

Pace.READ_WPM = 1500      -- no reader takes in more words a minute than this
Pace.WORDS_FLOOR = 1.5    -- seconds: the least any page with text needs
Pace.PACE_FLOOR = 2       -- seconds: the least a picture page needs
Pace.PACE_SHARE = 1 / 3   -- of the usual time per page, for a picture page
Pace.WINDOW = 25          -- the last this many pages make the usual time
Pace.SAMPLES = { 0.15, 0.35, 0.5, 0.65, 0.85 }   -- where in the book pages are measured
Pace.TEXT_MIN = 15        -- fewer words on a measured page than this: a picture book
Pace.SHORTEST = 0.5       -- seconds: a page shown less than this was passed on the way (a jump, a re-render)
Pace.LONGEST = 600        -- seconds: a page shown longer than this was left (not a reading time)

-- The words in a piece of text: runs of non-spaces, and each Chinese or
-- Japanese character (those scripts do not space their words).
function Pace.countWords(text)
    if type(text) ~= "string" or text == "" then return 0 end
    local cjk = 0
    local rest = text:gsub("[\227-\233][\128-\191][\128-\191]", function() cjk = cjk + 1; return " " end)
    local words = cjk
    for _w in rest:gmatch("%S+") do words = words + 1 end
    return words
end

-- The words on page `page` of an open document, or nil when it cannot say.
local function pageWords(doc, page, total)
    if type(doc.getPageXPointer) == "function" and type(doc.getTextFromXPointers) == "function" then
        -- (a reflowing book: the text from the top of this page to the top of the next)
        local from = doc:getPageXPointer(page)
        local to = page < total and doc:getPageXPointer(page + 1) or nil
        if not (from and to) then return nil end
        local text = doc:getTextFromXPointers(from, to)
        if type(text) == "table" then text = text.text end
        return Pace.countWords(text)
    end
    if type(doc.getPageTextBoxes) == "function" then
        -- (a page layout: the words the page's text layer holds, line by line)
        local boxes = doc:getPageTextBoxes(page)
        if type(boxes) ~= "table" then return 0 end
        local words = 0
        for _i, line in ipairs(boxes) do
            if type(line) == "table" then words = words + #line end
        end
        return words
    end
    return nil
end

-- The middle value of a list of numbers (nil for none).
local function median(list)
    if #list == 0 then return nil end
    local sorted = {}
    for i, v in ipairs(list) do sorted[i] = v end
    table.sort(sorted)
    local mid = (#sorted + 1) / 2
    return (sorted[math.floor(mid)] + sorted[math.ceil(mid)]) / 2
end

-- Measure an open document once: the words in the whole book (0 when it has
-- too little text to go by), or nil when it could not be read at all.
function Pace.measure(doc)
    local ok, words = pcall(function()
        local total = doc:getPageCount()
        if not total or total < 2 then return nil end
        local counts = {}
        for _i, at in ipairs(Pace.SAMPLES) do
            local page = math.max(1, math.min(total - 1, math.floor(total * at + 0.5)))
            local n = pageWords(doc, page, total)
            if n then counts[#counts + 1] = n end
        end
        local per = median(counts)
        if not per then return nil end
        if per < Pace.TEXT_MIN then return 0 end
        return math.floor(per * total + 0.5)
    end)
    return ok and words or nil
end

-- A fresh pace for a book: `words` in it as measured before (0 for a picture
-- book, nil when not measured yet).
function Pace.new(words)
    return { words = words, times = {} }
end

-- The seconds a page must stay on screen to count, with the book at `total`
-- pages. `unsettled` says the book is being laid out anew (KOReader lays out
-- the part on screen first after a change of font and the rest later, keeping
-- the old page count meanwhile): its pages are then judged by the floor alone.
function Pace.need(p, total, unsettled)
    if unsettled and p.words and p.words > 0 then return Pace.WORDS_FLOOR end
    if p.words and p.words > 0 and total and total > 0 then
        return math.max(Pace.WORDS_FLOOR, p.words / total * 60 / Pace.READ_WPM)
    end
    local usual = median(p.times)
    return math.max(Pace.PACE_FLOOR, usual and usual * Pace.PACE_SHARE or 0)
end

-- Note how long a page stayed (the usual time is made of these). Returns
-- whether it was a reading time at all (not a page passed on the way, not one left).
function Pace.note(p, seconds)
    if seconds < Pace.SHORTEST or seconds > Pace.LONGEST then return false end
    p.times[#p.times + 1] = seconds
    if #p.times > Pace.WINDOW then table.remove(p.times, 1) end
    return true
end

-- Which rule judges this book: "words", "pace", or nil while it is still to be measured.
function Pace.mode(p)
    if p.words == nil then return nil end
    return p.words > 0 and "words" or "pace"
end

return Pace
