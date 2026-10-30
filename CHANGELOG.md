# Changelog

All notable changes to CyberUI are listed here, newest first. Versions follow
[Semantic Versioning](https://semver.org), and the format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Each version's download
is on its [GitHub release](https://github.com/EmirErtorer/CyberUI.koplugin/releases);
versions marked *Prerelease* are test builds.

## [Unreleased]

### Changed
- The skyline is redrawn as a city: towers of several styles with masts, lights
  and billboards over a pale far skyline; windows lit by time read.
- Touches made while KOReader is still closing a book are no longer pressed on
  home afterwards.
- The jack-in card floats over the screen the book was opened from instead of a
  blank one.
- The operator card floats over home, with Photo, Handle and Save under it.
- Choosing a photo opens the picture in a square window you drag and zoom
  before using it; see-through PNGs no longer turn black.
- A launcher button's target is picked from lists: plugins, plugin actions and
  KOReader's actions by kind, with the whole menu as the last way in.
- Holding a launcher button (on home or in the editor) asks before deleting it
  (built-in buttons are hidden instead).
- Long settings pages and the launcher editor page instead of being cut off.
- The log counts minutes or pages (button in its header), the log and stats
  tabs can draw their bars as a skyline, and the stats tab shows minutes and
  pages together.
- Telemetry numbers now come from one set of daily totals, so every tab agrees;
  "last 7 days" is named as such, the twelve-week grid lines up Monday to
  Sunday, the best streak is all-time, and a week in progress is compared with
  the same stretch of the week before. The hour axis is labelled at the right
  columns.

### Added
- Ten languages: Turkish, Brazilian Portuguese, Portuguese, Spanish, Italian, French,
  German, Russian, Polish and Greek. CyberUI follows KOReader's language; the texts
  are `.po` files in `l10n/` that can be edited without touching the code (your
  own edits go in `settings/cyberui-l10n/` and survive updates). A check in the test
  suite fails when any text is untranslated, so new features arrive translated.
- Keep the book open on Home (System > Speed, off by default): going home puts
  the book away instead of closing it, so the same book opens again in about a
  third of the time and nothing blocks after home is shown. KOReader closes it
  when a different book is opened, after 30 seconds untouched, or when KOReader's
  menu or file browser is opened. The setting lists what it costs.

- Operator ID card: a handle, a rank earned from reading hours, an ID code with
  a barcode, your totals, and a photo chosen from any folder on the device
  (tap the face or PHOTO). Save the card as a picture. Your face, handle and
  rank sit in the banner on home; tap the face to open the card.
- Jack-in card: a card with the book shown while it opens, in place of
  KOReader's small opening message (System > Home > Jack-in card).
- Gigs: books you never opened become paid work after a week, priced by
  length and how long they waited (€$20 steps, up to double). Opening one takes
  the gig; every 10% you read pays a twentieth of the price and finishing pays
  the other half. Your eddies balance sits on the ID card; the ledger is
  signed, so editing the settings file does not add money. A Gigs button on
  home, with open, active and payout lists.
- Data shards: every highlight in your books as a recovered fragment, with a
  shard on home (on by default, System > Home > Data shard turns it off), a Shards screen, and a way to open the book at the highlight.
- Skyline chart: a month of reading as a night city on the calendar tab, and
  the year by week on the goal tab.
- Colour dial for the custom scheme: hue ring, saturation and brightness
  matrix, a grey preview and a note on whether the colour reads on the page.
- The icon picker also offers KOReader's own icons.

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

[Unreleased]: https://github.com/EmirErtorer/CyberUI.koplugin/compare/v1.0.5...HEAD
[1.0.5]: https://github.com/EmirErtorer/CyberUI.koplugin/releases/tag/v1.0.5
[1.0.0]: https://github.com/EmirErtorer/CyberUI.koplugin/releases/tag/v1.0.0
