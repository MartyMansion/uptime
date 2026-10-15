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
	main.autoload_save = false
	root.add_child(main)

## Plays a standard day: breakfast, work tickets until 4, drive stop, evening.
func play_day(gs: Node, buy: Array, drinks: int, pouches: int) -> void:
	if gs.is_weekend():
		gs.beers += drinks if "buy_beer" in buy else 0
		gs.pouches += pouches if "buy_pouches" in buy else 0
		gs.do_action("pancakes")
		gs.minutes = maxi(gs.minutes, 1100)
		for i in drinks: gs.do_action("drink")
		for i in pouches: gs.do_action("pouch")
		gs.minutes = maxi(gs.minutes, 1170)
		gs.do_action("bedtime_story")
		gs.do_action("sleep")
		return
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
	check(gs.minutes == 540 and gs.energy == 82 and gs.performance == 54, "ticket costs 2 blocks / 10 energy, +4 perf")
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
	check(gs.energy == e - 5 and gs.performance == p + 7, "focused ticket: -5 energy, +7 perf")
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
	# --- Playtest regressions: no softlocks when exhausted
	gs.new_game(5)
	gs.do_action("leave_for_work")
	gs.energy = 3
	check(gs.can_do("coffee_break") == "" and gs.can_do("work_ticket") != "", "exhausted at work: coffee break available")
	gs.minutes = gs.OFF_WORK
	gs.do_action("head_home")
	gs.energy = 0
	check(gs.can_do("pickup_girls") == "", "0 energy: Dan can still pick up the girls")
	gs.new_game(6)
	gs.do_action("cereal")
	check(gs.can_do("cereal") != "", "breakfast/cereal once per morning")
	# --- Pass 2: weekends, cozy verbs, calendar, moments, quitting, save/load
	gs.new_game(11)
	for i in 5: play_day(gs, [], 0, 0)
	check(gs.day == 5 and gs.phase == "weekend" and gs.can_do("leave_for_work") != "", "Saturday is a home day (no work)")
	check(gs.can_do("pancakes") == "" and gs.calendar_text().begins_with("Saturday"), "weekend pancakes + calendar")
	var sm := [{}]
	gs.day_ended.connect(func(x): sm[0] = x, CONNECT_ONE_SHOT)
	gs.do_action("pancakes"); gs.minutes = 1080; gs.do_action("homework"); gs.do_action("tea_jess")
	check(gs.fridge_drawings >= 1, "homework adds a fridge drawing")
	gs.do_action("sleep")
	check(str(sm[0].get("moment", "")) != "", "day summary has a moment of the day")
	gs.new_game(12)
	gs.do_action("feed_girls"); gs.do_action("leave_for_work")
	var st0: int = gs.stress
	gs.do_action("breathe")
	check(gs.stress == maxi(st0 - 4, 0) and gs.minutes == 480, "breathe: free stress relief, competes with a pouch")
	gs.day = 3
	check(gs.can_do("concert") != "", "concert only in the evening on Thursday")
	gs.day = 0
	gs.pouches = 5; gs.do_action("pouch")
	var msgs: Array = []
	gs.lifeos_message.connect(func(t): msgs.append(t))
	gs.end_day(); gs.end_day(); gs.end_day()
	check(gs.clean["pouch"] == 2 and msgs.any(func(t): return "Cravings" in str(t)), "quitting pouches: clean streak + reward line")
	gs.fridge_drawings = 7
	check(gs.save_game("user://test_save.json"), "save game")
	gs.new_game(13)
	check(gs.load_game("user://test_save.json") and gs.fridge_drawings == 7 and gs.day == 3 and gs.clean["pouch"] == 2, "load game restores the morning")
	gs.delete_save("user://test_save.json")
	check(not gs.load_game("user://nope.json"), "missing save fails cleanly")
	# --- Choices in cutscenes
	gs.new_game(21)
	var wk: Array = Cutscenes.build("wake", gs, {})
	check(wk.any(func(st): return st[0] == "choice"), "Monday wake has the Shoes postmortem choice")
	gs.drinks_week = 9
	var jh: Array = Cutscenes.build("jess_home", gs, {})
	check(jh.any(func(st): return st[0] == "choice") and gs.notices_seen.has("real_talk"), "Jess real-talk choice after a heavy week")
	var c0: int = gs.closeness
	gs.apply_choice("talk_honest")
	check(gs.closeness == c0 + 8 and gs.honesty == 65 and gs.weekly_review().contains("Honesty"), "honest answer: closeness + honesty, noted in review")
	# --- Endings
	gs.new_game(41)
	gs.closeness = 80; gs.girls_connected = 80; gs.stress = 20
	check(gs.ending_id() == "cozy" and gs.weekly_review().contains("Pancake Sunday"), "cozy week -> Pancake Sunday ending")
	gs.week_stats["drinks"] = 20
	check(gs.ending_id() == "foggy", "heavy week -> Foggy ending")
	gs.notices_seen["choice_talk_honest"] = true
	check(gs.ending_id() == "turning", "honesty -> Turning Point ending")
	gs.stress = 80
	var cz: Array = Cutscenes.build("chaos", gs, {"n": 0})
	check(str(cz[-1][1][0][1]) == "chaos_calm", "high stress: the laugh option is out of reach in chaos events")
	gs.stress = 20
	var c1: int = gs.closeness
	gs.apply_choice("phone_draft")
	check(gs.closeness == mini(c1 + 2, 100), "phone: draft-and-delete heart reply")
	gs.new_game(61); gs.do_action("leave_for_work"); gs.minutes = 1480
	check(gs.can_do("head_home") == "" , "off-grid clock at 12:40 AM still has a way forward (no softlock)")
	gs.new_game(62)
	# --- Side hustle + achievements
	gs.new_game(51)
	gs.phase = "home_pm"; gs.minutes = 1200
	var m0: int = gs.money
	for i in 3:
		gs.today["side_hustle"] = 0
		gs.minutes = 1200
		gs.do_action("side_hustle")
	check(gs.hustle == 3 and gs.money == m0 + 50, "side hustle pays $50 on the 3rd session")
	gs.fridge_drawings = 10
	gs._check_achievements()
	check("gallery" in gs.achievements and "founder" in gs.achievements and gs.weekly_review().contains("Achievements"), "achievements unlock and show in the review")
	# --- Recovery tools
	gs.new_game(31)
	gs.do_action("feed_girls"); gs.do_action("leave_for_work")
	gs.do_action("call_doctor")
	check(gs.rx_plan, "calling the doctor sets an Rx plan")
	gs.do_action("rx_dose")
	var en: int = gs.energy
	gs.minutes = gs.rx_until
	gs._check_crash()
	check(gs.energy == maxi(en - 10, 0), "with a plan the Rx crash is gentler (-10)")
	gs.minutes = gs.OFF_WORK; gs.do_action("head_home"); gs.do_action("buy_patch")
	check(gs.patch_days == 5, "patches bought at the Gas-N-Sip")
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
		var walk: Array[Vector2] = main.loc.reachable(main.loc.spot("entry"))
		var unreachable: Array = []
		for sid in main.loc.stations:
			var r: Rect2 = main.loc.stations[sid]["rect"]
			if not walk.any(func(p): return main.loc.station_at(p) == sid):
				unreachable.append(sid)
		check(walk.size() > 100 and unreachable.is_empty(), "%s: furniture collision, every station reachable %s" % [n, unreachable])
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
