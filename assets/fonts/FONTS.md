# Fonts and their licences

Every font file in this folder is redistributed with the app, so the licence has
to ship with it. Keep this table and `LICENSES/` in sync when a font is added.

## Active font switch

The active body and heading source is `../themes/font_body.tres`. Change its
single `base_font` resource line to change the whole app. `font_display.tres`
is deliberately an alias of that body resource, so scene headings and
code-built battle labels stay in sync.

| File | Used for | Licence | Upstream |
| --- | --- | --- | --- |
| `CMUTypewriter-Regular.ttf` | app-wide body and heading font | SIL OFL 1.1 (`LICENSES/CMUTypewriter-OFL.txt`) | https://fontlibrary.org/en/font/cmu-typewriter |
| `PixelifySans-Regular.ttf` | retained legacy asset; not active | SIL OFL 1.1 (`LICENSES/PixelifySans-OFL.txt`) | https://fonts.google.com/specimen/Pixelify+Sans |
| `PixelifySans-Bold.ttf` | retained legacy asset; not active | SIL OFL 1.1 (`LICENSES/PixelifySans-OFL.txt`) | https://fonts.google.com/specimen/Pixelify+Sans |
| `PressStart2P-Regular.ttf` | pixel headings | SIL OFL 1.1 (`LICENSES/OFL-1.1.txt`) | https://fonts.google.com/specimen/Press+Start+2P |
| `Silkscreen-Regular.ttf` | small pixel labels | SIL OFL 1.1 (`LICENSES/OFL-1.1.txt`) | https://fonts.google.com/specimen/Silkscreen |
| `Silkscreen-Bold.ttf` | small pixel labels | SIL OFL 1.1 (`LICENSES/OFL-1.1.txt`) | https://fonts.google.com/specimen/Silkscreen |
| `Kalam-Regular.ttf` | script accents | SIL OFL 1.1 (`LICENSES/OFL-1.1.txt`) | https://fonts.google.com/specimen/Kalam |
| `Kalam-Bold.ttf` | script accents | SIL OFL 1.1 (`LICENSES/OFL-1.1.txt`) | https://fonts.google.com/specimen/Kalam |
| `Montserrat-ExtraBold.ttf` | retained legacy asset; not active | SIL OFL 1.1 (`LICENSES/OFL-1.1.txt`) | https://github.com/JulietaUla/Montserrat |
| `Montserrat-Bold.ttf` | retained legacy asset; not active | SIL OFL 1.1 (`LICENSES/OFL-1.1.txt`) | https://github.com/JulietaUla/Montserrat |
| `Montserrat-SemiBold.ttf` | retained legacy asset; not active | SIL OFL 1.1 (`LICENSES/OFL-1.1.txt`) | https://github.com/JulietaUla/Montserrat |

## Copyright lines

OFL 1.1 asks for the copyright notice alongside the licence. When a font is
added or updated, paste its upstream copyright statement here:

- **CMU Typewriter** — Copyright (c) 2003-2009, Andrey V. Panov
- **Montserrat** — Copyright (c) 2011, The Montserrat Project Authors (https://github.com/JulietaUla/Montserrat)
- **Press Start 2P** — _add the line from the Google Fonts download_
- **Silkscreen** — _add the line from the Google Fonts download_
- **Kalam** — _add the line from the Google Fonts download_

The three Google Fonts files were already in the project without their licence
text; `LICENSES/OFL-1.1.txt` covers the licence itself, and the copyright lines
above still need filling in for strict compliance.
