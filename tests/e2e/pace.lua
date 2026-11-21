-- Eddies pay for reading, not for turning pages, on real books: an EPUB at
-- the usual font, the same kind of book in an enormous font, a PDF with a
-- text layer and a PDF of pictures. Each is opened and measured as on a
-- device, then its pages are turned through KOReader at different speeds on a
-- clock the scene controls. Needs HOME_SETUP=tests/e2e/setup_pace.sh.
local H = ...
local Event = require("ui/event")
local ReaderUI = require("apps/reader/readerui")
local Gigs = require("cyberui/data/gigs")
local Pace = require("cyberui/data/pace")
local Settings = require("cyberui/settings")
local time = require("ui/time")
local lfs = require("libs/libkoreader-lfs")

-- the scene's clock: pages stay exactly as long as each case says
local t = 1000
Gigs.clock = function() return t end

local dir = G_reader_settings:readSetting("home_dir")
local function find(pattern)
    for f in lfs.dir(dir) do if f:find(pattern, 1, true) then return dir .. "/" .. f end end
end
local books = {
    epub = find("Ailenin"), big = find("Kurt Kanunu"), pdf = find("Hunter-Gatherer"), pictures = find("Picture book"),
}

H.step(1, function()
    for k, v in pairs(books) do H.check(v ~= nil, "found the " .. k .. " book") end
    Settings.set("gigs", { quotes = {}, seen = {}, ledger = {} })
    Settings.save("gigs_on", true)
    Gigs.reload()
end)

-- Turn the open book's pages from `from` to `to` percent, each staying `secs`
-- seconds; then pay what was earned. Returns the earnings after.
local function read(path, from, to, secs)
    local ui = ReaderUI.instance
    local total = ui.document:getPageCount()
    local first, last = math.max(1, math.floor(total * from / 100) + 1), math.floor(total * to / 100)
    for p = first, last do
        ui:handleEvent(Event:new("GotoPage", p))
        t = t + secs
    end
    Gigs.settle()
    return Gigs.earnings(path), last - first + 1
end

-- Open a book and wait for it.
local function open(path) H.app().openBook(path) end

-- What the open book needs a page to stay, and how it is judged.
local function need()
    local e = Gigs.earnings(ReaderUI.instance.document.file)
    local total = ReaderUI.instance.document:getPageCount()
    local words = (Settings.get("gigs").pace or {})[ReaderUI.instance.document.file]
    words = words and words.words
    return Pace.need(Pace.new(words), total), e.mode, words, total
end

---------------------------------------------------------------- 1. EPUB, usual font
H.step(1, function() open(books.epub) end)
-- measured on its own, a moment after it opened (the real scheduled path)
H.step(5, function()
    local secs, mode, words, total = need()
    H.say(string.format("EPUB: %s words in %d pages, a page needs %.1f s", tostring(words), total, secs))
    H.check(mode == "words" and words and words > 10000, "the EPUB was measured once it opened: " .. tostring(words) .. " words")
    H.check(secs >= 4 and secs <= 20, "at the usual font a page needs a few seconds: " .. string.format("%.1f", secs))
    local e, n = read(books.epub, 0, 35, 20)
    H.check(e.milestones >= 3 and e.counted >= n - 1, "20 s a page (about 750 words a minute at most): the first three tenths pay; " .. e.counted .. " of " .. n .. " pages counted")
    local before = e.milestones
    local e2, n2 = read(books.epub, 35, 70, 2)
    H.check(e2.milestones == before and e2.quick >= n2 - 1, "2 s a page: skimming pays nothing more; " .. e2.quick .. " too quick")
end)

---------------------------------------------------------------- 2. EPUB, enormous font, fast reader
local before_total
H.step(1, function() open(books.big) end)
H.step(5, function()
    local ui = ReaderUI.instance
    H.check(ui and ui.document.file == books.big, "the second EPUB is open")
    before_total = ui.document:getPageCount()
    ui:handleEvent(Event:new("SetFontSize", 46))
end)
-- KOReader lays out the part on screen at once and keeps the old page count until the rest is done
H.step(1, function()
    local ui = ReaderUI.instance
    H.say("font changed: rendering state " .. tostring(ui.rolling.rendering_state) .. ", " .. ui.document:getPageCount() .. " pages")
    local e, n = read(books.big, 0, 35, 4)
    H.check(e.milestones >= 3, "while the book is laid out anew, a fast reader at 4 s a page earns the first three tenths: " .. e.counted .. " of " .. n)
end)
-- then it lays out the whole book in the background and reloads it
local waited = 0
local function settled()
    local ui = ReaderUI.instance
    return ui and ui.document and ui.rolling.rendering_state == nil and ui.document:getPageCount() > before_total
