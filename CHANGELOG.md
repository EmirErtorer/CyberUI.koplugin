# Changelog

All notable changes to CyberUI are listed here, newest first. Versions follow
[Semantic Versioning](https://semver.org), and the format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Each version's download
is on its [GitHub release](https://github.com/EmirErtorer/CyberUI.koplugin/releases);
versions marked *Prerelease* are test builds.

## [1.3.2] - 2026-11-12

A hotfix for crashes with highlights in Chinese, Japanese and other scripts whose letters take several bytes.

### Fixed

- **KOReader crashed on start, or when opening Data shard, with highlights in Chinese, Japanese, Korean and other scripts.** A long highlight was cut in the middle of a letter and saved that way. Text is now cut only between whole letters, anything drawn drops broken bytes, and shards saved by an earlier version are mended when they load, so a device that was stuck restarting recovers by updating.
- The same cut in the selected-text menu and the edit-highlight dialog, which could break on long selections in those scripts.
- A window CyberUI does not restyle (the OPDS "Add catalog" form, for one) appeared behind the list it was opened from. It now opens in front.
- A warning in the log for every window shown from home, from the selected-text menu looking for a book that was not open.
- On colour screens, pop-ups refresh with the waveform made for colour, which should stop the washed-out, see-through look reported on the Kobo Clara Colour. This one is not yet checked on a device.

## [1.3.1] - 2026-11-09

### Fixed

- The reader's bottom settings panel: the step bars (line spacing and the other bars made of steps) did not react to taps. They now call KOReader's own control directly, so every step, the fine-tune and the "more" buttons work.

## [1.3.0] - 2026-11-09

Everything since 1.1.2: KOReader's own windows in CyberUI's style, a rebuilt book details page, eddies that pay for reading, and a lot of smaller fixes.

### Added
- **KOReader's own windows are in CyberUI's style.** Notices, questions, button menus, the on-screen keyboard and text entry, lists (contents, bookmarks, history), the selected-text menu, the edit-highlight dialog and the dictionary. Also the note and text viewer (paged text, icon and warning buttons), number, two-number, date and time pickers (big values with steps and a slider, columns for a clock), lists to choose one from, forms with several fields, information lists (book details, statistics), sorting windows (a step up and down on each row), the folder chooser (a Choose this folder button), progress windows, QR codes, the keyboard language picker, the Wi-Fi list (strength icons, secured or open, the connected network first, Disconnect and Edit) and the book status page. KOReader still builds and runs every one, and each stays where it was in front of or behind other windows; anything CyberUI does not know is shown as KOReader made it.
- **A switch for each kind of window.** **KOReader dialogs** in System > Home turns it all off and opens a page with a switch for notices and questions, the selected-text menu, button menus, keyboard and text entry, lists, the dictionary, pickers, viewers, the Wi-Fi list and the reader panels, so a problem with one kind can be switched off alone.
- **The keyboards can be put away.** A HIDE handle on the keyboard, and a tap beside it puts it away; in CyberUI's own typing panel the text stays, with Save and Cancel left, and a tap on the field brings the keyboard back. New key plates: cut corners that alternate along a row, outlined digits, a warning-coloured backspace, a bracketed space bar.
- **Gigs and eddies can be turned off** in System > Gigs, after three "are you sure" windows. Off, nothing pays, the Gigs tile becomes the shop and every look can be worn. Turned back on, any look that was not paid for goes back to the free one, and eddies and purchases are kept. The gig settings have their own tab.
- **Every book pays eddies**, not only gigs: about a tenth of an eddy per page, paid as you read and when you finish. Only books started from the beginning count.
- **A small board of gigs.** The board offers 5 unopened books at a time (3, 5 or 10 in System > Gigs), drawn at random and drawn anew every week (3, 7 or 14 days). Gigs pay two to four times the plain rate, and a book's price grows by a quarter per week it has waited, up to double after a month.
- **Roll a gig** for 20 eddies to swap it for another book (hold a gig on the board).
- **Series from the books' own details.** Collections has a Series switch listing every series found in the books' metadata (two or more books), each opening its books in series order.
- **Edit a book's details.** Title, authors, series, series number, genres and language, one row each. Changes are KOReader's own custom metadata, so the book file is untouched and KOReader and other plugins show them too.
- **Group the library by genre.** Group by > Genre uses the books' genres (a book with several appears under each).
- **Rename a collection.** Holding a collection offers Rename and Delete; saved filters and views follow the new name.
- **Highlights, notes and bookmarks pages.** The counters on a book's details are buttons: each opens a CyberUI list of that kind, newest first, and a tap on an item opens the book at that place.

### Changed
- **The book details page gives the synopsis the room.** Cover, title, author and series, genres and size, two small chips, then the whole synopsis, and one row at the bottom: Open (or Take gig) with Edit info and More. Rename, move, delete, forget and show folder moved into More.
- **Eddies are paid for reading, not for turning pages.** A page counts once it has been on screen for 15 seconds. Pictures and files under 50 pages no longer pay or appear as gigs, and a never-opened book's length is capped at 800 pages. Prices are exact: a 300-page book pays 30 eddies at the plain rate. Gigs already taken keep their price and what they paid.
- **The keyboard has accented capitals and a locked Shift.** The accented layer covers Portuguese, Spanish, French, German, Turkish and Polish letters and has its own Shift; tap it twice to lock it.
- **Buttons never lose their words or icons.** Button rows size to their labels and wrap (Cancel and Paste were being cut off), a button that has only an icon keeps it, known verbs (open, rename, delete) get icons and destructive ones the warning look, and plugin lists keep the glyphs, switches, arrows and small lines their entries carry (ZenOS's settings, for one).
- **Keyboards from other plugins keep working.** Keys that type a word (suggestions) keep their words.
- **The menu's lists are taller**, up to 80% of the screen; System > Home > Menu height sets 50, 65, 80 or 90%.
- **Lumen and tint are sliders** in the menu's Deck and Controls pages and in KOReader's frontlight window.
- **Saving the ID card asks where**, with a folder picker, and reports a folder that cannot be written to.
- **The settings panel and the selected-text menu in books are in CyberUI's style**, going back to KOReader's look with their switches.
- **Ink Away's quick menu opens as a CyberUI sheet** from its tab in the menu, docked at the top there and centred over a book, and its tab shows the pen.

### Fixed
- KOReader quit to the device's own system when a swipe began on the tab bar.
- In a book, KOReader's drop-down menu stayed over a plugin's dialog opened from it (Bookends' settings, for one); it now steps aside.
- The selected-text menu showed blank buttons on KOReader versions that build it differently; it is recognised on any KOReader and keeps every icon.

## [1.1.2] - 2026-11-01

### Changed
- Taking a gig needs the book to be on the board. "Not wanted" takes a book off the board for good and its slot stays empty until the board is drawn anew.
- A list of choices too long for the screen (the collections when adding a book to one, filters, and the like) is now split into pages with previous and next buttons, so every entry can be reached.

### Fixed
- On colour screens (Kindle Colorsoft, Kobo Clara Colour and the like) KOReader quit to the device's own system whenever night mode was on and CyberUI drew a book with a colour cover, and kept doing so at every start until the plugin was removed. Covers are now converted to the screen's pixel type before they are drawn inverted.
- CyberUI could freeze on a phone (a white screen, or stuck after opening it) while it looked through the whole storage for books. It no longer follows linked folders or Android's own data folder, and stops after a few thousand folders.
- With ZenOS running, its Home tab in the toolbar opened ZenOS's own library over CyberUI. It now goes to CyberUI home when CyberUI is the chosen home screen.

## [1.1.1] - 2026-10-31

### Fixed
- Choosing a folder no longer ends in "Something went wrong" and a crash. This hit
  Statistics scope (Add a folder), Library opens in, and moving books to a folder.

## [1.1.0] - 2026-10-31

Everything since 1.0.0, the 1.0.5 prerelease included. The big ones: an operator
ID card, Gigs that pay eddies for reading your backlog, a shop of looks to spend
them on, data shards, ten languages, and a home that comes back much faster.

### Added
- **Operator ID card**: a handle, a rank earned from your reading hours, an ID
  code with a barcode, your totals, eddies and a photo from the device (drag and
  zoom it into a square). Tap your face on home to open it; save it as a picture.
- **Gigs**: a book you never opened becomes paid work after a week, priced by its
  length and how long it waited. Opening it takes the gig; every 10% you read pays
  a twentieth of the price and finishing pays the other half, with a notice on
  home. Open, active and payout lists, and a Take gig button on the book's details.
- **Eddies and the Shop**: eddies come only from reading gigs and buy only looks:
  twenty styles in four categories (ID card frames, backdrops, handle flairs and
  jack-in cards), one free in each. Every style is previewed before you buy. The
  ledger is signed, so editing the settings file adds no eddies and unlocks nothing.
- **Data shards**: every highlight in your books as a recovered fragment, one on
  home, a Shards screen, and a way to open the book at the highlight.
- **Jack-in card**: a card with the book shown while it opens, in place of
  KOReader's small opening message (System > Home > Jack-in card).
- **Ten languages**: Turkish, Brazilian Portuguese, Portuguese, Spanish, Italian,
  French, German, Russian, Polish and Greek, following KOReader's language. The
  texts are `.po` files in `l10n/` you can edit without touching code (your edits
  go in `settings/cyberui-l10n/` and survive updates).
- **Keep the book open on Home** (System > Speed, on by default): going home puts
  the book away instead of closing it, so the same book opens again in about a
  third of the time and nothing blocks after home is shown.
- **Operator ID in KOReader's menu**, in a book too: CyberUI's tab has two pages, the ID card and
  the controls, in the order you choose (System > Home > Menu tab opens on). With
  ZenOS running it sits right after ZenOS's Controls and Launcher.
- **Diagnostics**: a see-through view of an e-reader's main board in the empty
  space under the readouts (SoC, memory, flash, power chip, radio, display and
  touch connectors, USB-C, battery and more), scaled to the room.
- **Editable home launcher**: hide, reorder, replace and add buttons, each with its
  own name, icon and target picked from lists of plugins, plugin actions and
  KOReader's own actions. The icon picker also offers KOReader's icons.
- **Library menu**: sort orders, grouping (author, series, status, format, date
  added), more filters, saved views, jump to a letter and selecting many books at
  once. An All books view lists every book of every folder, and you choose the
  folder the Library opens in.
- **Double tap to open** books in the library, and a way to remove a book from
  the history.
- **Any status on a book**, unread included.
- **A setting to stretch covers** to their frame, and a size for the covers in the
  recent list on home.
- **Telemetry tabs**: stats by week, month and year, streaks and records, a
  calendar, a yearly goal, a book's own reading facts, and a folder scope. Bars
  can be a night-city skyline, and the log counts minutes or pages.
- **Colour dial** for the custom scheme: hue ring, saturation and brightness
  matrix, a grey preview and a note on whether the colour reads on the page.
- **A quiet support note** at the end of System > About.
- **Annotate** in one tap: a tile on the Deck's Controls page, left of Restart,
  opens the book in Ink Away's annotation mode (the one being read, or the last
  one read), and "Annotate this book" sits in the reader's Tools menu (both appear
  when Ink Away is installed).
- **Delete a collection** by holding it on the Collections screen (Favorites stays).

### Changed
- The recent list on home shares its room between its rows, so a fourth or fifth
  row fits where it used to stop at three.
- Telemetry numbers come from one set of daily totals, so every tab agrees.
- Touches made while KOReader is still closing a book are no longer pressed on
  home afterwards.
- Holding a launcher button asks before deleting it (built-in buttons are hidden
  instead). Long settings pages and the launcher editor page instead of being cut off.

### Fixed
- Exit left KOReader running behind a frozen screen when CyberUI was open.
- KOReader 2025.10 crashed at start with CyberUI installed.
- Home flashed over the page when KOReader reloaded the open book in the
  background to apply a change.
- Leaving a book read in landscape with the Home gesture left home sideways and its buttons dead.
- Covers inverted along with the screen in night mode.
- Session log page counts: each page is counted once.
- Page-turn keys now page the screens and the menu.
- The drop-down menu left the page half painted after it closed.
- Taps inside the bottom bar no longer reach what is under it.
- The warmth stepper uses KOReader's 0 to 100 scale.
- Arabic and Hebrew text is shaped and set right to left.
- With Project: Title installed, the menu over home was missing every plugin's entries.
- Toggling the frontlight inside a book opened from CyberUI turned it on and straight off.
- A crash when a drag reached the photo window after it had closed.

## [1.0.5] - 2026-10-27 *Prerelease*

### Added
- A size setting for the covers in the recent list on home (System > Home >
  Recent covers): S, as before, up to XL.
- All books in the Library menu: every book of every folder in one list.

### Fixed
- Exit left KOReader running behind a frozen screen when CyberUI was open;
  it now quits.
- With Project: Title installed, the menu over home was missing the entries
  of every plugin, CyberUI's own included.
- Toggling the frontlight inside a book opened from CyberUI turned it on and
  straight off again.
- KOReader 2025.10 crashed at start with CyberUI installed (it looked up the
  home folder in a way only newer KOReader has).

## [1.0.0] - 2026-10-24

The first release.

### Home
- A cyberpunk home screen that opens at start and comes back whenever you
  close a book, even after a restart: a banner, the date with your reading
  streak and daily goal, the book you are reading with Resume, your recent
  books and a launcher to every section.
- Coming home from a book takes one paint: home shows first and KOReader
  closes the book behind it, about twice as fast as before and three times
  through KOReader's own Home action, which CyberUI takes over while it is
  your home. Add the "CyberUI home" action to any gesture.
- Tap a recent book to bring it into the active panel; open it from there.
- The banner says what you like: a set line, a greeting with your handle, a
  random highlight from your books, the device's status or your own text,
  with a top line of its own. Hold it to change it.
- An editable status bar: the tag on the left and up to six readouts (clock,
  date, battery, Wi-Fi, frontlight, processor, memory, storage, book progress,
  uptime) to add, move and remove. Only the clock, date, battery and Wi-Fi are
  read again each minute, and the bar redraws only when one changed.
- The book's progress as segments, an ASCII bar, a heartbeat trace, a scan
  line or an equalizer. Hold the bar to switch.

### Library
- A library browser: folders with breadcrumbs, grid or list, sort orders and
  status filters, folders shown as a stack under their first book's cover.
- Hold a book or folder to open, see details, mark it done, put it in
  collections, rename, move or delete it. Rename and move take the book's
  reading data along.
- A trash: deleted books and folders wait 30 days and go back where they were.
- Book details: cover, facts, progress, a paged synopsis and annotation counts.
- Search as you type, with CyberUI's own keyboard.
- Collections, a reading log and a Diagnostics screen: power cell, processor
  and memory, storage, Wi-Fi, screen and light, uptime, read once when it
  opens (Rescan for fresh readings).

### Look
- Colour schemes Mono, Graphite, Neon, Synthwave, Bloodline, Terminal and
  Amber, plus your own colours, each in light and dark and following KOReader's
  night mode. Greyscale screens get the grey schemes only.
- Fourteen cyberpunk font sets, among them Oxanium (the default), Orbitron,
  Michroma, VT323 and Press Start 2P, or any font installed on the device.
- ASCII covers by default, in colour on colour screens, in eight character
  sets with Braille the default. Image covers and title cards too, in four
  sizes.
- An ASCII sleep screen that redraws KOReader's own: book covers by default,
  or custom images, or everything. Transparent images let the book or home
  show through, and KOReader's message stays crisp text.
- Its own icon set, drawn for CyberUI.
- Dark screens refresh cleaner: a full refresh every two screens, and a small
  flash after a press.

### KOReader's menu
- KOReader's drop-down menu in CyberUI's style, over home and inside books,
  read live from KOReader so every setting and plugin entry is there. It
  drops from the top, takes up to half the screen and pages beyond that.
- A Deck tab first when ZenOS is not running: frontlight and warmth, Wi-Fi,
  night mode, rotate, restart and exit, with the device at a glance. With
  ZenOS running, its Controls and Launcher show as CyberUI tiles instead.

### Companions and updates
- Ink Away on the launcher: it opens when installed, and otherwise describes
  itself and installs from GitHub in one tap.
- CyberUI updates itself: System, About, Updates shows the newest release (and
  newer prereleases, if you want them) with its notes and installs it after
  checking the download. Once a day, only on Wi-Fi that is already on, it
  looks by itself and says so on home.

[Unreleased]: https://github.com/EmirErtorer/CyberUI.koplugin/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/EmirErtorer/CyberUI.koplugin/releases/tag/v1.1.1
[1.1.0]: https://github.com/EmirErtorer/CyberUI.koplugin/releases/tag/v1.1.0
[1.0.5]: https://github.com/EmirErtorer/CyberUI.koplugin/releases/tag/v1.0.5
[1.0.0]: https://github.com/EmirErtorer/CyberUI.koplugin/releases/tag/v1.0.0
