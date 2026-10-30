# Contributing to CyberUI

Thanks for wanting to help. CyberUI is a one person project and there is more
I would like to fix and add than I have time for, so help of any size is
welcome, and you do not need to write code to help.

Please read the [Code of Conduct](CODE_OF_CONDUCT.md) first. Security problems
go through [SECURITY.md](SECURITY.md), never a public issue.

## Ways to help

- **Report a bug.** Use the [bug report form](https://github.com/EmirErtorer/CyberUI.koplugin/issues/new/choose).
  Your device, its firmware and your KOReader version matter a lot here: most
  problems only show up on one kind of screen or one KOReader release.
- **Test a prerelease.** Anything I cannot try on my own reader goes out as a
  prerelease first. Turn on prereleases in System, About, Updates, try it and
  say how it went.
- **Share an idea.** Talk it through in
  [Discussions](https://github.com/EmirErtorer/CyberUI.koplugin/discussions)
  or open a [feature request](https://github.com/EmirErtorer/CyberUI.koplugin/issues/new/choose).
- **Make a theme.** A colour scheme is a dozen lines in `cyberui/themes/`.
  Show yours in Discussions; good ones can ship.
- **Improve the README** when something was hard to find or explained badly.
- **Send a fix or a feature** as a pull request.

## Before you write code

For a small fix, go ahead and open a pull request.

For anything bigger (a new screen, a change to how something works, a new
setting), please open an issue or a discussion first so we can agree on the
idea. Things I am careful about:

- **It has to stay fast on a plain grey Kindle.** Home paints in a few
  milliseconds; keep it that way. Work that can wait runs after the first
  paint, and anything slow is cached.
- **Refreshes matter.** E-ink screens are slow to redraw and ghost. Refresh
  only the part of the screen that changed, and never let a value that keeps
  changing (processor load, say) cause refreshes by itself.
- **Nothing hard-coded outside the theme layer.** Colours, sizes and fonts come
  from `cyberui/theme.lua` and the files in `cyberui/themes/`, so every
  scheme, light and dark, and every font set keeps working.
- **No new dependencies.** CyberUI uses what KOReader already ships, so it
  installs by copying one folder.
- **Works on stable KOReader.** Check new KOReader calls exist in the latest
  stable release, not just in a nightly.
- **Fewer settings, better defaults.**

## Setting up

You need [LuaJIT](https://luajit.org),
[luacheck](https://github.com/lunarmodules/luacheck) and KOReader's desktop
emulator, built from a [KOReader checkout](https://github.com/koreader/koreader/blob/master/doc/Building.md)
into `~/koreader-emulator` (or point `KO_DIR` at yours).

```sh
git clone https://github.com/EmirErtorer/CyberUI.koplugin.git
cd CyberUI.koplugin
tools/emulator.sh          # copies CyberUI into the emulator and starts it
```

The emulator is good for most work, but nothing beats a real reader. If you
have one, copy the folder into KOReader's `plugins` folder as the README
describes and try it there too.

## Where things are

| Path | What it holds |
|---|---|
| `main.lua` | The plugin's entry: Start with, menu entries, gestures, return from a book |
| `cyberui/app.lua`, `cyberui/host.lua` | The screen stack and the one window CyberUI draws in |
| `cyberui/screens/` | One file per screen: home, library, details, settings and so on |
| `cyberui/ui/` | Elements: buttons, panels, covers, the keyboard, progress bars |
| `cyberui/gfx/` | Drawing: shapes, text, icons and the ASCII art renderer |
| `cyberui/theme.lua`, `cyberui/themes/` | The theme layer: styles, colour schemes, font sets |
| `cyberui/data/` | Books, the library index, history, stats, the trash, device readings |
| `cyberui/menu.lua`, `cyberui/popup.lua` | KOReader's drop-down menu in CyberUI's style |
| `cyberui/install/`, `cyberui/update/` | Installing from GitHub and the updater |
| `tests/` | Headless suites and the emulator scenarios in `tests/e2e/` |

Each file starts with a comment that says what it does.

## Tests

Run these before you open a pull request:

```sh
tests/run.sh          # lint, luacheck, and the headless suites on KOReader's drawing code
tests/run.sh --e2e    # also the scenarios in the visible emulator
```

The headless suites need the emulator build; without it they are skipped.
GitHub runs the lint on every pull request. A fix should come with a check
that fails without it, and a feature with checks for what it does: look at the
suite or scenario next to the code you changed and follow its pattern.

## Code style

- Match the code around you: its naming, its comments and how it is laid out.
- Every function gets a short comment above it saying what it does or why.
  Comments explain, they do not repeat the code.
- No globals. `tests/lint.lua` checks for them and `luacheck` must stay clean.
- Text people see is in plain English with British spelling (colour, grey),
  short, and wrapped in `_()` like the rest of the code.

## Pull requests

- Keep each pull request to one change.
- Say what it changes and why, how you tested it and on which devices. If you
  could only try it in the emulator, say so; I may ship it as a prerelease
  first so readers can try it on theirs.
- For anything you can see, add a screenshot from the emulator or your reader.
- Add a line to the `[Unreleased]` section of the [changelog](CHANGELOG.md),
  written for readers rather than developers.
- Write commit messages as plain sentences that say what changed.

I try to answer every pull request within a week. Every contribution that
ships is credited in the changelog.

## License

CyberUI is released under the [MIT License](LICENSE). By sending a pull
request you agree that your contribution is released under it too.

## Translations

Every text the reader sees is translated into all the shipped languages. After
adding or changing one, run `luajit tools/i18n.lua sync`, fill the new entries in
every `l10n/<language>/cyberui.po`, and `luajit tools/i18n.lua check` (the test
suite runs it, so an untranslated text fails). See `l10n/README.md`.
