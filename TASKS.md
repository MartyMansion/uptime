# Uptime — Task Roadmap

Source of truth: `/workspace/game-design/uptime-game-design-doc-v2.md` (§2.5 One Week slice, §6.2 milestones).

## M0 — Skeleton (DONE, 2026-10-13)
- [x] Godot 4.7 project, GameState autoload, house scene (placeholder rects)
- [x] Movable Dan, day clock (30-min blocks, 6:30 AM–1:00 AM), energy bar, needs meters
- [x] Actions: breakfast / cereal, play with girls, bedtime story, work ticket, gaming, text Jess, sleep
- [x] LifeOS notification popup, day-end summary, 7-day week + Weekly Performance Review stub
- [x] Headless test (`tests/run_tests.gd`)

## M0.5 — Day flow + substance thread (DONE, 2026-10-14)
- [x] Day phases: home morning → drop-off/commute → work → drive home (Gas-N-Sip stop) → pick up girls → home evening
- [x] Drive-home stop: buy six-pack ($12), nic pouches ($7), both, or just drive on
- [x] Alcohol: stress relief, lowers Jess Closeness, lowers sleep quality; Jess notices at 4/8/12 drinks a week
- [x] Nicotine pouches: short stress relief, hidden gum damage → dentist/LifeOS notes, review line
- [x] Amphetamine Rx: +energy, focused tickets, crash after 6h, hurts sleep, "skipped lunch"; extra doses tracked → refill math note
- [x] Tests for the phase flow and all three substances

## M0.6 — Art, UI, scenes, cutscenes (DONE, 2026-10-14)
- [x] Original procedural pixel art (tools/gen_sprites.py): Dan/Jess/Lily/June/Gary 4-dir walk + idle, portraits, tiles, props; ASSETS.md style guide
- [x] UI rebuilt with containers + theme (top bar, sidebar meters, bottom prompt, LifeOS toast, dialogue box, summary modal); stretch keep-aspect
- [x] UI audit (no overlapping/out-of-bounds labels) in tests + screenshots at 1280x720, 1920x1080, 1366x768, 1024x768, 800x600
- [x] Real scenes: House, TriCounty office, Gas-N-Sip, Brookfield Elementary; switched per phase
- [x] Cutscenes with portraits + movement: wake-up, drop-off, arrive at work/Gary, drive-home stop, pickup, Jess home, bedtime, day-end, weekly review

## M1 — Grey-box day (design doc Phase 1)
- [x] Phone overlay with 3 real text threads + reply choices (thoughtful / "k 👍" / draft-and-delete)
- [ ] Ticket Triage minigame (drag tickets to Fix / Escalate / Schedule / Off-and-on)
- [x] Per-girl needs (Fed / Rested / Connected for Lily and June)
- [x] Stress effects; Running on Fumes greys out kind options
- [x] Collision with furniture; door transitions between rooms
- [x] Choices inside cutscenes (e.g. "Shoes, a Postmortem" P1 incident choice)
- [x] Car/commute scene with the 4 AM Club podcast as an interactive radio
- [ ] Substance thread: longer arcs over weeks (cancer-risk scare at the dentist, honest Rx talk with doctor, Jess real-talk scene tied to Honesty)
- [ ] Substance choices feed Honesty/Integrity meters and ending tone
- [ ] Content check: sensitivity read on substance writing (stay non-preachy, never mock)

## M2 — One Week vertical slice (Phase 2)
- [ ] ~12 Jess conversations, dinner scene with branching dialogue
- [ ] Outage Response minigame + one on-call page at a bad moment
- [ ] AI side hustle Tier 1 (first script, first $50 for Marisol's bakery)
- [ ] ~25 ticket jokes, ~30 LifeOS notifications, 5 achievements
- [x] Chaos events (June + Blu-ray crayon), "one more match" prompt
- [x] Save/load
- [ ] Commissioned/final art pass replacing generated placeholders (see ASSETS.md); comedy pass; 5–10 outside playtesters

## M3+ — Chapter 1 demo, Chapters 2–4, beta, launch (see doc §6.2)

## Playtester follow-ups (from the 100-run pass)
- [x] Automated playtest harness (tests/playtest_bot.gd), 100 weeks clean
- [x] Fix work/drive softlocks; breakfast once per morning; coffee break at work
- [x] Tone pass: warm, Stardew-style dialogue; substance thread as concern, not mockery
- [x] Weekends: home days (park, pancakes, chores, on-call page)
- [x] Fill the 4:30-7:30 PM gap: dinner (+conversation), homework, park, walk, tea, side hustle
- [x] 7:30 PM "Lily is waiting with a book" nudge
- [x] Moment of the day in the summary
- [x] Fridge drawing gallery (visible on the fridge) — [ ] porch plant, Lego castle
- [ ] Recovery paths as playable as the habits (see backlog)

## Refinement hour (done)
- [x] Calendar + Lily's concert; relationship heart events; achievements (5); six endings
- [x] Recovery: patches, doctor call / Rx plan, clean-day streaks, Jess real-talk choice + hidden Honesty
- [x] Ticket triage choices; Wednesday bedtime page; AI side hustle tier 1 (Marisol's bakery)
- [ ] Next: Lily/June visible meters, porch plant, multi-week arcs, real ticket-triage minigame UI, sound

## Marty ideas backlog
- [x] Subtle substance-use thread: alcohol (marriage, sleep), nicotine pouches (gum damage, cancer risk via dentist), prescription amphetamines (focus/crash, extra-dose temptation) — skeleton in M0.5
- [x] Daily drive-home stop (gas station/liquor) between work and picking up the girls — M0.5
- [x] Recovery/quitting paths that are as playable as the habits (patches, "dry January" LifeOS upsell, talking to Jess)
- [ ] Withdrawal/tolerance tuning across multiple weeks
- [x] Sprites for everyone, fix overlapping fonts, real scenes + cutscenes (after Windows playtest) — M0.6
