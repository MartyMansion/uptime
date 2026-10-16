# Uptime: Expanded Playtest (12 personas × 300 weeks)

Build tested: `main` at 7755b1b, plus fixes in a8c2232, 2b44e95 and later commits (see git log). Each persona played **300 one-week runs** headless (Godot 4.7.2) in parallel, with separate save slots (`UPTIME_SAVE_TAG=<persona>`).

**Actual counts:**
- Every persona ran the full 300 weeks: 3,600 weeks in the first pass.
- After the fixes, 5 farm personas were re-run for another 300 weeks each: sysadmin, completionist, paperfan, homelab and tycoon.
- The table shows the final run for each persona. The first-pass farm logs are in `playtest_expanded/v1/`.

**Result:** 0 problems across all 12 personas (UI audits, paper/camera checks, save/load, state invariants, farm model checks, keyboard-only play). The only first-pass problem, 15 "boxes did not open the assembly" in completionist, was a bot expectation and is fixed (see bug #9). `tests/run_tests.gd` passes with 0 failures.

New personas: 8 `homelab` (datacenter vet), 9 `tycoon`, 10 `therapist`, 11 `a11y` (keyboard-only), 12 `comedy`. Their policies are in `tests/persona_bot.gd`. Logs are in `uptime-build/playtest_expanded/`, and every line the comedy writer and therapist read is in `lines_comedy.txt` and `lines_therapist.txt`.

## Per-persona stats

How to read the table: "Breached / hand-solved" counts incidents Dan solved by hand that missed the SLA. "Farm" sums over all 300 weeks; servers_online is the total at week end, so divide by weeks for the average. "Avg end state" is the average at week end.

| Persona | Weeks | Problems | Endings | Breached / hand-solved incidents | Farm | Avg end state |
|---|---|---|---|---|---|---|
| a11y | 300 | 0 | cozy 100% | 53/511 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 0 perf 76 jess 96 girls 99 | drawings 9.6 bedtimes 4.3 | drinks 0.0 pouches 0.0 rx_extra 0.0 | money 44 |
| comedy | 300 | 0 | foggy 99%, turning 0% | 72/497 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 1 perf 69 jess 91 girls 89 | drawings 6.6 bedtimes 0.6 | drinks 2.8 pouches 9.1 rx_extra 20.9 | money 46 |
| completionist | 300 | 0 | cozy 66%, turning 29%, foggy 3%, homelab 1% | 40/550 | runs 300 orders 1826 builds 888 servers_online 593 net $31934 outages 289 | stress 2 perf 32 jess 93 girls 95 | drawings 11.8 bedtimes 4.5 | drinks 0.9 pouches 1.6 rx_extra 2.0 | money 81 |
| cozy | 300 | 0 | cozy 100% | 49/419 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 5 perf 29 jess 97 girls 100 | drawings 13.0 bedtimes 7.0 | drinks 0.0 pouches 0.0 rx_extra 0.0 | money 80 |
| homelab | 300 | 0 | cozy 67%, turning 17%, foggy 7%, homelab 5%, real 2%, uptime 0% | 32/482 | runs 297 orders 1197 builds 1192 servers_online 543 net $23759 outages 265 | stress 0 perf 93 jess 89 girls 84 | drawings 4.4 bedtimes 2.9 | drinks 0.0 pouches 0.0 rx_extra 3.9 | money 52 |
| newbie | 300 | 0 | turning 54%, cozy 37%, real 5%, foggy 2%, crispy 0% | 209/222 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 2 perf 15 jess 84 girls 92 | drawings 1.7 bedtimes 1.6 | drinks 0.6 pouches 1.1 rx_extra 2.6 | money 71 |
| paperfan | 300 | 0 | cozy 100% | 46/484 | runs 291 orders 681 builds 680 servers_online 292 net $21395 outages 188 | stress 0 perf 31 jess 96 girls 99 | drawings 9.8 bedtimes 2.2 | drinks 0.0 pouches 0.0 rx_extra 0.0 | money 44 |
| speedrunner | 300 | 0 | foggy 100% | 39/499 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 0 perf 36 jess 78 girls 81 | drawings 3.5 bedtimes 0.8 | drinks 1.2 pouches 7.6 rx_extra 19.6 | money 48 |
| struggling | 300 | 0 | turning 73%, foggy 26% | 138/443 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 4 perf 70 jess 8 girls 16 | drawings 0.7 bedtimes 0.3 | drinks 16.0 pouches 16.6 rx_extra 8.8 | money 19 |
| sysadmin | 300 | 0 | cozy 54%, turning 23%, foggy 14%, homelab 4%, real 3%, uptime 0% | 54/477 | runs 300 orders 1513 builds 1371 servers_online 600 net $25232 outages 232 | stress 0 perf 94 jess 87 girls 80 | drawings 5.0 bedtimes 2.4 | drinks 0.0 pouches 0.0 rx_extra 4.5 | money 84 |
| therapist | 300 | 0 | real 100% | 45/488 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 0 perf 54 jess 48 girls 100 | drawings 1.1 bedtimes 3.0 | drinks 0.0 pouches 0.0 rx_extra 0.0 | money 99 |
| tycoon | 300 | 0 | real 39%, uptime 26%, turning 19%, cozy 8%, foggy 6%, crispy 0% | 33/410 | runs 300 orders 1800 builds 1800 servers_online 300 net $30916 outages 216 | stress 1 perf 86 jess 69 girls 39 | drawings 2.9 bedtimes 0.0 | drinks 0.0 pouches 0.0 rx_extra 3.4 | money 154 |

Homelab ending, before and after tuning (300 weeks each):

| Persona | Before (any 2 servers) | After |
|---|---|---|
| completionist | 45% | 1% |
| sysadmin | 17% | 4% |
| homelab vet | 0% (couldn't afford) | 5% |
| tycoon | 0% | 0% (bot stalls at tier 1, see feedback) |

## Bugs found and fixed (all covered by tests or persona checks)

| # | Found by | Bug | Fix |
|---|---|---|---|
| 1 | a11y | The BrookOS desktop and its windows opened without keyboard focus, so you couldn't use the desktop or shops without a mouse. | The first icon (or the window's first button) grabs focus. Arrows, Enter and Esc work. Tests: `desktop takes keyboard focus`, `window takes keyboard focus`. |
| 2 | a11y | Town-map pins were under 24 px tall (too small to click reliably). | Pins have a 25 px minimum height and a 13 px font. A 14 px font made pins overlap, which the a11y bot caught. |
| 3 | tycoon | The HUD day label was clipped in the garage, because the garage's long title squeezed the top bar. | The garage title is now short ("The garage"). |
| 4 | comedy | "Play with Lily & June" and "Make breakfast with the girls" printed the menu label as their result (133 and 14 times in 3 weeks). | 5 rotating result lines each. Tests: `play_girls has a real result line`, `breakfast has a real result line`. |
| 5 | comedy | The extra-Rx line repeated about 60 times a week, and after the first fix it got stuck on its last variant (5,685 times in 300 weeks). | Escalating first line, then the later two alternate. |
| 6 | comedy | The after-work line still listed a fixed route ("school, Gas-N-Sip, home"), contradicting the no-forced-stop fix. | It now says "After-care closes at 6:30. The girls know exactly what time it is." |
| 7 | homelab/tycoon | The homelab ending was too easy: "any 2 servers" won 50–75% of farm weeks. | Now it needs 2+ servers online behind a UPS, at least $35 net, at most 1 outage, Jess ≥ 50 and girls ≥ 40. A thriving cozy week outranks it unless the farm netted $140 or more. Tests cover each gate. |
| 8 | homelab | The economy never paid back inside one week (old prices, $9/day per server). | Server $55, UPS $60, electrician $95, $14/day per server. Power stays realistic: 180 W ≈ $0.69/day at 0.16 $/kWh. |
| 9 | completionist | The bot's assembly check fired when the game correctly refused a build (too tired or too late). | Bot fix: it checks `can_do` first and counts `farm_build_blocked`. The game already gives the reason. |
| 10 | therapist | The harsh-language detector flagged "closer" as "loser" (false positive). | Bot fix: whole-word matching. |
| 11 | a11y | The legacy bot had no way to play keyboard-only. | Added an `act()` hook in `playtest_bot.gd`. The a11y persona plays through station keys 1–4, T/P/R/B, map number keys, terminal Tab/Enter/H, and desktop Esc. |

## Persona feedback (in voice)

### 1. Sysadmin
- "The terminal is the best part. Real commands answer like real boxes, and Tab completion works the way my hands expect."
- "Incident SLAs that tighten as I level up actually feel fair. I breach about 1 in 7 when I'm careless, which is about right."
- "I'm a sysadmin with a garage. Of course I bought a rack. The FarmStat window is the first in-game dashboard I didn't want to file a bug against."
- "Two servers on a household circuit, then a hard stop until the electrician comes? That's real. I've tripped that breaker."
- "Overnight outages without a UPS are believable, and so is the rate."
- "I'd like `ssh` into my own garage boxes from the work terminal, and a pager alert when the farm goes down."
- "Performance in the 90s with Jess at 87 and the girls at 79 is a good 'competent but stretched' week."

### 2. Cozy Stardew fan
- "Three hundred weeks and every single one ended cozy. That's the dream, but maybe it's too easy for me."
- "Thirteen fridge drawings a week and 7 bedtime stories: the cozy loop is generous and readable."
- "Performance around 29 doesn't seem to hurt my week much. I'd like work stakes I can feel, gently."
- "The park, the tomato and pancakes are the best part. More weekend activities, please, especially seasonal ones."
- "I never opened the garage. Could Lily or June ask to see the 'blinky lights'? That would pull me in."
- "Tea on the couch is a perfect line. The cozy writing is the strongest in the game."

### 3. Speedrunner / Breaker
- "I mashed every key, spammed disallowed actions, F6/F7'd mid-week, resized to 6 resolutions and rage-quit tickets. Zero state corruption in 300 weeks. Respect."
- "Every speedrun ends 'foggy' because the fastest route is chemical. It's funny once. Maybe add a clean any% route."
- "Locked map pins refuse cleanly, with no time cost. Good."
- "Esc-skipping cutscenes is instant. Please add a 'skip seen dialogue' option."
- "The desktop opens and closes cleanly while I spam keys. The busy-state guard holds."
- "I'd like a clean-week timer and a week-in-under-N-minutes achievement."

### 4. Terminal newbie
- "I breached 209 of the 222 incidents I solved myself. Even with cheaper hints, I feel stupid, not taught."
- "The hint text 'Try: …' is great when it appears. I want a 'just show me' button that teaches the command afterwards."
- "Autopilot saved me, but it locks when you're on a PIP, which is exactly when I need it."
- "Typing nonsense gets funny 'command not found' replies. More of those, please; that's where I laughed."
- "Ending up 'turning' or 'cozy' even when I'm bad at work feels kind. Thank you."
- "Performance around 15 is brutal. Gary's check-ins felt like being called to the principal."

### 5. Struggling parent
- "Jess at 8 and the girls at 16 at week's end is honest. It's what it looks like when it's going badly."
- "73% of my weeks ended 'turning'. The game keeps the door open, and that matters."
- "Sixteen drinks and 16.6 pouches a week, and the lines never mock me. They notice. That's the right tone."
- "The Gas-N-Sip being optional now means it's my choice, which hurts more, in a good way."
- "I want one more off-ramp mid-week: a friend's text, or a meeting flyer at the pharmacy."
- "Money ends around $19. Show me the bills coming, not just the balance."

### 6. Completionist
- "I touched every verb, place and box. The garage plus the shops is a lovely new checklist."
- "I bought 6 items a week and built half of them. Building takes real evening time, which I like."
- "I'd like an achievements screen. The data exists, but I can't see it in-game."
- "FarmStat needs history. A week-over-week graph would make me buy one more server."
- "Performance around 32 because I'm everywhere at once. Fair."
- "The 'Mercer Data Center' ending text is great. I want the girls' status page in the fridge drawing art."

### 7. South Park + Paper Mario fan
- "Cards flip with real thickness, mouths flap only while typing, and the camera never leaked in 300 weeks. The craft holds."
- "578 times (in the a11y run) a sign sat under the dialogue banner. The adaptive banner mostly works, but not always."
- "The garage set is the darkest diorama. The shop bulb helps, but the servers need a glow pass."
- "Box labels on delivered parts are a delight. Give them the 'THIS SIDE UP' arrows."
- "I want a little paper puff of dust when Dan builds something."
- "The BrookOS wallpaper with the cut-paper hills fits the style perfectly. Add a paper cursor."

### 8. Homelab / datacenter veteran
- "Pricing is plausible for the used market: $55 for a 2016 1U, $45 for an open-frame 12U, $25 for an ex-bank 24-port, $60 for a 1500VA with a fresh battery. The old $140 electrician was a dream; $95 is a 'cousin of Kevin' price. Fine for satire."
- "The power model passed every sanity check (bill = W × 24 h × $0.16, servers ≥ 150 W each, fans never add heat) across 22,000 farm inspections. The 180 W server is honest, if a bit low for dual Xeons under load."
- "The circuit cap (2 servers per household circuit) and the 'won't come online: you need a switch' messages are the most real thing in the garage."
- "The textbook order (rack, switch, compute, then the UPS before you scale) is now viable, but money is the wall: 22,029 'can't afford' looks. I rarely got past 2 online in one week."
- "Outages without a UPS hit about 1 night in 8. With a UPS and fans it's much lower. That's the right lesson. Show *why* each outage happened in FarmStat."
- "Assembly is order-correct (rack before cable before power). I'd add one realism beat: 'rails don't fit the rack', fixed with a zip tie."
- "Missing: a thermal or noise readout in °C/dB, a 'kill-a-watt' item, and drives that actually fail (RAID rebuild night)."
- "The data-center ending at 5% of my weeks feels earned now. Before, any two boxes won. Good tune."

### 9. Tycoon / management-sim fan
- "Payback math: about $14/day per server against $55 capex is roughly 4 days to pay back. Inside a one-week game, that's the only reason the farm matters. Keep payback ≤ 4 days."
- "Progression is too flat. My greedy-ROI policy stalled at 1 server online in all 300 weeks: a second server earns $0 until a rack *and* a switch exist, so pure ROI never sees the unlock. Show 'unlocks +$14/day' on rack/switch tooltips. RCT shows you the ride before you build the queue."
- "I ended with the most money of anyone ($154) and an 'uptime'/'real' ending, but the girls were at 39. The game punishes neglect the right way."
- "I want a scaling curve across weeks (the design doc's Path B): rack 2, colo contracts, Town Sentiment. One week is a tutorial."
- "Noise and heat need visible counter-play beyond fans and foam: an 'eco mode' that trades income for Jess's patience."
- "The power bill at under $1/day is invisible. Show it as a utility-bill event on Sunday."
- "Factorio lesson: show throughput. FarmStat should graph $/day for each day of the week."
- "The ending is gated on the family, not just money, so a pure min-maxer can't win it. That's the right call for this game."

### 10. Parent and family therapist
- "I slipped once on day 1, then chose honesty and repair every time. 300 weeks, 100% 'real' ending. The game honours repair without pretending it's instant. I like that."
- "But Jess ended at about 48 on average while the girls hit 100. Repair with your partner is slower than with kids, which is true, but here it reads as unrewarded. Telling the truth (the honest talk, calling Dr. Patel) should visibly move closeness, or at least unlock a scene."
- "The 'jess70' moment fired in 5 of 300 weeks. The marriage arc needs a reachable warm beat for a parent who is trying."
- "Substance lines are observational, never shaming. 'The little voice that counts the pills' is exactly the right register. Keep it."
- "No harsh or contemptuous lines were found once the detector stopped flagging 'closer'. The compassion bar is met."
- "Per-child attention (Lily reading, June chaos) models real parenting. Two kids, not one meter."
- "Fairness: staying late costs both Jess and the girls (−5/−6) with a clear LifeOS line. That's transparent. Good."
- "Cringe check: 'late-stage capitalism' and 'Navy SEAL' read as internet-voice, not Jess or LifeOS. Mild, but they pull you out."
- "Garage time costs closeness in the evening. Please also add a scene where Jess sets a boundary about it, not just a meter tick."

### 11. Accessibility / UX tester
- "I played 300 weeks keyboard-only. Over 51,000 actions came through station keys 1–4, about 9,500 through global keys, and 2,650 hints through the H key. Nothing required a mouse after the focus fix."
- "Fixed: the desktop and its windows had no keyboard focus; map pins were under 24 px."
- "Font sizes: nothing is below 12 px, but 13 px text is everywhere (shop rows, map pins, FarmStat tips). Please add a text-size option (100/125/150%) and make 14 px the floor."
- "The dialogue font passes (≥14 px). The typewriter is 48 cps, and the first Enter finishes the line. Good. Add a 'text speed' setting."
- "Color: meters use color plus labels, so they're fine for colour-blind players. Server LEDs are green/red only; add a shape or blink so the difference isn't colour alone."
- "Map: number keys plus arrows/Enter work. Locked pins show 🔒 plus a reason. Good parity."
- "Terminal: Tab completion never suggested a wrong prefix. H works when the input isn't focused. Show 'H = hint' in the prompt."
- "The desktop has no visible focus ring on the icons. The theme's focus style is thin; make it thicker."
- "Escape is consistent (window → desktop → room). Please also show 'Esc' on the taskbar."

### 12. Comedy writer
- "3,400 unique lines, 127,772 shown. The writing range is big, but repetition is the killer. Top repeats: the extra-Rx line (5,685), 'Pouch in…' (2,727) and the play variants (~1,900 each)."
- "The best bits are character jokes: June's shoes 'quietly resign', 'the trombone was persuasive', 'Nobody releases the cat. The cat has been through enough.' More of that, less internet voice."
- "LifeOS works as a sad, earnest app. It's funniest when it apologises ('LifeOS is so sorry'). Don't make it snarky."
- "Timing: punchlines land at the end of the line. Keep that discipline. Some lines stack two jokes ('Time: gone. Into the void. Worth it, probably.'). Cut to one."
- "Gary is underused. He's the best straight man in the game."
- "Rule of three: the 'incidents' bits (shoes, Wi-Fi, cat) are strong. Make it a recurring format with a weekly callback."
- "Cringe: the internet-voice lines (see rewrites). Only one was clearly cringe and was applied (below); the rest are proposals."

## Comedy writer: line rewrites (before → after)

Applied (clearly cringe): **#1** only. The others are proposals for Marty.

| # | Where | Before | After (proposed) | Why |
|---|---|---|---|---|
| 1 ✅ applied | Jess text (`game_state.gd` texts) | "Hospital gave us pizza instead of a raise again. Saved you a slice of late-stage capitalism. ❤" | "Hospital gave us pizza instead of a raise again. Saved you a slice. It is the one with the burnt corner. It is yours. ❤" | Internet-voice slogan; Jess is warm and specific, not online |
| 2 | Wake cutscene (LifeOS) | "You slept 4h 51m. That's 18% more than a Navy SEAL. … Let's crush today! (Gently.)" | "You slept 4h 51m. LifeOS has rounded this up to 'a night'. Let's crush today. (Gently. Like a grape.)" | The Navy SEAL bit is a stale hustle-culture reference; the grape lands on the last word |
| 3 | Pouch (repeats ~9×/week) | "Pouch in. A brief, quiet calm. Upper lip, left side, same spot as always." | Keep as #1, and add: "Pouch in. Your lip has a reserved parking spot." / "Pouch in. Calm arrives on schedule. It's the only thing that does." | Repetition fatigue: 2,727 shows |
| 4 | Gaming | "One more match. Stress down. Time: gone. Into the void. Worth it, probably." | "One more match. Stress down. Time: gone. Worth it, probably." | Two button jokes stacked; cut "Into the void" |
| 5 | Jess (after texts) | "Thanks for texting today. It really helped." | Rotate: "Thanks for texting today. It really helped." / "Your text came in during a code blue. I read it after. It still counted." / "You texted. I noticed. That's the whole review." | 904 repeats; sincere is right, sameness isn't |
| 6 | Dan to Gary (work) | "(Sysadmin Brain: It's DNS.)  Sure thing, Gary." | "(Sysadmin Brain: It's DNS.) (Sysadmin Mouth: …) Sure thing, Gary." | The gap between brain and mouth is the joke; give it a beat |
| 7 | Bedtime summary | "Lights out." | "Lights out. June asks for water. Lights out again." | 1,087 repeats of a dead line; a tiny story fits the slot |
| 8 | Stayed late (LifeOS) | "Stayed late. June asked after-care if Daddy 'lives at work now'. Jess: -5, Girls: -6." | "Stayed late. June asked after-care if Daddy 'lives at work now'. The after-care lady didn't have a good answer. Jess: -5, Girls: -6." | The sting lands harder with a witness; tone stays gentle |
| 9 | Coffee break | "Coffee with the team. Karen shows everyone her new puppy. You feel a little more human." | Rotate the puppy: "…Karen's puppy has learned 'sit'. Gary has not." | 1,583 repeats; Gary is the underused straight man |
| 10 | Rx (normal dose) | "Rx taken. The 47 browser tabs close themselves, emotionally. Focus: on." | Keep (strong), but add: "Rx taken. Your brain closes the tabs. One stays open. It's always the one about the dishwasher." | Repetition; ties back to Jess's dishwasher "Noise" text |
| 11 | Ticket closed (LifeOS) | "Ticket closed! 1 down, ∞ to go. Somebody's day just got easier, though." | "Ticket closed! 1 down, ∞ to go. Somewhere a printer is printing. You did that." | Callback to June's printer dream |
| 12 | Garage server build | "Racked, cabled, powered on. The fans spin up like a jet that has given up on flying." | "Racked, cabled, powered on. The fans spin up. Somewhere in the house, Jess sighs in the same key." | Ties the farm to the marriage cost (the therapist's ask) |

## Consolidated, prioritized roadmap

**P0: ship-blockers and fairness (next pass)**
1. **Terminal newbie breach rate (94%).** Add a "show me" hint that teaches the command, scale SLAs further at Lv 0–1, and keep autopilot available on a PIP (once per day). *(newbie, a11y)*
2. **Marriage repair is invisible.** Honest choices and the Dr. Patel call should move Jess's closeness, and a reachable warm scene should exist for a recovering dad. Today the therapist ends at Jess 48 and `jess70` fires in 2% of weeks. *(therapist)*
3. **Repetition fatigue.** Rotate result lines for pouch, coffee, gaming, bedtime and Jess's thank-you text, starting with comedy rewrites #3, #5, #7 and #9. *(comedy)*
4. **Text-size option** (100/125/150%) and a 14 px floor for shop rows, map pins and FarmStat. *(a11y)*

**P1: farm and progression**
5. Rack and switch tooltips that show what they unlock ("+1 server online, +$14/day"), so value-driven players can see the next tier. *(tycoon)*
6. FarmStat history graph ($/day, watts, outage cause), a Sunday power-bill event, and outage causes in the log. *(tycoon, homelab)*
7. Homelab ending rate is now 1–5% for builders (0% for pure min-maxers). Watch it: if Marty wants about 10% for dedicated builders, lower `HOMELAB_NET` to 25 or the server price to $50. *(tuning)*
8. Jess boundary scene about the garage, and the comedy writer's #12 build line tying the farm to the marriage. *(therapist, comedy)*
9. Realism beats: rails that don't fit, a drive-failure / RAID-rebuild night, °C/dB readouts. *(homelab)*

**P2: polish**
10. Dialogue banner still covers wall signs about 1.6% of lines (578 of 36,890); extend the keep-out list to farm and garage signs. *(paperfan, a11y)*
11. A thicker focus ring on desktop icons, a visible Esc hint on the taskbar, a text-speed option, and shape or blink on server LEDs (not colour alone). *(a11y)*
12. Achievements screen and a "skip seen dialogue" option. *(completionist, speedrunner)*
13. A clean any% route for speedrunners (every speedrun ends `foggy`). *(speedrunner)*
14. Lily or June inviting the cozy player to see the "blinky lights", a soft on-ramp to the garage. *(cozy)*

**P3: next milestone**
15. Win Path B beyond the first week: second rack, colo contracts, Town Sentiment and "Five Nines", as in design doc §B. *(tycoon, homelab)*

## Pass 3 (1000 weeks × 12 personas)

Every persona ran **1000 fresh playthroughs**, one full week each, with a new save and seed every time. That is 12,000 weeks, 84,000 days and about 1.99 M actions. Logs and summaries are in `playtest_pass3/`.

**Playthroughs per persona:** 1000 each for sysadmin, cozy, speedrunner, newbie, struggling, completionist, paperfan, homelab, tycoon, therapist, a11y and comedy. The tycoon count is from the rerun after its bot fix; the first 1000-run tycoon pass is kept in `playtest_pass3/tycoon_v1/`.

**Problems: 0 across all 12 personas** (final runs).

### Roadmap status
- Comedy rewrites #2–#12: done, one commit each. #1 was applied in pass 2.
- P0.1 Show me / wider slack / PIP autopilot · P0.2 visible repair · P0.3 repetition (covered by the rewrites) · P0.4 text size.
- P1.5 shop unlock lines · P1.6 FarmStat history + power bill · P1.7 `HOMELAB_NET` 25 · P1.8 garage-boundary scene · P1.9 rails / RAID-rebuild night / °C and dB.
- P2.10 compact-banner fallback · P2.11 focus ring, taskbar key hints, blinking LEDs, text speed, terminal key hints · P2.12 Trophies app + F4 instant seen dialogue · P2.13 Clean Sprint achievement · P2.14 blinky-lights girls moment.
- P3.15 (Path B beyond one week): **deferred** to the next milestone. It is too large for a polish pass.

### Bugs found and fixed
1. **The compact banner pushed the "Enter / Esc" hint over the sidebar.** This came from the P2.10 change and showed up as about 250 problems in the first, aborted launch. In compact mode the hint is now hidden and the banner grows inward. That launch was restarted and its logs are in `aborted_run1/`.
2. **Tycoon bot stalled at 1 server.** Drives always had the best single-item return, so the bot never scaled up. It now climbs a cumulative tier ladder (server → rack → switch → server → electrician). Max online went from 1 to 2, and the uptime ending went from 24% to 22% with more real/turning endings. This was a bot bug; the game itself was fine.

### Results vs pass 2
- **Homelab ending:** 6% for the homelab persona (was 1–5%). Completionist and sysadmin reach it 2% of the time.
- **Therapist:** Jess ends at 66 on average (was 48), and the `real` ending fires in 67% of runs. The repair scene works.
- **Newbie:** breached 791 of 956 hand-solved incidents (83%, was 94%) and used Show me 38k times. It is still high because the bot deliberately types nonsense 20% of the time. Next step: a Lv0 "guided" incident mode.
- **Speedrunner:** still ends `foggy` 99% of the time. The Clean Sprint achievement gives them a goal other than the ending.

### Full table
| Persona | Weeks | Problems | Endings | Breached / hand-solved incidents | Farm | Avg end state |
|---|---|---|---|---|---|---|
| a11y | 1000 | 0 | cozy 100% | 87/1687 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 0 perf 78 jess 96 girls 99 | drawings 9.6 bedtimes 4.4 | drinks 0.0 pouches 0.0 rx_extra 0.0 | money 48 |
| comedy | 1000 | 0 | foggy 99%, turning 0% | 86/1658 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 1 perf 70 jess 91 girls 89 | drawings 6.6 bedtimes 0.6 | drinks 2.7 pouches 9.7 rx_extra 20.5 | money 47 |
| completionist | 1000 | 0 | cozy 60%, turning 34%, foggy 3%, homelab 2% | 31/1782 | runs 1000 orders 6172 builds 3137 servers_online 1978 net $108308 outages 913 | stress 1 perf 33 jess 93 girls 96 | drawings 11.6 bedtimes 4.5 | drinks 0.7 pouches 2.0 rx_extra 2.0 | money 80 |
| cozy | 1000 | 0 | cozy 100% | 44/1401 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 5 perf 29 jess 97 girls 100 | drawings 13.1 bedtimes 7.0 | drinks 0.0 pouches 0.0 rx_extra 0.0 | money 80 |
| homelab | 1000 | 0 | cozy 62%, turning 20%, foggy 9%, homelab 6%, real 2% | 37/1548 | runs 998 orders 4022 builds 4013 servers_online 1834 net $80874 outages 855 | stress 0 perf 93 jess 90 girls 84 | drawings 4.4 bedtimes 3.0 | drinks 0.0 pouches 0.0 rx_extra 4.0 | money 54 |
| newbie | 1000 | 0 | turning 56%, cozy 37%, foggy 3%, real 1%, crispy 0% | 791/956 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 2 perf 21 jess 89 girls 92 | drawings 1.7 bedtimes 1.8 | drinks 0.7 pouches 1.3 rx_extra 2.4 | money 60 |
| paperfan | 1000 | 0 | cozy 100% | 60/1684 | runs 981 orders 2163 builds 2145 servers_online 981 net $71723 outages 672 | stress 0 perf 33 jess 96 girls 100 | drawings 9.9 bedtimes 2.2 | drinks 0.0 pouches 0.0 rx_extra 0.0 | money 45 |
| speedrunner | 1000 | 0 | foggy 99%, turning 0%, cozy 0% | 27/1603 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 0 perf 36 jess 82 girls 78 | drawings 3.2 bedtimes 0.7 | drinks 1.2 pouches 7.4 rx_extra 19.1 | money 44 |
| struggling | 1000 | 0 | turning 73%, foggy 26% | 286/1530 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 4 perf 72 jess 19 girls 15 | drawings 0.6 bedtimes 0.2 | drinks 15.9 pouches 16.4 rx_extra 8.8 | money 21 |
| sysadmin | 1000 | 0 | cozy 57%, turning 22%, foggy 12%, real 3%, homelab 2%, uptime 1% | 102/1581 | runs 1000 orders 4981 builds 4504 servers_online 1992 net $83778 outages 807 | stress 0 perf 94 jess 87 girls 81 | drawings 4.8 bedtimes 2.5 | drinks 0.0 pouches 0.0 rx_extra 4.4 | money 85 |
| therapist | 1000 | 0 | real 67%, cozy 32% | 76/1631 | runs 0 orders 0 builds 0 servers_online 0 net $0 outages 0 | stress 0 perf 55 jess 66 girls 100 | drawings 1.0 bedtimes 3.0 | drinks 0.0 pouches 0.0 rx_extra 0.0 | money 100 |
| tycoon | 1000 | 0 | real 42%, uptime 22%, turning 17%, cozy 11%, foggy 5% | 37/1336 | runs 1000 orders 6643 builds 6000 servers_online 2000 net $106933 outages 1074 | stress 1 perf 86 jess 69 girls 42 | drawings 3.0 bedtimes 0.0 | drinks 0.0 pouches 0.0 rx_extra 3.5 | money 76 |
