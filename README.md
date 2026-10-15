# Uptime — "One Week" prototype (paper port)
A life sim about a sysadmin dad with 99.2% uptime and an SLA of 100%. Godot 4.7, GDScript.

**Look:** crude paper cut-out characters standing as cards in 3D cardboard dioramas, with a raised side-on follow camera
(Paper Mario-like). The old pixel version is preserved at git tag `v0-pixel`.

### How the paper layer works
- Game logic is unchanged: each Location (`scripts/locations/*.gd`) is still a 320x200 plan with stations, spots and
  solids. It is hidden; `scripts/paper/diorama.gd` builds a 3D set from it and mirrors every actor onto a paper card.
- Walk with WASD/arrows as before (W/S move into/out of the set). Near a station a paper tag floats over it
  (`Kitchen [1-3]`); the bottom bar lists the actions.
- Cards flip like a page (tilt + visible thickness) when Dan turns, bob/wobble when walking, and the speaker's head
  flaps open on vowels while the line types out (Enter once finishes the line, again continues).
- The dialogue banner sits at the bottom, or moves to the top if the bottom would cover a sign or the speaker.
- Town destinations (park, pharmacy, dental, diner, coffee) each have a small set behind the papercraft town board.

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

### Shorter workday (Marty's playtest)
- At the office a ticket takes about 2.5 in-game hours. **Head home** unlocks after **2 tickets**, or from 1:30 PM.
- A 3rd ticket counts as **staying late**: Jess -5, Girls -6. There is no 4th ticket.
- Job performance drifts down 3 per workday, so it now has to be earned. Office tickets give +3 base, adjusted by grade. Tickets worked from home give at most +1 base, max 2 per day.

### Terminal quality-of-life
- **Live suggestions:** after every step, the button row shows the real next command for this ticket (correct host and args), plus 1–2 plausible alternatives and `help`. With Rx focus the right one comes first, marked ▶.
- **Grading:** a run done only by clicking caps at **Good**. If you type or Tab-complete at least half the commands yourself, you keep **Great** and get **+6 XP**.
- **Tab completion** works like bash for commands, hostnames, users, services and subcommands. Pressing Tab twice lists the options.
- The command input keeps focus after Enter.
- Walking away after 3+ commands still costs the time you spent (30–60 min).

### Town map
- Leaving a place opens a top-down pixel-art map of Brookfield. Click a place, or press its number; arrows + Enter also work. Press M from the car to reopen it.
- Places: Home, School (after-care pickup 2:30–6:30 PM), Gas-N-Sip, Riverside Park, Pharmacy (Rx refill), Dental (Dr. Lin), Lou's Diner (feeds the girls), and the Office (mornings only, with drop-off on the way).
- Each place shows its travel time. Places are locked by time or phase, and the lock reason is listed.
- Home stays locked until the girls are picked up, except on Wednesday, when Jess has pickup.
- Missing the after-care window means Jess leaves work to get them: Girls -15, Jess -8, stress +8.

### Pass 2 mechanics
- **Performance:** below 40 Gary checks in; below 25 you're on a PIP (autopilot suspended, burnout risk); at 75 or above you get a $60 Friday bonus.
- **Girls Fed:** a snack at school pickup (+15); Jess cooks if they're still hungry at 7:30 PM. Watch for the red HUNGRY warning.
- **Afternoon:** pickup opens at 2:00 PM; grab a coffee on the town map in between.
- **Terminal:** common real commands (dig, journalctl, uptime, sudo, top, ip a, curl, cat, ls, history, clear, man) work, with Tab completion.
- **Incidents** have a visible SLA. Hints cost time, and breaches hurt performance and block the Uptime ending.

### Paper port mechanics
- **Incident SLA scales with skill:** slack on top of the fastest path is 12–28 min at Lv 1–2, 10–24 at Lv 3,
  8–20 at Lv 4 and 6–16 at Lv 5. **Curveballs** (Gary wants an ETA, vendor hold music, Karen, laptop updates, the CEO
  "listening in") cost 4–8 min each, 20% per command, and are listed in the postmortem as not your fault.
- Parallel bots: set `UPTIME_SAVE_TAG=<name>` to give a process its own save slot.
- Persona bots now also check the paper layer (cards present/inside walls, lanes, camera edge leaks) and there is a
  7th persona, `paperfan`, which watches cutscenes at 30 fps and judges typing, flaps, flips and framing.
- Quick look at all sets: `xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/paper_quick.gd -- /tmp/pq`;
  gameplay clip frames: `tools/paper_gif.gd`; regenerate paper 2D art: `python3 tools/gen_paper.py`.
