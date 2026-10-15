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

## Work a ticket: the terminal
At **Your desk** (or the home PC), *Work a ticket* opens **TermOS**, a green-on-black console on the fictional TriCounty network:
`tc-dc01` (AD/DNS), `tc-files01` (smbd), `tc-web01` (nginx), `tc-print01` (cups), `tc-app01` (payroll), `tc-sw01` (core switch).
Each ticket has a randomized root cause: blocked firewall port, stopped service, DNS typo, full disk, expired cert, stuck print queue, wrong VLAN, or account lockout.
Type real-ish commands (`ping`, `ssh`, `nslookup`, `traceroute`, `ss -tlnp`, `firewall list/allow`, `systemctl status/restart`, `tail log`, `df -h`, `du -sh`, `logrotate --force`, `certcheck`, `certbot renew`, `lpstat`, `cancel -a`, `ipconfig`, `show port`, `set port N vlan V`, `aduser`, `unlock`, `dns records/fix`, `help`), or click the suggestions.
- **Hint (H):** 3 per ticket (1 when Running on Fumes). **Rx focus:** the next step is highlighted ▶ and hints are free. **Fumes:** typed commands may come out with typos (clicked ones don't).
- **Grade:** Great (optimal path, no hints): 30 min, -7 energy, +6 perf, almost no stress. Good: 60 min, +5 perf. Slow: 90 min, +3 perf, more stress. **Autopilot:** 60 min, +2 perf, the most stress. **Walk away (Esc):** no cost.
- Tickets take about 1–3 minutes of real play.

## A week
**Mon–Fri:** wake-up → House (breakfast) → Front door (drop-off, TriCounty, Gary) → work tickets / coffee break / call the doctor at **Your desk** until 4 PM →
**Gas-N-Sip** (beer, pouches, patches, or just the car; pick the radio station) → school pickup → Jess comes home (sometimes a chaos event) →
evening: family dinner (with conversation), homework & drawings, the park, walk around the block, tea with Jess, games, side hustle, bedtime story 7:30–9 PM → **Bed** → day-end summary with a *Moment of the day*.
**Sat–Sun:** home days: pancakes, chores together, the park, tea, on-call page Sunday afternoon.
The calendar (top of the sidebar) has picture day, taco Wednesday, Lily's Thursday concert and pizza Friday. After Sunday: weekly review + one of six endings.

## Dev
- Tests (headless): `godot --headless --path . -s res://tests/run_tests.gd`
- Playtest bot (100 weeks): `godot --headless --path . -s res://tests/playtest_bot.gd -- 100 /tmp` (writes playtest_log.txt with BALANCE/ENDINGS/SAVELOAD/TERMINAL stats + dialogue_seen.txt)
- Screenshots + UI audit (needs a renderer): `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshots.gd -- <outdir>`
- Regenerate art: `python3 tools/gen_sprites.py` (see ASSETS.md)

### Dan's skills, autopilot and incidents
- **Skills:** each ticket category (networking, dns, storage, services, accounts, certs, printers) has its own XP. The bar sits in the terminal header. Levels come at 40/100/180/300 XP. Higher levels give more hints, and at Lv 5 autopilot grades "good".
- **Autopilot is locked** for a category until Dan reaches Lv 3 in it ("Autopilot locked (needs Lv 3)").
- **Incidents:** site outage, ransomware scare, failed backup restore, DB corruption, UPS failure, and cert-expiry outage. Each one runs as a multi-stage runbook with a 90-minute SLA (3 in-game minutes per command) and escalation lines from Gary. A blameless POSTMORTEM follows. You can walk away, and Gary will hand it to a vendor (perf/stress hit).
- **After-hours pages:** on weekday evenings Dan might get paged. Take it now and the family meters take the hit, or hand it to Raj.
- **Girls: Fed:** packed lunches (+20 when leaving for work), slower decay while you're at work, a LifeOS nudge below 25%, and family dinner tops it up.
- Summary and postmortem popups stay inside the game area. Long text shrinks to fit.
