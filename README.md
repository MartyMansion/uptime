# Uptime — "One Week" prototype
A life sim about a sysadmin dad with 99.2% uptime and an SLA of 100%. Godot 4.7, GDScript.

## Open it
1. Install Godot 4.7+ (standard build) from godotengine.org.
2. Unzip, open the Project Manager → **Import** → pick `uptime/project.godot` → **Import & Edit**.
3. Press **F5**. (First open re-imports the art; takes a few seconds.)

## Controls
| Key | Does |
|---|---|
| WASD / Arrow keys | Walk |
| 1 / 2 / 3 / 4 | Actions at the highlighted station (listed in the bottom bar) |
| T | Text Jess (anywhere) |
| P | Nic pouch (anywhere) |
| R | Rx dose (anywhere) |
| Enter / Space | Next dialogue line / close popup / continue past a summary |
| Esc | Skip the current cutscene |

## A day
Wake-up cutscene → **House** (breakfast or cereal in the Kitchen) → **Front door** (drop-off cutscene at school, arrive at **TriCounty**, Gary says something) →
work tickets (or a coffee break) at **Your desk** until 4 PM → **Exit** → **Gas-N-Sip** stop (Beer cooler, Counter, or just get in **Your car**) →
school pickup → Jess comes home → evening (Girls' room, PC desk, Kitchen) → bedtime story 7:30–9 PM → **Bed** → day-end cutscene + summary. After Sunday: weekly review cutscene + LifeOS Performance Review.

## Dev
- Tests (headless): `godot --headless --path . -s res://tests/run_tests.gd`
- Playtest bot (100 weeks): `godot --headless --path . -s res://tests/playtest_bot.gd -- 100 /tmp` (writes playtest_log.txt + dialogue_seen.txt)
- Screenshots + UI audit (needs a renderer): `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshots.gd -- <outdir>`
- Regenerate art: `python3 tools/gen_sprites.py` (see ASSETS.md)
