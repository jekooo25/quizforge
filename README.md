# Quizmon

A quiz battle: answer a question, your creature attacks. The faster you answer,
the harder the hit. Miss, and the enemy attacks you. First to 0 HP loses.

## Play

Open the folder in Godot 4.7 and press F5, or from a terminal:

```powershell
godot --path "C:\Users\myles\OneDrive\Documents\Default Project"
```

## Project layout

| Path | What it does |
| --- | --- |
| `project.godot` | Project settings, window size, main scene |
| `scenes/battle.tscn` | The only scene: a Control root with `battle.gd` attached |
| `scripts/battle.gd` | Whole battle loop: UI construction, questions, damage, win/lose |
| `scripts/creature.gd` | `Creature` data class (name, HP, attack, colour) |
| `scripts/creature_sprite.gd` | `CreatureSprite`: draws the creature in vector code, no image assets |
| `tests/smoke_test.gd` | Headless test of the battle loop (19 checks) |
| `tests/capture.tscn` | Screenshot harness for checking layout without the editor |

## Tuning knobs

All in `scripts/battle.gd`:

- `ROUND_TIME` — seconds per question (default 12)
- `QUESTIONS` — the question array; add entries shaped like
  `{"q": "...", "choices": ["A", "B", "C", "D"], "correct": 2}` where `correct`
  is a zero-based index
- `_resolve_hit()` — damage formula: `atk * (1 + speed)`, plus streak bonus,
  times 1.4 on a critical (answered in the first 28% of the clock)
- `_start_battle()` — creature stats live here

## Verification

```powershell
# battle logic, no window needed
godot --headless --path . --script res://tests/smoke_test.gd

# refresh the global class cache after adding scripts with class_name
godot --headless --import --path .

# save a screenshot of the current layout
godot --path . res://tests/capture.tscn -- --out shot.png --delay 1.2
```
