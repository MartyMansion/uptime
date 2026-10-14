extends SceneTree
## Automated playtester: plays the full week N times with varied strategies
## through the real Main scene (UI + cutscenes), logging problems.
##   godot --headless --path . -s res://tests/playtest_bot.gd -- [runs] [outdir]

const STRATS := ["random", "workaholic", "family_first", "heavy", "all_skip", "night_owl", "rx_spam", "balanced", "broke", "stardew"]
var problems: Array[String] = []
var lines := {}            # dialogue/text line -> count
var stats := {"runs": 0, "days": 0, "actions": 0, "cutscenes": {}, "actions_used": {}, "endings": 0, "audits": 0}
var gs: Node
var main: Node
var cur := ""

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func bad(msg: String) -> void:
	var m := "[%s] %s" % [cur, msg]
	if problems.size() < 500:
		problems.append(m)
	printerr("PROBLEM ", m)

func note(t: String) -> void:
	if t != "":
		lines[t] = int(lines.get(t, 0)) + 1

func _run() -> void:
	gs = root.get_node("GameState")
	gs.lifeos_message.connect(func(t): note(str(t)))
	gs.action_performed.connect(func(_id, r): note(str(r)))
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 100
	var outdir: String = args[1] if args.size() > 1 else "/workspace/uptime-build/playtest"
	await process_frame
	for i in runs:
		var strat: String = STRATS[i % STRATS.size()]
		cur = "run %d/%s" % [i + 1, strat]
		await play_week(strat, 1000 + i)
		stats["runs"] += 1
	# every cutscene variant built against a range of states (catches unreachable text)
	var f := FileAccess.open(outdir + "/playtest_log.txt", FileAccess.WRITE)
	f.store_line("RUNS %d DAYS %d ACTIONS %d AUDITS %d PROBLEMS %d" % [stats["runs"], stats["days"], stats["actions"], stats["audits"], problems.size()])
	f.store_line("CUTSCENES " + JSON.stringify(stats["cutscenes"]))
	f.store_line("ACTIONS " + JSON.stringify(stats["actions_used"]))
	for p in problems:
		f.store_line("PROBLEM " + p)
	f.close()
	var lf := FileAccess.open(outdir + "/dialogue_seen.txt", FileAccess.WRITE)
	var keys: Array = lines.keys()
	keys.sort()
	for k in keys:
		lf.store_line("%5d | %s" % [lines[k], str(k).replace("\n", " / ")])
	lf.close()
	var missing: Array = []
	for id in gs.ACTIONS:
		if not stats["actions_used"].has(id): missing.append(id)
	for id in Cutscenes.IDS:
		if not stats["cutscenes"].has(id): missing.append("cutscene:" + id)
	if not missing.is_empty():
		problems.append("never triggered: " + ", ".join(missing))
	print("PLAYTEST DONE runs=%d days=%d actions=%d unique_lines=%d problems=%d" % [stats["runs"], stats["days"], stats["actions"], lines.size(), problems.size()])
	for p in problems.slice(0, 40):
		print("  ", p)
	quit(1 if not problems.is_empty() else 0)

## Plays out queued cutscenes, recording every line; sometimes step-by-step.
func drain(step := false) -> void:
	var guard := 0
	while main.cs_id != "" and guard < 60:
		guard += 1
		stats["cutscenes"][main.cs_id] = int(stats["cutscenes"].get(main.cs_id, 0)) + 1
		for st in main.cs_steps:
			if st[0] == "say": note("%s: %s" % [st[1] if st[1] != "" else "(narration)", st[2]])
			elif st[0] == "lifeos": note("LifeOS: " + str(st[1]))
		if step and main.dialog_panel.visible:
			note("%s: %s" % [main.dialog_name.text, main.dialog_text.text])
			await audit("dialogue " + main.cs_id)
		main.skip_cutscene()
	if guard >= 60: bad("cutscene queue never drained")
	if main.summary_root.visible:
		note(main.summary_title.text + " :: " + main.summary_label.text)
		await audit("summary")

func audit(where: String) -> void:
	await process_frame
	stats["audits"] += 1
	for p in main.audit_ui():
		bad("UI %s: %s" % [where, p])

func check_state() -> void:
	for v in ["energy", "stress", "performance", "closeness", "girls_fed", "girls_connected"]:
		var x: int = gs.get(v)
		if x < 0 or x > 100: bad("%s out of range: %d" % [v, x])
	if gs.money < 0: bad("money negative %d" % gs.money)
	if gs.beers < 0 or gs.pouches < 0 or gs.rx_pills < 0: bad("negative inventory")
	if gs.minutes > gs.DAY_END: bad("clock past 1 AM: %d" % gs.minutes)
	if not gs.week_over and main.cs_id == "" and not main.summary_root.visible and main.loc_name != main.PHASE_LOC[gs.phase]:
		bad("location %s doesn't match phase %s" % [main.loc_name, gs.phase])