end
for _i = 1, 60 do
    H.step(1, function() if not settled() then waited = waited + 1 end end)
end
H.step(1, function()
    H.check(settled(), "KOReader laid the book out again in the bigger font (" .. waited .. " s)")
    local secs, mode, words, total = need()
    H.say(string.format("enormous font: %s words in %d pages (was %d), a page needs %.1f s", tostring(words), total, before_total, secs))
    H.check(mode == "words" and secs <= 3, "in the enormous font a page needs only a couple of seconds: " .. string.format("%.1f", secs))
    local e0 = Gigs.earnings(books.big).milestones
    local e = read(books.big, 35, 70, 4)
    H.check(e.milestones >= 6 and e.milestones > e0, "4 s a page goes on paying in the new layout: " .. e.milestones .. " tenths, " .. e.counted .. " counted")
    local e2 = read(books.big, 70, 100, 0.8)
    H.check(e2.milestones == e.milestones and not e2.finish_paid, "flipping at 0.8 s a page pays nothing more")
    H.shot("p01-enormous-font")
end)

---------------------------------------------------------------- 3. PDF with a text layer
H.step(1, function() open(books.pdf) end)
H.step(6, function()
    -- measured here by hand, timed (the scheduled measuring has already run or will be skipped)
    local doc = ReaderUI.instance.document
    local t0 = time.now()
    local words = Pace.measure(doc)
    H.say(string.format("PDF measured in %.1f ms: %s words", time.to_ms(time.since(t0)), tostring(words)))
    local secs, mode, kept, total = need()
    H.say(string.format("PDF: %s words in %d pages, a page needs %.1f s", tostring(kept), total, secs))
    H.check(mode == "words" and secs >= 3, "the PDF is judged by its words: " .. string.format("%.1f", secs) .. " s a page")
    local e, n = read(books.pdf, 0, 35, math.max(25, secs * 1.3))
    H.check(e.milestones >= 3, "reading the PDF (a little under the most a page needs) pays the first three tenths: " .. e.counted .. " of " .. n)
    local e2 = read(books.pdf, 35, 70, 3)
    H.check(e2.milestones == e.milestones, "3 s a page through the PDF pays nothing more")
end)

---------------------------------------------------------------- 4. PDF of pictures
H.step(1, function() open(books.pictures) end)
H.step(5, function()
    local _secs, mode, words = need()
    H.check(mode == "pace" and words == 0, "the picture PDF is judged by pace: " .. tostring(mode) .. ", " .. tostring(words) .. " words")
    local e, n = read(books.pictures, 0, 35, 8)
    H.check(e.milestones >= 3, "8 s a picture page pays the first three tenths: " .. e.counted .. " of " .. n)
    local e2 = read(books.pictures, 35, 70, 1)
    H.check(e2.milestones == e.milestones, "flicking at 1 s a page pays nothing more")
    H.say(string.format("pictures: a page needs %.1f s at the reader's pace", need()))
end)

---------------------------------------------------------------- the dossier and the Gigs page
H.step(1, function() H.event("CyberUIHome") end)
H.step(3, function()
    H.app().push("dossier", { path = books.pdf })
end)
H.step(2, function()
    H.check(H.findWhere(function(el) return type(el.text) == "string" and el.text:find("EDDIES // PLAIN RATE", 1, true) == 1 end) ~= nil, "the dossier shows the book's eddies")
    H.shot("p02-dossier")
    -- a tap on the eddies explains how the book's pages count
    local el = H.findWhere(function(e) return type(e.text) == "string" and e.text:find(" PAID", 1, true) ~= nil end)
    H.check(el ~= nil, "the eddies summary is on the dossier")
    if el then H.tapAt(el.x + el.w / 2, el.y + el.h / 2) end
end)
H.step(1.5, function()
    H.check(H.find("How pages count") ~= nil, "a tap on the eddies explains how the pages count")
    H.shot("p02b-explained")
    H.app().closeDialog()
    H.app().push("gigs")
end)
H.step(2, function()
    local s = H.app().current()
    s.tab, s.page = "active", 1
    H.app().update()
end)
H.step(2, function()
    H.check(#Gigs.active() == 4, "the Active tab lists every book paying, gigs or not: " .. #Gigs.active())
    H.shot("p03-gigs-active")
end)
