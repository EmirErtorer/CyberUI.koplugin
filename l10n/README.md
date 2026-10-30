# Translations

CyberUI speaks the language KOReader is set to (KOReader > Settings > Language;
KOReader asks for a restart when it changes). Ten languages are in: Turkish
(`tr`), Brazilian Portuguese (`pt_BR`), Portuguese (`pt_PT`), Spanish (`es`),
Italian (`it_IT`), French (`fr`), German (`de`), Russian (`ru`), Polish (`pl`)
and Greek (`el`). Any other language shows English, except the few common words
(Cancel, Close, Delete...) that KOReader itself already translates.

## Fix or change a text, no code needed

Every language is one file, `l10n/<language>/cyberui.po`, a plain-text gettext
file that Poedit, Weblate or any text editor opens:

```
msgid "Library"          <- the English, never edit this line
msgstr "Bibliothek"      <- the text shown
```

- To change a text for yourself, copy the entry into
  `settings/cyberui-l10n/<language>.po` in KOReader's folder (the same format, only
  the entries you change). It wins over the shipped file and survives updates.
- To change it for everyone, edit the shipped file and send it back.
- Keep the placeholders (`%d`, `%s`, `%1`) as they are, and in the same order.
- Text the English writes in CAPITALS stays in capitals (the checks enforce it:
  Turkish `İ`, German `SS` for `ß`, Greek capitals without accents).
- Names stay as they are: CyberUI, KOReader, Ink Away, Wi-Fi (German says WLAN),
  GitHub and the font names.
- Some labels sit in narrow places (the tab bars, the stat tiles). Keep them
  short; `CYBERUI_LANG=<language> TRUNC=1 tests/screens.lua` lists the texts that
  were cut short with an ellipsis.

Plural texts have one `msgstr[n]` per form of the language, in the order of the
`Plural-Forms` line at the top of the file (Russian and Polish have three).

## Add a language

```bash
luajit tools/i18n.lua new <language> <number of plural forms> "<plural rule>"
```

`<language>` is KOReader's code (see `koreader/l10n/`), for example
`luajit tools/i18n.lua new nl_NL 2 "n != 1"`. Translate the empty entries, then
`luajit tools/i18n.lua check`. Nothing else changes: the file is found by name.

## For developers: nothing ships untranslated

All text goes through `local _ = require("cyberui/gettext")`:

```lua
_("Open")                                    -- a text
string.format(_("Saved %s"), name)           -- with a placeholder
string.format(_.n("%d book", "%d books", n), n)   -- a count (languages differ)
_.c("verb", "Open")                          -- one word, two meanings
```

After adding or changing a text, run `luajit tools/i18n.lua sync` (it updates
`l10n/cyberui.pot` and adds the new text, empty, to every language), translate it
in **every** language, then `luajit tools/i18n.lua check`. `tests/run.sh` runs that
check, so a commit with an untranslated, fuzzy or mismatched text fails. It also
refuses a text joined to other text with `..` (translate whole sentences with a
placeholder) and words shown to the reader outside `_()` (mark a deliberate one
with `-- i18n: keep`).

Dates use `Format.date` (KOReader's translated day and month names) and capitals
`Format.upper` (language aware), never `os.date("%a")` or `:upper()` for text the
reader sees.

`tools/i18n.lua export <language> [from [to]]` lists the texts to translate,
numbered; `import <language> <file>` takes `N<TAB>first letters<TAB>translation`
lines (plural forms after more tabs).

The terms chosen for each language are in `GLOSSARY.md`.
