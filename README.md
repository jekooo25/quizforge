# Quizforge

A student uploads a reviewer, it becomes a question set, and the questions drive
a monster battle. Built to the Figma screens: courtyard splash → auth → wooden
board menu → upload → generation.

## Run it

```powershell
godot --path "C:\Users\myles\OneDrive\Documents\Default Project"
```

Landscape phone layout, designed at **1280 x 562** (≈2.28:1, matching the frames)
with `canvas_items` stretch, so it scales to any device.

## Screens

| Script | Screen |
| --- | --- |
| `scripts/screens/title_screen.gd` | Splash, "Tap anywhere to start" |
| `login_screen.gd` | Username / password, or sign up |
| `signup_name_screen.gd` | Sign up step 1 — full name |
| `signup_school_screen.gd` | Sign up step 2 — school credentials |
| `loading_screen.gd` | Branded wait screen, then the menu |
| `menu_screen.gd` | Three tiles on the campus photo, mascot top right |
| `progress_screen.gd` | Two tabs: the profile summary, and the saved-quiz shelf |
| `my_quizzes_screen.gd` | The same shelf as a screen of its own |
| `upload_screen.gd` | Reviewer picker + backup consent |
| `generation_screen.gd` | Five-stage pipeline, then Play Encounter |
| `settings_screen.gd` | Music / SFX |
| `thank_you_screen.gd` | Farewell after exit, then the app closes |
| `progress_screen.gd` | What we know about the student |
| `scenes/battle.tscn` | The encounter itself (placeholder, see below) |

## Structure

```
scripts/ui/ui_theme.gd      palette, fonts, every widget factory (restyle here)
scripts/ui/nav.gd           autoload: screen router + profile/save
scripts/ui/backdrop.gd      courtyard drawn in code
scripts/ui/cat_mascot.gd    the mascot, drawn in code
scripts/ui/board_card.gd    wooden board frame + content slot
scripts/ui/board_dialog.gd  confirmations on the board
assets/fonts/               Press Start 2P, Silkscreen, Kalam (Google Fonts, OFL)
```

All art is vector code — no sprites to lose. Swap `backdrop.gd` / `cat_mascot.gd`
for real art and nothing else changes.

## What is real vs. placeholder

| Real | Placeholder |
| --- | --- |
| Every screen, styled and navigable | Login accepts anything non-empty |
| Form validation (email, password match, required fields) | No backend, no real accounts |
| Profile saved to `user://quizforge_save.json` | Password is never written to disk |
| File picker with image/doc filters | Reviewer contents are not parsed |
| Generation pipeline UI with real progress/staging | Stages are timed, not doing inference |
| Encounter reached from the flow | Uses the earlier Quizmon battle scene |

The honest gap: **nothing reads the uploaded reviewer yet**, and there's no
question generator. That's the next build, and it defines the product.

## Question generation (`server/`)

This is the part that makes it Quizforge instead of a quiz UI: a file goes in,
questions come out.

```powershell
# one-time: dependencies live outside the project so OneDrive doesn't sync them
py -m venv C:\Users\myles\Tools\qfenv
C:\Users\myles\Tools\qfenv\Scripts\python.exe -m pip install pymupdf pillow

# key goes in the user environment, never in the repo
[Environment]::SetEnvironmentVariable("GEMINI_API_KEY", "your-key", "User")
```

```powershell
# AI generation (needs the key)
py server/spike.py "reviewer.pdf" --count 10 --provider gemini

# offline fallback: no key, no network, weaker questions
py server/spike.py "reviewer.pdf" --count 10 --provider offline
```

Inputs: `.pdf`, `.txt`/`.md`/`.csv`, and images (photos of pages). PDFs with a
text layer are read directly; scanned pages and photos go to the vision model
as images. Measured: ~14s for 10 questions from a 7-page PDF.

Every provider returns one shape, so the app never learns which one ran:

```json
{ "source": {"file": "...", "pages": 7, "chars": 9942, "method": "text"},
  "title": "...",
  "pages": [{"page": 1, "text": "..."}],
  "questions": [{"id": "q1", "question": "...",
                 "choices": ["a", "b", "c", "d"], "answer": 2,
                 "explanation": "...", "source_quote": "..."}] }
```

`pages` feeds the review-and-edit screen; `source_quote` is why each question
exists. `QF_GEMINI_MODEL` / `QF_OPENAI_MODEL` override the model name.

**Offline is a fallback, not a substitute.** It blanks keywords and borrows
distractors, so it cannot tell what matters in a document — without noise
filters it happily writes questions about bibliography entries.

## Pointing the app at the server

Students never configure an address. The build ships with one, in
`scripts/quiz/server_config.gd`:

```gdscript
const DEFAULT_URL := "http://127.0.0.1:8765"
```

Change that line to the hosted HTTPS URL and rebuild — it is the only place in
the app that knows where the server is.

For LAN testing there is a hidden developer menu: **Settings → tap the version
label seven times**. It holds an address override (saved with the profile) and a
**Reset to default** button that hands control back to `DEFAULT_URL`. Profiles
written before v0.1.0 had an address typed into Settings; those are discarded on
load, so no shipped profile keeps pointing at someone's laptop.

## Test

```powershell
# click through every screen, end to end (66 checks)
godot --headless --path . res://tests/flow.tscn

# battle loop (21 checks)
godot --headless --path . res://tests/smoke.tscn

# save layer: atomic writes, backup recovery, damaged files (48 checks)
godot --headless --path . res://tests/save.tscn

# screenshot any screen
godot --path . res://tests/capture.tscn -- --screen res://scripts/screens/menu_screen.gd --out shot.png
```

Each suite counts the checks it ran and fails if it did not reach them all, so a
crashed assertion can no longer report a pass. They run as scenes rather than
`--script` entry points because a `--script` main loop is compiled before the
autoloads exist, and the app's scripts resolve autoloads by name.

Running them rewrites `user://` data: the flow test starts from an empty quiz
library, and the smoke test puts the machine's own quiz back when it finishes.

After adding a script with `class_name`, refresh the class cache:
`godot --headless --import --path .`

## Tuning

- Palette and type: `scripts/ui/ui_theme.gd`
- Frame size / aspect: `[display]` in `project.godot`
- Generation speed: `SPEED` in `generation_screen.gd`
- Stage names and thresholds: `STAGES` in `generation_screen.gd`
