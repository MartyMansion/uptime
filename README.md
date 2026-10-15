# Uptime — "One Week" prototype
A life sim about a sysadmin dad with 99.2% uptime and an SLA of 100%. Godot 4.7, GDScript.

## Open it
1. Install Godot 4.7+ (standard build) from godotengine.org.
2. Unzip, open the Project Manager → **Import** → pick `uptime/project.godot` → **Import & Edit**.
3. Press **F5**. (First open re-imports the art; takes a few seconds.)

## Controls
| Key | Does |
|---|---|
| WASD / Arrow keys | Walk (furniture is solid now) |
| 1 / 2 / 3 / 4 | Actions at the highlighted station (listed in the bottom bar); also picks options in choices |
| T | Phone: reply to Jess (thoughtful / k 👍 / draft-and-delete ❤) |
| B | Box breathing (free stress relief, 2/day) |
| P | Nic pouch (anywhere) |
| R | Rx dose (anywhere) |
| Enter / Space | Next dialogue line / close popup / continue past a summary |
| Esc | Skip the current cutscene (on a choice: takes the kindest option) |
| F6 / F7 | Save / load (the game also autosaves every morning and continues on launch) |

## A week
**Mon–Fri:** wake-up → House (breakfast) → Front door (drop-off, TriCounty, Gary) → work tickets / coffee break / call the doctor at **Your desk** until 4 PM →
**Gas-N-Sip** (beer, pouches, patches, or just the car; pick the radio station) → school pickup → Jess comes home (sometimes a chaos event) →
evening: family dinner (with conversation), homework & drawings, the park, walk around the block, tea with Jess, games, side hustle, bedtime story 7:30–9 PM → **Bed** → day-end summary with a *Moment of the day*.
**Sat–Sun:** home days: pancakes, chores together, the park, tea, on-call page Sunday afternoon.
The calendar (top of the sidebar) has picture day, taco Wednesday, Lily's Thursday concert and pizza Friday. After Sunday: weekly review + one of six endings.

## Dev
- Tests (headless): `godot --headless --path . -s res://tests/run_tests.gd`
- Playtest bot (100 weeks): `godot --headless --path . -s res://tests/playtest_bot.gd -- 100 /tmp` (writes playtest_log.txt with BALANCE/ENDINGS/SAVELOAD stats + dialogue_seen.txt)
- Screenshots + UI audit (needs a renderer): `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshots.gd -- <outdir>`
- Regenerate art: `python3 tools/gen_sprites.py` (see ASSETS.md)
