extends SceneTree
## Headless test: godot --headless --path . -s res://tests/run_tests.gd

var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		printerr("FAIL: ", msg)

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

## Plays a standard day: breakfast, work tickets until 4, drive stop, evening.
func play_day(gs: Node, buy: Array, drinks: int, pouches: int) -> void:
	gs.do_action("feed_girls")
	gs.do_action("leave_for_work")
	while gs.minutes < gs.OFF_WORK:
		gs.do_action("work_ticket")
	gs.do_action("head_home")
	for b in buy:
		gs.do_action(b)
	gs.do_action("pickup_girls")
	for i in drinks:
		gs.do_action("drink")
	for i in pouches:
		gs.do_action("pouch")
	gs.minutes = maxi(gs.minutes, 1170)
	gs.do_action("bedtime_story")
	gs.do_action("sleep")

func _process(_d: float) -> bool:
	var gs: Node = root.get_node("GameState")
	var main: Node = root.get_node("Main")
	gs.new_game(42)
	# --- Basics + phase flow
	check(gs.clock_text() == "6:30 AM" and gs.phase == "home_am", "day starts 6:30 AM at home")
	gs.do_action("feed_girls")
	check(gs.minutes == 420 and gs.energy == 95, "breakfast costs 1 block / 5 energy")
	check(gs.can_do("work_ticket") != "", "can't work tickets before leaving home")
	check(gs.can_do("drink") != "", "no drinking in the morning")
	gs.do_action("leave_for_work")
	check(gs.phase == "work" and gs.minutes == 480, "leave for work: 2 blocks, phase=work")
	gs.do_action("work_ticket")
	check(gs.minutes == 540 and gs.energy == 82 and gs.performance == 58, "ticket costs 2 blocks / 10 energy, +perf")
	var m: int = gs.minutes
	gs.do_action("text_jess")
	check(gs.minutes == m and gs.closeness == 56, "texting Jess costs no time, +closeness")
	check(gs.can_do("head_home") != "", "can't leave before 4 PM")
	# --- Rx: focus, crash, extra dose
	var e: int = gs.energy
	gs.do_action("rx_dose")
	check(gs.energy == e + 15 and gs.rx_active(), "Rx gives +15 energy and focus")
	e = gs.energy
	var p: int = gs.performance
	gs.do_action("work_ticket")
	check(gs.energy == e - 5 and gs.performance == p + 12, "focused ticket: -5 energy, +12 perf")
	e = gs.energy
	while gs.rx_active():
		gs.do_action("work_ticket")
	check(gs.today["crashed"], "Rx wears off -> crash")
	gs.do_action("rx_dose")
	check(gs.rx_extra_total == 1 and gs.week_stats["rx_extra"] == 1, "second dose counted as extra")
	# --- Drive home stop
	while gs.minutes < gs.OFF_WORK:
		gs.do_action("work_ticket")
	gs.do_action("head_home")
	check(gs.phase == "drive", "head home -> gas station stop")
	var money: int = gs.money
	gs.do_action("buy_beer")
	gs.do_action("buy_pouches")
	check(gs.beers == 6 and gs.pouches == 15 and gs.money == money - 19, "bought six-pack + tin")
	gs.do_action("pickup_girls")
	check(gs.phase == "home_pm", "pick up girls -> home evening")
	main.perform("play_girls")  # exercise UI path
	# --- Alcohol
	var c: int = gs.closeness
	gs.do_action("drink"); gs.do_action("drink"); gs.do_action("drink")
	check(gs.closeness < c and gs.beers == 3, "drinks lower closeness")
	# --- Nicotine
	var s: int = gs.stress
	gs.do_action("pouch")
	check(gs.stress == maxi(s - 6, 0) and gs.gum_damage == 1, "pouch: stress relief, hidden gum damage")
	gs.minutes = 1170
	gs.do_action("bedtime_story")
	check(gs.week_stats["bedtimes"] == 1, "bedtime story counted")
	var sleep_q := [-1]
	gs.day_ended.connect(func(sm): sleep_q[0] = sm["sleep_quality"], CONNECT_ONE_SHOT)
	gs.do_action("sleep")
	check(sleep_q[0] < 70, "drinks + late Rx hurt sleep quality (%d%%)" % sleep_q[0])
	check(gs.day == 1 and gs.phase == "home_am", "sleep advances to Tuesday morning")
	# Clean day sleeps better
	gs.day_ended.connect(func(sm): sleep_q[0] = sm["sleep_quality"], CONNECT_ONE_SHOT)
	play_day(gs, [], 0, 0)
	check(sleep_q[0] == 100, "sober day: full sleep quality")
	# Heavy rest of week -> Jess notices, dentist notes
	var notices: Array = []
	gs.lifeos_message.connect(func(t): notices.append(t))
	for i in 5:
		play_day(gs, ["buy_beer", "buy_pouches"], 3, 5)
	check(gs.week_over, "week ends after Sunday")
	check(notices.any(func(t): return str(t).begins_with("Jess: can we talk")), "Jess notices drinking over time")
	check(notices.any(func(t): return str(t).contains("Dr. Lin")), "dentist note appears after sustained pouch use")
	var review: String = gs.weekly_review()
	check(review.begins_with("LIFEOS") and review.contains("Oral Health") and review.contains("Hydration"), "weekly review includes subtle lines")
	print(review)
	# --- Scenes, cutscenes, assets, UI
	main.skip_all_cutscenes()
	main.dismiss_summary() if main.summary_root.visible else null
	gs.new_game(9)
	main.skip_all_cutscenes()
	main.summary_root.visible = false
	main.sync_location()
	check(main.loc_name == "house", "home phase loads the house scene")
	for n in ["house", "office", "gas_station", "school"]:
		main.load_location(n)
		var ok := true
		for sid in main.loc.stations:
			for aid in main.loc.stations[sid]["actions"]:
				ok = ok and gs.ACTIONS.has(aid)
		check(ok and main.loc.spots.has("entry"), "location %s loads with valid stations" % n)
	main.sync_location()
	main.perform("leave_for_work")
	check(main.cs_id == "dropoff", "leaving for work plays the drop-off cutscene")
	main.skip_all_cutscenes()
	check(main.loc_name == "office" and main.loc.actors.has("gary"), "arrive at office with Gary")
	gs.minutes = gs.OFF_WORK
	main.perform("head_home")
	main.skip_all_cutscenes()
	check(main.loc_name == "gas_station", "drive home stop is the Gas-N-Sip scene")
	main.perform("pickup_girls")
	check(main.cs_id == "pickup", "pickup cutscene at school")
	main.skip_all_cutscenes()
	check(main.loc_name == "house" and main.loc.actors.has("jess"), "evening at home with Jess")
	var all_ok := true
	for id in Cutscenes.IDS:
		var steps: Array = Cutscenes.build(id, gs, {})
		if steps.is_empty():
			all_ok = false
			printerr("empty cutscene ", id)
		for st in steps:
			if st[0] == "say" and st[1] in ["dan", "jess", "lily", "june", "gary"] and not ResourceLoader.exists("res://assets/portraits/%s.png" % st[1]):
				all_ok = false
	check(all_ok, "all %d cutscenes build with portraits" % Cutscenes.IDS.size())
	main.perform("sleep")
	check(main.cs_id == "day_end", "sleep plays the day-end cutscene")
	main.skip_all_cutscenes()
	check(main.summary_root.visible, "day summary shown after the cutscene")
	main.dismiss_summary()
	check(main.cs_id == "wake", "next morning plays the wake-up cutscene")
	main.skip_all_cutscenes()
	for n in ["dan", "jess", "lily", "june", "gary"]:
		var t: Texture2D = load("res://assets/sprites/characters/%s.png" % n)
		check(t.get_width() == 64 and t.get_height() == 96, "%s sheet is 4 dirs x (3 walk + 1 idle)" % n)
	var probs: Array[String] = main.audit_ui()
	for x in probs:
		printerr("  ", x)
	check(probs.is_empty(), "UI audit: no overlapping/out-of-bounds labels")
	print("TESTS DONE: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
	return true