## Strategy: choose the next action from what's allowed right now.
func choose(strat: String, allowed: Array, rng: RandomNumberGenerator) -> String:
	var ph: String = gs.phase
	var pref: Array = []
	match strat:
		"random", "broke":
			return allowed[rng.randi() % allowed.size()]
		"workaholic":
			pref = ["rx_dose", "leave_for_work", "work_ticket", "head_home", "pickup_girls", "work_ticket", "sleep"]
			if gs.rx_active(): pref.erase("rx_dose")
		"family_first":
			pref = ["feed_girls", "text_jess", "leave_for_work", "work_ticket", "head_home", "pickup_girls", "bedtime_story", "play_girls", "sleep"]
		"heavy":
			pref = ["pouch", "rx_dose", "cereal", "leave_for_work", "work_ticket", "head_home", "buy_beer", "buy_pouches", "pickup_girls", "drink", "gaming", "sleep"]
		"all_skip":
			pref = ["leave_for_work", "head_home", "pickup_girls", "sleep"]
			if ph == "work" and "head_home" not in allowed: return ""   # idle: let time be advanced by waiting
		"night_owl":
			pref = ["cereal", "leave_for_work", "work_ticket", "head_home", "pickup_girls", "gaming", "work_ticket", "drink"]
		"rx_spam":
			pref = ["rx_dose", "leave_for_work", "work_ticket", "head_home", "pickup_girls", "work_ticket", "sleep"]
		"balanced", "stardew":
			pref = ["feed_girls", "leave_for_work", "text_jess", "work_ticket", "head_home", "pickup_girls", "bedtime_story", "play_girls", "gaming", "sleep"]
	if strat == "heavy" and gs.today.get("drink", 0) >= 4: pref.erase("drink")
	if strat == "heavy" and gs.today.get("pouch", 0) >= 4: pref.erase("pouch")
	if strat == "family_first" and gs.today.get("play_girls", 0) >= 3: pref.erase("play_girls")
	if strat == "workaholic" and gs.today.get("rx_dose", 0) >= 2: pref.erase("rx_dose")
	if strat == "stardew" and gs.today.get("gaming", 0) >= 1: pref.erase("gaming")
	for p in pref:
		if p in allowed: return p
	return allowed[rng.randi() % allowed.size()] if not allowed.is_empty() else ""

func play_week(strat: String, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	main.summary_root.visible = false
	main.summary_is_week = false
	main.pending_summary = ""
	gs.new_game(seed_v)
	main.cs_queue.clear()
	main.queue_cutscene("wake")
	if strat == "broke": gs.money = 15
	await drain(true)
	var last_day := -1
	var day_actions := 0
	var total := 0
	while not gs.week_over and total < 3000:
		total += 1
		if gs.day != last_day:
			last_day = gs.day
			day_actions = 0
			stats["days"] += 1
		day_actions += 1
		if day_actions > 120:
			bad("stuck: %s day %d phase %s at %s" % [strat, gs.day, gs.phase, gs.clock_text()])
			gs.end_day()
			await drain()
			if main.summary_root.visible: main.dismiss_summary()
			await drain()
			continue
		var allowed: Array = []
		for id in gs.phase_actions():
			if gs.can_do(id) == "": allowed.append(id)
		# zero-time actions can loop forever; cap them per strategy step
		var timed: Array = allowed.filter(func(a): return int(gs.ACTIONS[a]["blocks"]) > 0 or a == "sleep")
		if timed.is_empty() and not allowed.is_empty() and gs.phase != "drive":
			bad("softlock: only zero-time actions in %s at %s (energy %d): %s" % [gs.phase, gs.clock_text(), gs.energy, allowed])
		if allowed.is_empty():
			bad("softlock: nothing allowed in %s at %s (energy %d)" % [gs.phase, gs.clock_text(), gs.energy])
			gs.end_day()
		else:
			if day_actions > 40: allowed = timed if not timed.is_empty() else allowed
			if strat == "night_owl" and gs.phase == "home_pm" and gs.minutes < gs.DAY_END - 30:
				allowed.erase("sleep")
				if allowed.is_empty(): allowed = ["sleep"]
			var a := choose(strat, allowed, rng)
			if a == "" or not (a in allowed):
				a = timed[rng.randi() % timed.size()] if not timed.is_empty() else allowed[0]
			stats["actions"] += 1
			stats["actions_used"][a] = int(stats["actions_used"].get(a, 0)) + 1
			var before_min: int = gs.minutes
			main.perform(a)
			if gs.minutes < before_min and gs.phase != "home_am": bad("clock went backwards on " + a)
		check_state()
		if rng.randf() < 0.05: await audit("play")
		await drain(rng.randf() < 0.3)
		if main.summary_root.visible:
			main.dismiss_summary() if not gs.week_over else null
			if gs.week_over:
				stats["endings"] += 1
				break
			await drain()
	if not gs.week_over: bad("week never finished")
	main.summary_root.visible = false
