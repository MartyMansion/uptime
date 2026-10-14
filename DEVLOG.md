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
