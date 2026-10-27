# Changelog

All notable changes to CyberUI are listed here, newest first. Versions follow
[Semantic Versioning](https://semver.org), and the format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Each version's download
is on its [GitHub release](https://github.com/EmirErtorer/CyberUI.koplugin/releases);
versions marked *Prerelease* are test builds.

## [Unreleased]

### Added
- A size setting for the covers in the recent list on home (System > Home >
  Recent covers): S, as before, up to XL.

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

[Unreleased]: https://github.com/EmirErtorer/CyberUI.koplugin/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/EmirErtorer/CyberUI.koplugin/releases/tag/v1.0.0
