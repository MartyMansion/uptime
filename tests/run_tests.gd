extends SceneTree
## Headless test: godot --headless --path . -s res://tests/run_tests.gd

var failures := 0

func await_free_audit(main: Node) -> void:
	var probs: Array = main.audit_ui().filter(func(x): return "map" in str(x))
	check(probs.is_empty(), "map buttons inside the game area, no overlap %s" % [probs])

func main_walkaway_check(wm: int) -> void:
	var gs: Node = root.get_node("GameState")
	check(gs.charge_walkaway(2) == 0 and gs.minutes == wm, "a quick peek and walk away is free")
	check(gs.charge_walkaway(5) == 30 and gs.minutes == wm + 30, "walking away after 5 commands costs 30 min")
	check(gs.charge_walkaway(20) == 60, "walking away after 20 commands costs an hour")
	gs.minutes = gs.DAY_END
	check(gs.can_do("head_home") == "", "at the desk at 1 AM you can still drive home (no softlock)")
	gs.do_action("head_home"); gs.travel("gas")
	check(gs.phase in ["drive", "home_am"] and gs.minutes <= gs.DAY_END, "driving home at 1 AM ends the day cleanly")

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		printerr("FAIL: ", msg)

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.autoload_save = false
	main.use_map = false   # map has its own tests below
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
	while not gs.can_leave_work() and gs.can_do("work_ticket") == "":
		gs.do_action("work_ticket")
	gs.do_action("head_home"); gs.travel("gas")
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
	check(gs.minutes == 630 and gs.energy == 80 and gs.performance == 53, "office ticket ~2.5 h / 12 energy, +3 perf (got %d %d %d)" % [gs.minutes, gs.energy, gs.performance])
	var m: int = gs.minutes
	gs.do_action("text_jess")
	check(gs.minutes == m and gs.closeness == 56, "texting Jess costs no time, +closeness")
	check(gs.can_do("head_home") != "", "can't leave after just 1 ticket in the morning")
	# --- Rx: focus, crash, extra dose
	var e: int = gs.energy
	gs.do_action("rx_dose")
	check(gs.energy == e + 15 and gs.rx_active(), "Rx gives +15 energy and focus")
	e = gs.energy
	var p: int = gs.performance
	gs.do_action("work_ticket")
	check(gs.energy == e - 5 and gs.performance == p + 6, "focused ticket: -5 energy, +6 perf")
	check(gs.can_leave_work() and gs.can_do("head_home") == "", "2 tickets -> Head home unlocks (Marty: shorter workday)")
	var cl0: int = gs.closeness
	var gc0: int = gs.girls_connected
	gs.do_action("work_ticket")
	check(gs.closeness == cl0 - 5 and gs.girls_connected == gc0 - 6, "3rd ticket = staying late: costs family time")
	check(gs.can_do("work_ticket") != "", "no 4th office ticket")
	e = gs.energy
	while gs.rx_active():
		gs.do_action("coffee_break")
	check(gs.today["crashed"], "Rx wears off -> crash")
	gs.do_action("rx_dose")
	check(gs.rx_extra_total == 1 and gs.week_stats["rx_extra"] == 1, "second dose counted as extra")
	# --- Drive home stop
	while not gs.can_leave_work() and gs.can_do("work_ticket") == "":
		gs.do_action("work_ticket")
	gs.do_action("head_home"); gs.travel("gas")
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
	gs.do_action("head_home"); gs.travel("gas")
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
	gs.fridge_drawings = 7
	gs.end_day(); gs.end_day(); gs.end_day()
	check(gs.clean["pouch"] == 2 and msgs.any(func(t): return "Cravings" in str(t)), "quitting pouches: clean streak + reward line")
	gs.fridge_drawings = 7
	check(gs.save_game("user://test_save.json"), "save game")
	gs.new_game(13)
	check(gs.load_game("user://test_save.json") and gs.fridge_drawings == 7 and gs.day == 3 and gs.clean["pouch"] == 2, "load game restores the morning")
	# Persona bug (speedrunner): mid-day saves stored afternoon meters + loading re-applied the morning stress.
	var sv_st: int = gs.stress
	var sv_en: int = gs.energy
	gs.do_action("leave_for_work")
	gs.stress = 77; gs.money += 500; gs.performance = 3
	check(gs.save_game("user://test_save.json"), "mid-day save")
	gs.load_game("user://test_save.json")
	check(gs.stress == sv_st and gs.energy == sv_en and gs.performance != 3 and gs.minutes == gs.DAY_START, "mid-day save + load = the exact morning (no afternoon meters)")
	gs.load_game("user://test_save.json"); gs.load_game("user://test_save.json")
	check(gs.stress == sv_st, "reloading the same save doesn't stack morning stress (%d vs %d)" % [gs.stress, sv_st])
	# Persona bug (newbie): walking away was free, freezing the clock at the desk.
	gs.new_game(5); gs.do_action("leave_for_work")
	var wm: int = gs.minutes
	main_walkaway_check(wm)
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
	# --- Town map (Marty: Stardew-style travel)
	main.use_map = true
	gs.new_game(91); main.skip_all_cutscenes(); main.summary_root.visible = false; main.sync_location()
	main.perform("leave_for_work")
	check(main.map_open() and gs.phase == "home_am", "leaving the house opens the town map")
	check(main.map_order == ["office"], "morning: only the office (drop-off on the way) is selectable")
	var ek := InputEventKey.new(); ek.keycode = KEY_1; ek.pressed = true
	main._unhandled_input(ek)
	check(not main.map_open() and gs.phase == "work", "keyboard [1] travels to the office")
	main.skip_all_cutscenes()
	gs.today["tickets"] = 2
	main.perform("head_home"); main.skip_all_cutscenes(); main.auto_map()
	check(main.map_open() and gs.phase == "drive" and gs.at_place == "road", "badging out shows the map")
	var opts := {}
	for o in gs.map_options(): opts[o[0]] = o
	check(opts["home"][3] != "" and "Pick up" in opts["home"][3], "home is locked until the girls are picked up")
	check(opts["office"][3] != "" and opts["gas"][3] == "" and int(opts["gas"][2]) == 10, "office locked, Gas-N-Sip open with travel time")
	check(gs.minutes < gs.PICKUP_OPEN and opts["school"][3] != "", "school pickup locked before the after-care window")
	main.map_pick("gas")
	check(not main.map_open() and gs.at_place == "gas" and gs.can_do("buy_beer") == "", "Gas-N-Sip: map closes, store open")
	main.perform("pickup_girls")
	check(main.map_open(), "'Back in the car' reopens the map")
	main.map_pick("park")
	check(main.map_open() and gs.at_place == "park", "park visit, map stays up")
	gs.minutes = maxi(gs.minutes, gs.PICKUP_OPEN)
	main._map_refresh()
	main.map_btns["school"].emit_signal("pressed")
	check(gs.girls_picked and main.map_open(), "mouse click on school picks up the girls")

	main.map_pick("home")
	check(gs.phase == "home_pm" and not main.map_open(), "home after pickup -> evening")
	# missed window: Jess has to get them, meters drop
	gs.new_game(92); gs.do_action("leave_for_work"); gs.today["tickets"] = 2
	gs.do_action("head_home")
	var gc1: int = gs.girls_connected
	var cl1: int = gs.closeness
	gs.minutes = gs.PICKUP_CLOSE - 10
	gs.travel("diner")
	check(gs.girls_picked and gs.girls_connected <= gc1 - 15 and gs.closeness <= cl1 - 8 and int(gs.week_stats.get("missed_pickups", 0)) == 1, "missing the pickup window costs family meters (Jess picks up)")
	check(gs.travel("home") != "" and gs.phase == "home_pm", "then home is open")
	gs.new_game(93); gs.day = 2; gs._start_day(); gs.do_action("leave_for_work"); gs.today["tickets"] = 2; gs.do_action("head_home")
	var o2 := {}
	for o in gs.map_options(): o2[o[0]] = o
	check(o2["home"][3] == "" and o2["school"][3] != "", "Wednesday: Jess has pickup, home open")
	check(gs.travel("dental") != "" and gs.travel("dental") == "You're here.", "dentist visit, can't stack it")
	main.use_map = false
	# --- Pass 2: performance consequences
	gs.new_game(201)
	var p2_pm_msgs: Array = []
	gs.lifeos_message.connect(func(x): p2_pm_msgs.append(str(x)))
	gs.performance = 35; gs.end_day()
	check(gs.notices_seen.has("gary_checkin") and p2_pm_msgs.any(func(x): return "check-in" in x), "perf < 40: Gary check-in")
	gs.performance = 20; gs.end_day()
	check(gs.on_pip() and not gs.autopilot_unlocked("dns") or gs.skill_level("dns") < 3, "perf < 25: PIP")
	gs.skills["dns"] = 300
	check(gs.on_pip() and not gs.autopilot_unlocked("dns"), "PIP suspends autopilot even at max skill")
	gs.performance = 90; gs.end_day()
	check(not gs.on_pip() and gs.autopilot_unlocked("dns"), "back over 40: Plan closed, autopilot restored")
	gs.new_game(202); gs.day = 4; gs.performance = 100
	var p2_m0: int = gs.money
	gs.end_day()
	check(gs.money == p2_m0 + gs.BONUS_AMT, "Friday spot bonus at high performance")
	gs.new_game(203); gs.day = 4; gs.performance = 30
	p2_m0 = gs.money
	gs.end_day()
	check(gs.money == p2_m0 and int(gs.week_stats["bonus"]) == 0, "no bonus at low performance")
	# endings: crispy reachable, uptime rare but possible
	gs.new_game(204); gs.week_stats["pip"] = 1; gs.stress = 45
	check(gs.ending_id() == "crispy", "on the Plan + stressed = Crispy")
	gs.new_game(205); gs.performance = 20; gs.stress = 40
	check(gs.ending_id() == "crispy", "low perf + stress = Crispy")
	gs.new_game(206); gs.performance = 90; gs.closeness = 20; gs.stress = 30
	check(gs.ending_id() == "uptime", "Uptime: perf 85+, clean SLAs, family neglected")
	gs.week_stats["sla_breaches"] = 1
	check(gs.ending_id() != "uptime", "an SLA breach rules out Five Nines")
	# --- Pass 2: girls fed
	gs.new_game(207)
	check(gs.girls_fed >= 50, "girls start the week fed")
	gs.do_action("leave_for_work"); gs.today["tickets"] = 2; gs.do_action("head_home")
	gs.minutes = gs.PICKUP_OPEN
	var p2_f0: int = gs.girls_fed
	gs.travel("school")
	check(gs.girls_fed >= p2_f0 + gs.SNACK_FED - 1, "after-care snack feeds the girls")
	gs.travel("home")
	gs.girls_fed = 10; gs.minutes = 1180
	gs.do_action("play_girls")
	check(gs.girls_fed >= 30 and gs.today.get("jess_dinner", false), "nobody cooked by 7:30: Jess makes grilled cheese")
	# --- Pass 2: dead hour
	gs.new_game(208); gs.do_action("leave_for_work"); gs.today["tickets"] = 2
	gs.minutes = 810; gs.do_action("head_home")
	var p2_o3 := {}
	for o in gs.map_options(): p2_o3[o[0]] = o
	check(p2_o3["coffee"][3] == "" and p2_o3["park"][3] == "" and gs.PICKUP_OPEN <= 840, "1:30 PM: coffee/park open, pickup at 2:00")
	var p2_e3: int = gs.energy
	gs.travel("coffee")
	check(gs.energy > p2_e3 and gs.at_place == "coffee", "coffee stop: +energy")
	# --- Pass 2: real commands
	var p2_rr2 := RandomNumberGenerator.new(); p2_rr2.seed = 9
	var p2_dt := TicketSim.new(p2_rr2, "dns")
	p2_dt.run("dig " + p2_dt.svc)
	check(p2_dt._done.has("nslookup " + p2_dt.svc) or p2_dt.log_lines[-1].contains("NXDOMAIN") or p2_dt.log_lines[-1].contains("find"), "dig works like nslookup")
	for p2_cmd_r in ["uptime", "top", "htop", "ip a", "curl -I https://tc-web01", "cat /etc/hosts", "ls", "history", "man ssh", "journalctl -xe", "sudo whoami", "free -h", "ps aux", "who"]:
		var p2_outr: String = p2_dt.run(p2_cmd_r)
		check(p2_outr != "" and not p2_outr.contains("command not found"), "real command works: " + p2_cmd_r)
	p2_dt.run("clear")
	check(p2_dt.log_lines.is_empty(), "clear clears the screen")
	check(p2_dt.complete("upt")[0] == "uptime " and p2_dt.complete("sudo syst")[0] == "sudo systemctl " and p2_dt.complete("dig tc-d")[0] == "dig tc-dc01 ", "Tab completes real commands, sudo + dig args")
	var p2_ct := TicketSim.new(p2_rr2, "cert")
	check(p2_ct.run("curl -I https://" + p2_ct.host).contains("expired"), "curl sees the expired cert")
	# --- Pass 2: incidents have tight, fair SLAs
	main.use_map = false
	gs.new_game(209); gs.do_action("leave_for_work")
	main.skip_all_cutscenes(); main.summary_root.visible = false; main.pending_summary = ""; main.summary_kind = ""
	main.open_incident("site_outage")
	var p2_rng: Array = main.SLACK_BY_LEVEL[main.incident_level("site_outage")]
	check(main.inc_budget == main.inc_optimal * main.INC_CMD_MIN + main.inc_slack and main.inc_slack >= p2_rng[0] and main.inc_slack <= p2_rng[1], "SLA = fastest path + skill-scaled slack (%d min, Lv %d)" % [main.inc_budget, main.incident_level("site_outage")])
	var p2_gd := 0
	while main.term_open() and not main.term_done and p2_gd < 30:
		p2_gd += 1; main.term_submit(main.term.next_step(), true)
	check(main.term_done and not main.inc_breached, "a clean run makes the SLA")
	main.term_close(true); main.dismiss_summary()
	main.open_incident("site_outage")
	for i in 6: main.term_submit("whoami", true)
	main.term_hint(); main.term_hint()
	p2_gd = 0
	while main.term_open() and not main.term_done and p2_gd < 30:
		p2_gd += 1; main.term_submit(main.term.next_step(), true)
	check(main.inc_breached, "wandering + hints breaches the SLA")
	main.term_close(true)
	check(main.summary_label.text.contains("breached by") and main.summary_label.text.contains("fastest path"), "postmortem explains what cost time: " + main.summary_label.text.left(300))
	main.dismiss_summary()
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
	gs.new_game(71)
	var gm: Array = []
	gs.lifeos_message.connect(func(x): gm.append(x))
	gs.end_day(); gs.end_day()
	check(gs.girl_quiet["june"] == 2 and gm.any(func(x): return "question mark" in str(x)), "per-girl: June notices after 2 days with no one-on-one")
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
	gs.minutes = gs.OFF_WORK; gs.do_action("head_home"); gs.travel("gas"); gs.do_action("buy_patch")
	check(gs.patch_days == 5, "patches bought at the Gas-N-Sip")
	# --- Terminal minigame
	var sims_ok := true
	for kind in TicketSim.TYPES:
		for sd in 4:
			var r := RandomNumberGenerator.new(); r.seed = 100 + sd
			var ts := TicketSim.new(r, kind)
			for cmd_ in ts.solution(): ts.run(cmd_)
			if not ts.solved or ts.grade() != "great":
				sims_ok = false
				printerr("ticket ", kind, " seed ", sd, " solved=", ts.solved, " grade=", ts.grade(), " steps=", ts.solution())
	check(sims_ok, "all 8 ticket types solve via their optimal path with grade Great")
	var r2 := RandomNumberGenerator.new(); r2.seed = 7
	var tw := TicketSim.new(r2, "service")
	for cmd_ in ["ping tc-web01", "df -h", "nslookup foo", "whoami", "tail log", "ss -tlnp"]: tw.run(cmd_)
	tw.hint(); tw.hint(); tw.hint()
	for cmd_ in tw.solution(): tw.run(cmd_)
	check(tw.solved and tw.grade() == "slow", "wandering + 3 hints still solves, grade Slow")
	var td := TicketSim.new(r2, "dns")
	check(td.run("dns records").begins_with("bash: not here"), "host-specific commands need ssh first")
	check(td.hint().contains("nslookup"), "hint points at the next step")
	gs.new_game(81); gs.do_action("feed_girls"); gs.do_action("leave_for_work")
	var g0 := [gs.minutes, gs.energy, gs.performance]
	gs.resolve_ticket("great", "t", "r")
	check(gs.minutes == g0[0] + 120 and gs.energy == g0[1] - 9 and gs.performance == g0[2] + 5, "great office fix: 2 h, -9 energy, +5 perf")
	var g1 := [gs.minutes, gs.performance]
	gs.resolve_ticket("autopilot", "t", "r")
	check(gs.minutes == g1[0] + 150 and gs.performance == g1[1] + 1, "autopilot: 2.5 h, only +1 perf")
	gs.today["tickets"] = 0   # fresh desk for the UI tests below
	main.skip_all_cutscenes(); main.summary_root.visible = false
	main.sync_location()
	main.perform("work_ticket")
	check(main.term_open() and main.term != null, "Work a ticket opens the terminal")
	for cmd_ in main.term.solution(): main.term_submit(cmd_, true)
	check(main.term_done, "terminal solves via clicked commands")
	var tk: int = gs.today["tickets"]
	main.term_close(true)
	check(not main.term_open() and gs.today["tickets"] == tk + 1, "closing a solved ticket counts it")
	# Marty's playtest: live suggestions show the real next command (+1-2 alternatives) after every step.
	for kd in TicketSim.TYPES:
		var lr := RandomNumberGenerator.new(); lr.seed = 77
		var lt := TicketSim.new(lr, kd)
		var ok := true
		var g := 0
		while not lt.solved and g < 20:
			g += 1
			var sg: Array[String] = lt.suggestions(false)
			if not (lt.next_step() in sg) or sg.size() < 3 or sg.size() > 4: ok = false
			lt.clicked_cmds += 1
			lt.run(lt.next_step())
		check(ok and lt.solved, "%s: suggestions always contain the exact next command, solvable by clicking" % kd)
		check(lt.grade() == "good" and not lt.typed_bonus(), "%s: all-clicked perfect run grades Good (not Great), no typed bonus" % kd)
	var tr2 := RandomNumberGenerator.new(); tr2.seed = 78
	var tt := TicketSim.new(tr2, "dns")
	var first: Array[String] = tt.suggestions(true)
	check(first[0] == tt.next_step(), "Rx focus: next step is first (highlighted)")
	for cmd_ in tt.solution(): tt.run(cmd_)
	check(tt.grade() == "great" and tt.typed_bonus(), "typing it yourself: Great + typed bonus")
	var sug_a: Array[String] = TicketSim.new(tr2, "port").suggestions(false)
	var keep := [gs.minutes, gs.energy, gs.performance, gs.stress, gs.skills.duplicate(), gs.today.duplicate(true), gs.week_stats.duplicate(true)]
	gs.skills["dns"] = 0
	gs.resolve_ticket("great", "t", "r", "dns", true)
	check(gs.skills["dns"] == 36, "typed bonus: +6 XP on top of Great (got %d)" % gs.skills["dns"])
	gs.minutes = keep[0]; gs.energy = keep[1]; gs.performance = keep[2]; gs.stress = keep[3]; gs.skills = keep[4]; gs.today = keep[5]; gs.week_stats = keep[6]
	# Marty's playtest: input keeps focus after Enter; Tab completion like bash.
	gs.today["tickets"] = 0
	main.perform("work_ticket")
	main.term_input.release_focus()
	main.term_input.text = "whoami"
	main.term_input.text_submitted.emit("whoami")
	check(main.term_input.has_focus() and main.term_input.text == "", "command input keeps focus after Enter (keep typing)")
	main.term_input.text = "nsl"; main.term_tab()
	check(main.term_input.text == "nslookup ", "Tab completes a command (nsl -> nslookup)")
	main.term_input.text = "ping tc-w"; main.term_tab()
	check(main.term_input.text == "ping tc-web01 ", "Tab completes a hostname")
	main.term_input.text = "systemctl r"; main.term_tab()
	check(main.term_input.text == "systemctl restart ", "Tab completes a subcommand")
	main.term_input.text = "ping tc-"; main.term_tab()
	check(main.term_input.text == "ping tc-", "ambiguous Tab: no change on first press")
	var nlog: int = main.term.log_lines.size()
	main.term_tab()
	check(main.term.log_lines.size() == nlog + 2 and "tc-dc01" in main.term.log_lines[-1] and "tc-web01" in main.term.log_lines[-1], "double-Tab lists the options")
	main.term_input.text = "s"; main.term_tab()
	check(main.term_input.text == "s", "Tab extends to common prefix only")
	main.term_input.text = "unlock "; check(main.term.complete_candidates("unlock ").has("karen"), "Tab completes usernames")
	var ev := InputEventKey.new(); ev.keycode = KEY_TAB; ev.pressed = true
	main.term_input.text = "certb"; main._term_input_key(ev)
	check(main.term_input.text == "certbot ", "Tab key in the input completes (not focus-next)")
	main.term_input.text = ""
	main.term_close(false)
	gs.today["tickets"] = 0
	main.perform("work_ticket")
	main.term_autopilot()
	check(main.term_open() and not main.autopilot_allowed(), "autopilot is locked until Dan is proficient (Lv 3)")
	gs.skills[gs.skill_of(main.term.kind)] = 100
	check(main.autopilot_allowed(), "autopilot unlocks at Lv 3")
	var tk2: int = gs.today["tickets"]
	main.term_autopilot()
	check(not main.term_open() and gs.today["tickets"] == tk2 + 1, "autopilot closes the ticket")
	# --- Skills
	gs.new_game(82)
	check(gs.skill_level("dns") == 1 and gs.max_hints("dns") == 2, "skills start at Lv 1 with 2 hints")
	gs.do_action("feed_girls"); gs.do_action("leave_for_work")
	for i in 3: gs.resolve_ticket("great", "t", "r", "dns")
	check(gs.skill_level("dns") == 2 and gs.skills["dns"] == 90, "great DNS fixes earn XP and level up")
	gs.skills["dns"] = 300
	check(gs.skill_level("dns") == 5 and gs.autopilot_grade("dns") == "good" and gs.max_hints("dns") == 4, "max skill: better autopilot, more hints")
	# --- Incidents
	var mstart: int = gs.minutes
	var pm: String = gs.resolve_incident("ransomware", 60, false, true, false, 8, 1)
	check(pm.begins_with("POSTMORTEM") and pm.contains("within SLA") and gs.minutes == mstart + 60, "incident resolves with a postmortem and costs its time")
	var all_inc := true
	for iid in TicketSim.INCIDENTS:
		var rr := RandomNumberGenerator.new(); rr.seed = 5
		for si in TicketSim.INCIDENTS[iid]["stages"].size():
			var st := TicketSim.make_stage(rr, iid, si)
			for cmd_ in st.solution(): st.run(cmd_)
			all_inc = all_inc and st.solved
	check(all_inc, "all 6 incidents are solvable stage by stage")
	main.skip_all_cutscenes(); main.summary_root.visible = false
	gs.new_game(83); gs.do_action("feed_girls"); gs.do_action("leave_for_work")
	main.skip_all_cutscenes(); main.summary_root.visible = false
	main.sync_location()
	main.open_incident("site_outage")
	var guard := 0
	while main.term_open() and not main.term_done and guard < 30:
		guard += 1
		main.term_submit(main.term.next_step(), true)
	check(main.term_done and main.inc_idx == 1, "incident advances through both stages in the terminal")
	main.term_close(true)
	check(main.summary_root.visible and main.summary_kind == "postmortem" and main.summary_label.text.contains("Blameless"), "postmortem summary shown")
	main.dismiss_summary()
	check(not main.summary_root.visible and main.cs_id == "", "dismissing the postmortem goes back to work (no wake-up)")
	main.skip_all_cutscenes(); main.summary_root.visible = false
	gs.apply_choice("incident_take:cert_outage")
	main._check_pending_incident()
	check(main.term_open() and main.inc_after_hours, "after-hours page opens an incident at home")
	main.term_close(false)
	# --- Girls fed
	gs.new_game(84)
	var fedmsgs: Array = []
	gs.lifeos_message.connect(func(x): fedmsgs.append(x))
	gs.do_action("cereal"); gs.do_action("leave_for_work")
	while not gs.can_leave_work(): gs.resolve_ticket("good", "t", "r", "port")
	gs.do_action("head_home"); gs.travel("gas"); gs.do_action("pickup_girls")
	check(gs.girls_fed >= 25 or fedmsgs.any(func(x): return "Girls: Fed is low" in str(x)), "girls aren't starving silently: lunch + low-fed warning")
	gs.minutes = 1080; gs.do_action("family_dinner")
	check(gs.girls_fed >= 50, "family dinner feeds the girls")
	# --- Scenes, cutscenes, assets, UI
	main.skip_all_cutscenes()
	main.dismiss_summary() if main.summary_root.visible else null
	gs.new_game(9)
	main.skip_all_cutscenes()
	main.summary_root.visible = false
	main.sync_location()
	check(main.loc_name == "house", "home phase loads the house scene")
	for n in ["house", "office", "gas_station", "school", "road", "garage"]:
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
	check(main.loc_name == "road" and gs.at_place != "gas", "after work Dan is on the road, not forced to the Gas-N-Sip")
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
	paper_tests(gs, main)
	no_forced_gas_tests(gs, main)
	farm_tests(gs, main)
	print("TESTS DONE: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
	return true

## Paper presentation: sets, cards, camera, prompts, typewriter/flaps, banner, SLA scaling.
func paper_tests(gs: Node, main: Node) -> void:
	var d: Diorama = main.diorama
	check(d != null and main.paper and not main.world.visible, "paper diorama is the presentation; 2D plan hidden")
	for ln in ["house", "office", "gas_station", "school", "road"]:
		main.load_location(ln)
		check(d.set_name == ln and d.set_root.get_child_count() > 20, "paper set built for %s (%d pieces)" % [ln, d.set_root.get_child_count()])
		var ok := true
		for id in main.loc.stations:
			var c: Vector3 = d.to3((main.loc.stations[id]["rect"] as Rect2).get_center())
			if absf(c.x) > d.XW or c.z < d.zb - 0.1: ok = false
		check(ok, "%s: every station sits inside the set walls" % ln)
		# camera never sees past the set, anywhere Dan can stand
		var leaks := 0
		var b: Rect2 = main.loc.bounds
		for fx in [0.0, 0.5, 1.0]:
			for fy in [0.0, 0.5, 1.0]:
				main.dan.position = b.position + b.size * Vector2(fx, fy)
				for i in 120: d.tick(1.0 / 30.0, main.loc, "", "", 0.0, "")
				leaks += d.edge_leaks(1.63) + d.edge_leaks(1.33) + d.edge_leaks(2.0)
		check(leaks == 0, "%s: camera stays inside the diorama at all 9 test spots / 3 aspects (leaks %d)" % [ln, leaks])
		check(d.signs.size() >= 1, "%s: has lettered 3D signs" % ln)
	gs.phase = "drive"
	for pl in ["park", "pharmacy", "dental", "diner", "coffee"]:
		gs.at_place = pl
		main.load_location("road"); main._paper_sync()
		check(d.place == pl and d.set_root.get_child_count() > 15, "town destination %s has its own paper set" % pl)
		for i in 60: d.tick(1.0 / 30.0, main.loc, "", "", 0.0, "")
		check(d.edge_leaks(1.63) == 0, "%s: no set edges visible" % pl)
	gs.new_game(42)
	main.skip_all_cutscenes()
	main.sync_location()
	check(main.loc_name == "house", "back home for paper tests")
	# fridge drawings are 3D sprites
	gs.fridge_drawings = 5; main._update_fridge()
	check(d.fridge_root != null and d.fridge_root.get_children().filter(func(n): return n is Sprite3D).size() == 5, "5 fridge drawings pinned on the 3D fridge")
	# cards + lanes
	main.loc.actors["lily"].position = main.loc.actors["dan"].position + Vector2(2, 0)
	for i in 90: d.tick(1.0 / 30.0, main.loc, "", "", 0.0, "")
	check(absf(d.card_x("lily") - d.card_x("dan")) > (d.card("dan").size.x + d.card("lily").size.x) * 0.35, "two cards on one spot get auto-spaced apart")
	# flip has thickness + tilt
	var c: PaperCard = d.card("dan")
	c.face(-c.facing)
	c.tick(PaperCard.FLIP_TIME * 0.5, false, 0.0)
	check(c.flipping() and absf(c.pivot.rotation.z) > 0.05 and absf(c.layers[0].position.z - c.layers[4].position.z) > PaperCard.THICK * 1.5, "mid-flip the card tilts and shows its thickness")
	c.tick(1.0, false, 0.0)
	check(not c.flipping() and absf(c.layers[0].position.z - c.layers[4].position.z) < PaperCard.THICK * 1.01, "flip settles back to a thin card")
	var w0: float = c.art.walk
	c.tick(0.2, true, 0.0)
	check(c.art.walk > w0 and c.art.moving, "walking advances the walk cycle")
	# proximity prompt
	main.near_station = "kitchen"
	check(main._tag_text().begins_with("Kitchen"), "proximity tag names the station + keys")
	d.tick(0.03, main.loc, "kitchen", "", 0.0, main._tag_text())
	check(d.tag.visible and d.tag.text.begins_with("Kitchen"), "paper tag floats over the station when Dan is near")
	main.near_station = ""
	# typewriter + mouth flaps
	main.queue_cutscene("moment", {"id": "bedtime"})
	var spoke := false; var narr_ok := true; var flap_idle := 0; var flap_typing := 0
	for f in 3000:
		if main.cs_id == "": break
		if main.cs_waiting == "choice": main.pick_choice(0); continue
		if main.cs_waiting == "move" and main.cs_mover and main.cs_mover._tween and main.cs_mover._tween.is_valid(): main.cs_mover._tween.custom_step(0.05)
		main._process(1.0 / 30.0)
		if main.cs_waiting == "say":
			if main.typing():
				if main.talk_flap > 0: flap_typing += 1
			else:
				if main.talk_flap > 0: flap_idle += 1
				spoke = true
				main.advance()
	main.skip_all_cutscenes()
	check(spoke and flap_typing > 0 and flap_idle == 0, "mouths flap while letters type, and stop when the line is done (%d/%d)" % [flap_typing, flap_idle])
	main._run_step(["say", "", "A narrator line with no speaker."], false)
	for i in 120: main._process(1.0 / 30.0)
	check(not main.typing() and main.talk_flap == 0.0, "narration lines type out too (no stuck blank box)")
	main._run_step(["say", "jess", "Long line. With beats, and a pause before the punchline."], false)
	main._process(1.0 / 30.0)
	var e := InputEventKey.new(); e.keycode = KEY_ENTER; e.pressed = true
	main.cs_id = "test"
	main._unhandled_input(e)
	check(main.cs_waiting == "say" and not main.typing(), "first Enter finishes the line, it doesn't skip it")
	main._unhandled_input(e)
	check(main.cs_waiting == "", "second Enter advances")
	main.cs_id = ""
	main.dialog_panel.visible = false
	# SLA scales with skill: generous early, tight for experts
	var r := RandomNumberGenerator.new(); r.seed = 3
	var lo := 0; var hi := 0
	for i in 50: lo += main.incident_slack(1, r); hi += main.incident_slack(5, r)
	check(lo > hi * 1.4, "incident slack: Lv1 avg %d min vs Lv5 avg %d min" % [lo / 50, hi / 50])
	for k in gs.skills: gs.skills[k] = 0
	main.open_incident("site_outage")
	var b1: int = main.inc_budget
	main.term_close(false)
	for k in gs.skills: gs.skills[k] = 400
	main.open_incident("site_outage")
	var b5: int = main.inc_budget
	main.term_close(false)
	check(b1 > b5, "a new Dan gets a longer SLA than an expert Dan (%d vs %d min)" % [b1, b5])
	main.load_location("house")
	var probs: Array[String] = main.audit_ui()
	check(probs.is_empty(), "UI audit clean after paper tests %s" % [probs])

## Marty: leaving work never auto-routes to the Gas-N-Sip; it's an optional map pin, every weekday.
func no_forced_gas_tests(gs: Node, main: Node) -> void:
	var keep: bool = main.use_map
	main.use_map = true
	for d in 5:
		gs.new_game(500 + d)
		gs.day = d
		main.skip_all_cutscenes(); main.summary_root.visible = false; main.pending_summary = ""
		main.close_map()
		gs.do_action("leave_for_work"); main.skip_all_cutscenes()
		gs.minutes = gs.OFF_WORK
		main.perform("head_home")
		check(main.cs_id == "drive_stop", "day %d: the radio cutscene plays on leaving work" % (d + 1))
		var gas_seen := false
		var guard := 0
		while main.cs_id != "" and guard < 50:
			guard += 1
			for st in main.cs_steps:
				if st[0] == "loc" and st[1] == "gas_station": gas_seen = true
			main.skip_cutscene()
		main.auto_map()
		var opts := {}
		for o in gs.map_options(): opts[o[0]] = o[3]
		check(not gas_seen and gs.at_place != "gas" and main.loc_name == "road", "day %d: no forced Gas-N-Sip stop (at %s, loc %s)" % [d + 1, gs.at_place, main.loc_name])
		check(main.map_open() and opts.get("gas", "x") == "" and (opts.get("school", "x") == "" or gs.minutes < gs.PICKUP_OPEN or gs.jess_has_girls()), "day %d: map open; Gas-N-Sip and school are choices" % (d + 1))
		main.map_pick("coffee" if opts.get("coffee", "x") == "" else "park")
		check(gs.at_place != "gas" and main.loc_name == "road", "day %d: going elsewhere never touches the Gas-N-Sip" % (d + 1))
		main.close_map()
		gs.minutes = maxi(gs.minutes, gs.PICKUP_OPEN)
		main.map_pick("gas")
		check(gs.at_place == "gas" and main.loc_name == "gas_station", "day %d: the Gas-N-Sip only when picked" % (d + 1))
	main.close_map()
	main.use_map = keep


## Home PC desktop + parody shops + garage server farm (data-center path, lite).
func farm_tests(gs: Node, main: Node) -> void:
	gs.new_game(77)
	main.skip_all_cutscenes(); main.summary_root.visible = false; main.pending_summary = ""
	main.close_map()
	gs.day = 0; gs.phase = "home_pm"; gs.minutes = 1080
	main.sync_location()
	check(gs.CATALOG.size() >= 6 and gs.CATALOG.size() <= 10 and gs.SHOPS.size() == 3, "catalog: 6-10 items across 3 parody shops")
	for bad in ["newegg", "ebay", "amazon", "dell", "cisco", "apc"]:
		check(not JSON.stringify(gs.CATALOG).to_lower().contains(bad) and not JSON.stringify(gs.SHOPS).to_lower().contains(bad), "no real trademark: " + bad)
	main.near_station = "desk"
	check(main._current_actions().has("pc") and main._current_actions().has("gaming"), "desk offers the PC plus the old actions")
	main.perform("pc")
	check(main.desktop_open() and main.is_busy(), "PC desk opens the desktop")
	var fo: Control = main.get_viewport().gui_get_focus_owner()
	check(fo != null and main.desktop.is_ancestor_of(fo), "desktop takes keyboard focus (icons)")
	main.desk_app("pceggo")
	check(main.desk_window.visible and main.desk_title.text.begins_with("PCEggo"), "PCEggo window opens")
	fo = main.get_viewport().gui_get_focus_owner()
	check(fo != null and main.desk_window.is_ancestor_of(fo), "window takes keyboard focus")
	main.relayout(); main.relayout()
	check(main.audit_ui().is_empty(), "desktop audit clean %s" % [main.audit_ui()])
	for id in ["rackbay", "kevin", "cart", "farm"]:
		main.desk_app(id)
		main.relayout(); main.relayout()
		check(main.desk_window.visible and main.audit_ui().is_empty(), "%s window opens cleanly %s" % [id, main.audit_ui()])
	main.close_window()
	check(not main.desk_window.visible and main.desktop_open(), "window closes, desktop stays")
	# money check
	gs.money = 50
	main.cart.clear(); main.cart_add("server"); main.cart_add("rack")
	var m0: int = gs.money
	check(main.cart_checkout().begins_with("Card declined") and gs.money == m0 and gs.orders.is_empty(), "checkout refuses when money is short")
	gs.money = 400
	main.cart_add("switch"); main.cart_add("electrician")
	check(main.cart_checkout().begins_with("Order placed") and gs.money == 400 - 55 - 45 - 25 - 95 and gs.orders.size() == 4 and main.cart.is_empty(), "checkout charges and orders")
	check(gs.boxes.is_empty(), "nothing arrives the same day")
	main.desk_app("games")
	check(not main.desktop_open(), "Games icon runs the old gaming action")
	main.skip_all_cutscenes()
	# save mid-order, then next morning delivery
	gs.end_day(); main.skip_all_cutscenes(); main.summary_root.visible = false; main.pending_summary = ""
	check(gs.boxes.size() == 3 and gs.farm_has("electrician") == 1 and gs.orders.is_empty(), "next morning: 3 boxes in the garage, electrician installed")
	var tag := "user://farm_test.save"
	check(gs.save_game(tag), "save with boxes")
	gs.boxes = []
	check(gs.load_game(tag) and gs.boxes.size() == 3, "load restores boxes")
	gs.phase = "home_pm"; gs.minutes = 1020
	main.in_garage = false; main.sync_location()
	main.near_station = "garage"
	main.perform("go_garage")
	check(main.loc_name == "garage", "garage door goes to the garage")
	main.near_station = "boxes"
	main.perform("build_farm")
	check(main.assembly_open(), "boxes open the assembly step")
	var wrong: int = main.asm_order.find(2)
	main.assembly_step(wrong)
	check(main.asm_done == 0 and main.asm_mistakes == 1, "out-of-order step is refused")
	main.lifeos_panel.visible = false
	main.relayout(); main.relayout()
	check(main.audit_ui().is_empty(), "assembly audit clean %s" % [main.audit_ui()])
	main.assembly_auto()
	check(not main.assembly_open() and gs.farm_has("server") == 1 and gs.boxes.size() == 2, "assembly installs the server")
	check(main.diorama.farm_root != null and main.diorama.farm_root.get_children().any(func(c): return c.name.begins_with("Server")), "server visible in the garage diorama")
	var n0: int = main.diorama.farm_root.get_children().filter(func(c): return not (c is Label3D or c.name.begins_with("Box"))).size()
	while not gs.boxes.is_empty():
		main.perform("build_farm"); main.assembly_auto()
	check(gs.farm_has("rack") == 1 and gs.farm_has("switch") == 1 and gs.farm_online() == 1, "rack+switch built")
	check(main.diorama.farm_root.get_children().filter(func(c): return not (c is Label3D or c.name.begins_with("Box"))).size() > n0, "farm visibly grows")
	gs.farm["server"] = 3
	check(gs.farm_online() == 3, "electrician circuit lets 3 servers run")
	gs.farm["electrician"] = 0
	check(gs.farm_online() == 2, "no circuit: 2 servers max")
	gs.farm["electrician"] = 1
	var money0: int = gs.money
	var close0: int = gs.closeness
	var s: Dictionary = gs.end_day()
	main.skip_all_cutscenes(); main.summary_root.visible = false; main.pending_summary = ""
	check(str(s.get("farm", "")).begins_with("Garage farm") and gs.farm_days == 1, "nightly farm economics run")
	check(gs.farm_income_total != 0 and gs.farm_bill_day() > 0, "income and power bill tracked (net %d)" % gs.farm_income_total)
	check(gs.closeness < close0, "noise costs Jess's patience")
	# outages: without a UPS some nights trip
	gs.new_game(5); gs.farm = {"server": 2, "rack": 1, "switch": 1}
	for k in 40: gs._farm_night()
	var no_ups: int = gs.farm_outages
	gs.new_game(5); gs.farm = {"server": 2, "rack": 1, "switch": 1, "ups": 1, "fans": 1}
	for k in 40: gs._farm_night()
	check(no_ups > 0 and gs.farm_outages < no_ups, "home incidents happen; UPS + fans cut them (%d -> %d)" % [no_ups, gs.farm_outages])
	gs.new_game(6); gs.farm = {"server": 2, "rack": 1, "switch": 1}; gs.farm_income_total = 40; gs.closeness = 60; gs.stress = 20
	check(gs.ending_id() != "homelab", "2 servers without a UPS is not a data center (ending tuned)")
	gs.farm = {"server": 2, "rack": 1, "switch": 1, "ups": 1}; gs.farm_income_total = 60; gs.girls_connected = 60
	check(gs.ending_id() == "homelab" and gs.ending_text().contains("Mercer Data Center"), "homelab ending reachable with a real build")
	gs.closeness = 80; gs.girls_connected = 80; gs.stress = 20
	check(gs.ending_id() == "cozy", "a thriving family week outranks a modest farm")
	gs.farm_income_total = 150
	check(gs.ending_id() == "homelab", "a real little business outranks cozy")
	gs.closeness = 60; gs.girls_connected = 60; gs.farm_income_total = 60
	gs.farm_outages = 3
	check(gs.ending_id() != "homelab", "an outage-ridden farm doesn't earn the ending")
	gs.farm_outages = 0; gs.closeness = 40
	check(gs.ending_id() != "homelab", "neglecting Jess blocks the ending")
	check(gs.can_do("pc") != "" and gs.do_action("pc") != "", "UI verbs can't run through do_action")
	# every action result is a real line, not just the menu label (comedy writer pass)
	gs.new_game(3); gs.phase = "home_pm"; gs.minutes = 1000; gs.energy = 100
	var r1: String = gs.do_action("play_girls")
	check(r1 != gs.ACTIONS["play_girls"]["name"] and r1.length() > 30, "play_girls has a real result line")
	gs.new_game(3)
	var r2: String = gs.do_action("feed_girls")
	check(r2 != gs.ACTIONS["feed_girls"]["name"], "breakfast has a real result line")
	main.in_garage = false
	gs.new_game(1); main.skip_all_cutscenes(); main.summary_root.visible = false; main.pending_summary = ""; main.sync_location()
