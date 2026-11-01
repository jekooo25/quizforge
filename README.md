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
| `menu_screen.gd` | Wooden board, mascot peeking over the top |
| `upload_screen.gd` | Reviewer picker + backup consent |
| `generation_screen.gd` | Five-stage pipeline, then Play Encounter |
| `settings_screen.gd` | Music / SFX |
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

## Test

```powershell
# click through every screen, end to end (26 checks)
godot --headless --path . res://tests/flow.tscn

# battle loop (19 checks)
godot --headless --path . --script res://tests/smoke_test.gd

# screenshot any screen
godot --path . res://tests/capture.tscn -- --screen res://scripts/screens/menu_screen.gd --out shot.png
```

After adding a script with `class_name`, refresh the class cache:
`godot --headless --import --path .`

## Tuning

- Palette and type: `scripts/ui/ui_theme.gd`
- Frame size / aspect: `[display]` in `project.godot`
- Generation speed: `SPEED` in `generation_screen.gd`
- Stage names and thresholds: `STAGES` in `generation_screen.gd`
