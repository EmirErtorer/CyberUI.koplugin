# Notices

CyberUI is original code, released under the MIT License (see `LICENSE`). Its
icons are drawn for CyberUI and released under the same license.

## Fonts

The fonts in `fonts/` are bundled under the
[SIL Open Font License 1.1](https://openfontlicense.org); each family's
license text sits beside it as `fonts/OFL-<family>.txt`.

| Family | Use in CyberUI |
|---|---|
| Oxanium | The default font set |
| Chakra Petch, Tomorrow, Rajdhani, Turret Road, Iceland | Font sets |
| Orbitron with Exo 2, Michroma with Electrolize | Font sets |
| Audiowide, Wallpoet, Russo One with Share Tech | Font sets |
| VT323, Press Start 2P | The Terminal and Arcade sets |
| Share Tech Mono | Monospaced text everywhere |
| JetBrains Mono | Block shading in ASCII covers |

Orbitron, Oxanium, Exo 2 and JetBrains Mono are static instances cut from the
variable fonts Google Fonts publishes. The README's title is drawn from
Rubik Glitch (also SIL Open Font License 1.1), turned into paths, so the font
itself is not shipped.

## Runtime

CyberUI runs inside [KOReader](https://github.com/koreader/koreader) and uses
KOReader's own APIs at runtime: its widgets, its fonts, its book data, its
zip reader and its SHA-256 for checking updates. Nothing else is bundled.

## Acknowledgements

The ASCII sleep screen was inspired by the ASCII cover screensaver patch in
[omer-faruq's KOReader user patches](https://github.com/omer-faruq/koreader-user-patches)
(GPL-3.0). CyberUI's code is written independently and shares none of it.
