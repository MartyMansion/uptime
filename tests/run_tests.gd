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
	check(main.inc_budget < 90 and main.inc_budget == main.inc_optimal * main.INC_CMD_MIN + main.inc_slack and main.inc_slack >= 4 and main.inc_slack <= 16, "SLA = fastest path + slack (%d min)" % main.inc_budget)
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
