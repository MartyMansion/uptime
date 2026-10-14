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
