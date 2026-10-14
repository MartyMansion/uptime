# Uptime Devlog

## 2026-10-13 — Day 0: the skeleton boots
- Installed Godot 4.7.2-stable. Project created (GDScript, GL Compatibility renderer).
- Built the first playable skeleton of the "One Week" slice: house with Kitchen, Girls' room, PC desk and Bed; Dan moves with WASD/arrows.
- Time moves only when you act (30-min blocks). Energy 0–100, stress, job performance, Jess closeness, girls fed/connected.
- LifeOS pops up with upsells and KPI commentary. Day-end summary ("Sleep: 5h 30m. Productivity: Exceptional. Liver: Concerned."), and after Sunday the LifeOS Weekly Performance Review + stub ending card.
- Headless run and test script pass with zero errors.
- Next: phone overlay with real text choices, Ticket Triage minigame.

## 2026-10-14 — The drive home
- Days now have a shape: morning at home → Front door (drop-off + commute, 1 hr) → work (tickets until 4 PM) → **drive home stop** at the Gas-N-Sip → pick up the girls → evening at home.
- Marty's substance thread, kept quiet on purpose. No meters for it on the HUD; it shows up in people and the phone:
  - **Beer** (kitchen, evenings): -10 stress, nicks Jess Closeness, and makes sleep shallower (-12% sleep quality per drink). Jess notices around 4, 8 and 12 drinks a week ("recycling bin's clinking a lot this week").
  - **Nic pouches** (P, anywhere): -6 stress, no time. Hidden gum damage builds; dental reminders escalate to "Dr. Lin would like a closer look."
  - **Rx** (R): +15 energy and 6h of focus (tickets cost less, give more), then a -20 crash ("you skipped lunch (again)"), and worse sleep if taken late. Extra doses are allowed and tracked; LifeOS nudges you when you're low, and the pharmacy does the refill math.
- Weekly Review gets conditional lines (Hydration, Oral Health, Focus) that only appear if relevant.
- Tests: 25 checks pass headless.

## 2026-10-14 (evening) — It looks like a game now
Marty playtested on Windows (Godot 4.7): fonts overlapped and everything was rectangles. This pass:
- **Art:** `tools/gen_sprites.py` draws everything in Python/Pillow: 16x24 characters (Dan, Jess, Lily, June, Gary) with 4-direction 3-frame walks and a 2-frame idle bob, 32px portraits (+ a smug LifeOS phone), 16px tiles, ~25 props, little pixel-font signs (GAS-N-SIP, TRICOUNTY MANAGED, BROOKFIELD EL). Style guide and swap instructions in ASSETS.md.
- **UI:** rebuilt with containers and a single Theme. Top bar (day, clock, location, energy), right sidebar (money/fridge/tin, meters, controls, last event), bottom action prompt (wraps to 3 lines), LifeOS toast and dialogue box anchored inside the world area, centered summary modal. Stretch mode keep-aspect so it letterboxes instead of squashing. `main.audit_ui()` checks every visible label for overlap/out-of-bounds; 0 problems at 1280x720, 1920x1080, 1366x768, 1024x768 and 800x600.
- **Scenes:** House (bedroom, kitchen, girls' room, living room), TriCounty office (desks, server room, Gary's corner), Gas-N-Sip (store + lot), Brookfield Elementary curb. The phase decides the scene; no more overlays.
- **Cutscenes:** small step-script system (place/move/face/say/lifeos/dim/wait), Enter to advance, Esc to skip. Nine of them: wake-up ("Shoes, a Postmortem" on Monday), drop-off, arriving at work (Gary of the day), the drive-home stop (4 AM Club on the radio), pickup (Lily notices the gas-station smell if you stopped), Jess comes home (and quietly sits far away if Closeness is low), bedtime (dragon voice), day-end (lights down + LifeOS sleep report), weekly review (pancakes).
- Tests: 45 checks, including scene switching, cutscene triggers, portraits, sprite sheet layout and the UI audit.

## 2026-10-14 (night) — Playtester pass: 100 weeks, softer heart
A Stardew-loving playtester bot (`tests/playtest_bot.gd`) now plays full weeks through the real Main scene, cutscenes and all, with 10 strategies (random, workaholic, family-first, heavy drinking/pouches/Rx, all-skip, night owl/1 AM timeouts, Rx spam, balanced, broke, "Stardew"). It checks meter ranges, money/inventory, clock overruns, scene/phase mismatch, softlocks and stuck days, runs `audit_ui()` on gameplay, dialogue and summaries, and logs every line shown.
- **First run (100 weeks): 222 problems.** Fixed:
  - Softlock at work: under 10 energy before 4 PM there was nothing to do (156 hits). Added a **Coffee break** at Your desk (+8 energy, -4 stress, 30 min).
  - Softlock on the drive home: picking up the girls cost 3 energy, so Dan at 0-2 energy couldn't leave the Gas-N-Sip (60+ hits). Travel (leave for work, head home, pick up girls) no longer needs energy.
  - Breakfast/cereal could be repeated all morning (6,497 cereals in one run batch, draining Connected to 0). Now once per morning each.
- **Rerun: 100 weeks, 700 days, ~16k actions, ~1.5k UI audits, 0 problems.** All actions and all 9 cutscenes triggered.
- **Tone pass** (Marty: too much black comedy/meanness): ~110 strings rewritten across cutscenes, LifeOS, Jess, the girls, Gary, tickets, summaries, review and ending. Gary is a decent boss, LifeOS is silly-sweet instead of upselling, tickets end with small wins, the 4 AM Club is gentle, and the substance thread reads as concern (Jess checks in, Dr. Lin asks you to come in, LifeOS suggests talking to the doctor), never mockery. Logic unchanged.
- Tests: 48 checks pass. Report: `/workspace/uptime-build/PLAYTEST_REPORT.md`.

## 2026-10-14 (night) — Refinement hour, iteration 1: weekends, evenings, cozy loops, quitting, saves
- **Weekends are home days.** Saturday/Sunday start in a new `weekend` phase at the house: pancakes, chores with Jess, the park, homework/drawing, tea, games, bedtime. No drop-off, no office, no Gas-N-Sip.
- **The 4:30–7:30 PM gap is filled:** family dinner, homework & drawing, walk to the park, tea on the couch with Jess, a walk around the block. A LifeOS nudge at 7:30 points to the bedtime story.
- **Non-substance stress relief that competes:** B = box breathing (free, -5 stress, 3/day, works anywhere, same speed as a pouch), walk around the block (-12 stress, +4 energy), tea with Jess, the park, coffee break at work.
- **Cozy loops:** fridge drawing gallery (homework, park, bedtime, concert), shown in the HUD, the summary and the review. Relationship moments at Jess 70/85 and girls 75/90. A calendar line in the HUD (picture day, taco Wednesday, Lily's Thursday recorder concert as a real action, pizza Friday, Sunday on-call). Every day summary leads with a **Moment of the day**.
- **Quitting paths:** clean-day streaks for beer, pouches and extra Rx after use. At 2 and 4 clean days, people notice (Jess, Dr. Lin, the pharmacist) and there's a small stat reward. Streaks appear on the weekly review.
- **Save/load:** autosave every morning (`user://uptime_save.json`), continue on launch, F6 save, F7 load.
- Bot: +2 strategies (cozy, quitter). 100 weeks, 0 problems. Tests: 58 pass.
