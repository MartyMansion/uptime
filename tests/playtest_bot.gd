extends SceneTree
## Automated playtester: plays the full week N times with varied strategies
## through the real Main scene (UI + cutscenes), logging problems.
##   godot --headless --path . -s res://tests/playtest_bot.gd -- [runs] [outdir]

const STRATS := ["random", "workaholic", "family_first", "heavy", "all_skip", "night_owl", "rx_spam", "balanced", "broke", "stardew", "cozy", "quitter"]
var problems: Array[String] = []
var lines := {}            # dialogue/text line -> count
var stats := {"runs": 0, "days": 0, "actions": 0, "cutscenes": {}, "actions_used": {}, "endings": 0, "endings_by": {}, "audits": 0}
var bal := {}
var skill_sum := {}   # strat -> sums of end-of-week meters
var gs: Node
var main: Node
var cur := ""

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.autoload_save = false
	main.random_choices = true
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
	f.store_line("TERMINAL tickets %d autopilot %d (locked attempts %d) walked %d great %d good %d slow %d kinds %s" % [int(stats.get("terminal", 0)), int(stats.get("t_autopilot", 0)), int(stats.get("t_autopilot_locked", 0)), int(stats.get("t_walk", 0)), int(stats.get("grade_great", 0)), int(stats.get("grade_good", 0)), int(stats.get("grade_slow", 0)), JSON.stringify(stats.get("kinds", {}))])
	f.store_line("INCIDENTS %d (after-hours %d, SLA breached %d) %s" % [int(stats.get("incidents", 0)), int(stats.get("inc_after_hours", 0)), int(stats.get("inc_breached", 0)), JSON.stringify(stats.get("inc_ids", {}))])
	f.store_line("SKILLS avg end-of-week level " + JSON.stringify(skill_sum))
	f.store_line("MAP opens %d waits %d dest %s missed_pickups %d" % [int(stats.get("map_opens", 0)), int(stats.get("map_waits", 0)), JSON.stringify(stats.get("map_dest", {})), int(stats.get("missed_pickups", 0))])
	f.store_line("SAVELOAD round trips %d" % int(stats.get("saveloads", 0)))
	f.store_line("ENDINGS " + JSON.stringify(stats["endings_by"]))
	f.store_line("BALANCE (avg end of week)  strat | stress perf jess girls | drawings bedtimes | drinks pouches rx_extra | money")
	for k in bal:
		var b: Dictionary = bal[k]
		var n: float = b["n"]
		f.store_line("BALANCE %-12s | %3d %3d %3d %3d | %4.1f %3.1f | %4.1f %4.1f %3.1f | %d" % [k, b["stress"] / n, b["perf"] / n, b["jess"] / n, b["girls"] / n, b["drawings"] / n, b["bedtimes"] / n, b["drinks"] / n, b["pouches"] / n, b["rx_extra"] / n, b["money"] / n])
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
		# UI verbs + the garage build are exercised by the homelab personas (persona_bot.gd farm_routine)
		if gs.ACTIONS[id].get("ui", false) or id == "build_farm": continue
		if not stats["actions_used"].has(id): missing.append(id)
	for id in Cutscenes.IDS:
		# "triage" is the legacy quick-choice; the terminal minigame replaced it in play
		if not stats["cutscenes"].has(id) and id != "triage": missing.append("cutscene:" + id)
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
		if step and main.cs_waiting == "choice":
			await audit("choice " + main.cs_id)
			main.pick_choice(randi() % main.cs_choices.size())
			continue
		if step and main.dialog_panel.visible:
			note("%s: %s" % [main.dialog_name.text, main.dialog_text.text])
			await audit("dialogue " + main.cs_id)
		main.skip_cutscene()
		note(main.log_label.text)
	for k in gs.notices_seen:
		if str(k).begins_with("choice_") and not stats["cutscenes"].has(k):
			stats["cutscenes"][k] = 1
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
	if not gs.week_over and main.cs_id == "" and not main.summary_root.visible and main.loc_name != main.phase_loc():
		bad("location %s doesn't match phase %s" % [main.loc_name, gs.phase])

## Strategy: choose the next action from what's allowed right now.
## How the bot carries out an action (personas override, e.g. keyboard-only play).
func act(a: String) -> void:
	main.perform(a)

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
		"cozy":
			pref = ["pancakes", "feed_girls", "leave_for_work", "text_jess", "work_ticket", "head_home", "pickup_girls", "concert", "walk_park", "family_dinner", "homework", "tea_jess", "bedtime_story", "chores", "walk_block", "sleep"]
			if gs.today.get("tickets", 0) >= 3: pref.erase("work_ticket")
		"quitter":
			if gs.day < 2:
				pref = ["pouch", "leave_for_work", "rx_dose", "work_ticket", "head_home", "buy_beer", "buy_pouches", "pickup_girls", "drink", "sleep"]
			else:
				pref = ["breathe", "text_jess", "feed_girls", "pancakes", "leave_for_work", "call_doctor", "coffee_break", "work_ticket", "head_home", "buy_patch", "pickup_girls", "walk_block", "family_dinner", "tea_jess", "bedtime_story", "sleep"]
				if gs.patch_days > 0: pref.erase("buy_patch")
				if gs.today.get("tickets", 0) >= 4: pref.erase("work_ticket")
				if gs.today.get("coffee_break", 0) >= 1: pref.erase("coffee_break")
		"balanced", "stardew":
			pref = ["feed_girls", "leave_for_work", "text_jess", "work_ticket", "head_home", "pickup_girls", "bedtime_story", "play_girls", "gaming", "sleep"]
			if strat == "stardew" and gs.phase in ["home_pm", "weekend"]:
				pref = ["pancakes", "walk_park", "family_dinner", "homework", "tea_jess", "text_jess", "play_girls", "bedtime_story", "chores", "gaming", "sleep"]
	if strat == "quitter" and gs.day < 2 and gs.today.get("drink", 0) >= 3: pref.erase("drink")
	if strat == "quitter" and gs.day < 2 and gs.today.get("pouch", 0) >= 3: pref.erase("pouch")
	if strat == "heavy" and gs.today.get("drink", 0) >= 4: pref.erase("drink")
	if strat == "heavy" and gs.today.get("pouch", 0) >= 4: pref.erase("pouch")
	if strat == "family_first" and gs.today.get("play_girls", 0) >= 3: pref.erase("play_girls")
	if strat == "workaholic" and gs.today.get("rx_dose", 0) >= 2: pref.erase("rx_dose")
	if strat == "stardew" and gs.today.get("gaming", 0) >= 1: pref.erase("gaming")
	if strat in ["family_first", "stardew", "balanced", "cozy", "quitter"] and gs.minutes < 1170 and gs.today.get("bedtime_story", 0) == 0:
		pref.erase("sleep")
	if strat == "quitter" and gs.today.get("rx_dose", 0) >= 1: pref.erase("rx_dose")
	for p in pref:
		if p in allowed: return p
	if strat in ["cozy", "quitter", "family_first", "stardew"]:
		for p in ["walk_block", "play_girls", "coffee_break", "work_ticket", "gaming"]:
			if p in allowed: return p
	return allowed[rng.randi() % allowed.size()] if not allowed.is_empty() else ""

## Terminal minigame: solve like a human of this strategy would.
func play_terminal(strat: String, rng: RandomNumberGenerator) -> void:
	stats["terminal"] = int(stats.get("terminal", 0)) + 1
	var is_inc: bool = main.inc_id != ""
	if is_inc:
		stats["incidents"] = int(stats.get("incidents", 0)) + 1
		stats["inc_ids"] = stats.get("inc_ids", {})
		stats["inc_ids"][main.inc_id] = int(stats["inc_ids"].get(main.inc_id, 0)) + 1
		if main.inc_after_hours: stats["inc_after_hours"] = int(stats.get("inc_after_hours", 0)) + 1
	var t: TicketSim = main.term
	stats["kinds"] = stats.get("kinds", {})
	stats["kinds"][t.kind] = int(stats["kinds"].get(t.kind, 0)) + 1
	var roll := rng.randf()
	if (strat == "all_skip" or roll < 0.25) and main.autopilot_allowed():
		main.term_autopilot(); stats["t_autopilot"] = int(stats.get("t_autopilot", 0)) + 1
		await _after_terminal(); return
	if not main.autopilot_allowed() and (strat == "all_skip" or roll < 0.25):
		stats["t_autopilot_locked"] = int(stats.get("t_autopilot_locked", 0)) + 1
	if roll > 0.96:
		main.term_close(false); stats["t_walk"] = int(stats.get("t_walk", 0)) + 1
		await _after_terminal(); return
	if strat in ["random", "broke", "night_owl"] or roll < 0.5:
		for i in rng.randi() % 6:
			var sug: Array[String] = main.term.suggestions(false)
			main.term_submit(sug[rng.randi() % sug.size()].trim_suffix(" …"), rng.randf() < 0.5)
			note("TERM " + main.term.log_lines[-1])
		if rng.randf() < 0.5: main.term_hint()
		if rng.randf() < 0.3: main.term_hint()
	if rng.randf() < 0.2: await audit("terminal")
	var guard := 0
	while main.term_open() and not main.term_done and guard < 40:
		guard += 1
		main.term_submit(main.term.next_step(), true)
	if not main.term_done:
		bad("terminal %s not solvable via next_step (%s)" % [main.term.kind, main.term.steps])
		main.term_close(false); return
	note("TERM " + main.term.reply)
	if is_inc:
		stats["inc_breached"] = int(stats.get("inc_breached", 0)) + (1 if main.inc_breached else 0)
	else:
		stats["grade_" + main.term.grade()] = int(stats.get("grade_" + main.term.grade(), 0)) + 1
	if rng.randf() < 0.1: await audit("terminal solved")
	main.term_close(true)
	await _after_terminal()

## Town map: choose destinations like this kind of player would.
func map_pref(strat: String, rng: RandomNumberGenerator) -> Array:
	match strat:
		"heavy", "quitter", "rx_spam", "broke": return ["gas", "school", "home"] if rng.randf() < 0.7 else ["school", "gas", "home"]
		"cozy", "stardew", "family_first", "balanced": return ["school", "park", "diner", "home"] if rng.randf() < 0.5 else ["school", "home"]
		"workaholic", "all_skip": return ["school", "home"]
	var all: Array = gs.PLACES.keys()
	all.shuffle()
	return all

func play_map(strat: String, rng: RandomNumberGenerator) -> void:
	var guard := 0
	var visited := {}
	while main.map_open() and guard < 10:
		guard += 1
		stats["map_opens"] = int(stats.get("map_opens", 0)) + 1
		if rng.randf() < 0.1: await audit("map")
		var ok: Array = []
		for o in gs.map_options():
			if o[3] == "": ok.append(o[0])
		var pick := ""
		for p in map_pref(strat, rng):
			if p in ok and not visited.has(p): pick = p; break
		if pick == "" and "home" in ok: pick = "home"
		if pick == "" and "school" in ok: pick = "school"
		if pick == "" and "office" in ok: pick = "office"
		if pick == "":
			# nothing useful open (e.g. waiting for after-care): the car line
			main.close_map(); main.perform_direct("pickup_girls")
			stats["map_waits"] = int(stats.get("map_waits", 0)) + 1
			break
		visited[pick] = true
		stats["map_dest"] = stats.get("map_dest", {})
		stats["map_dest"][pick] = int(stats["map_dest"].get(pick, 0)) + 1
		if rng.randf() < 0.5:
			var ev := InputEventKey.new(); ev.pressed = true; ev.keycode = (KEY_1 + main.map_order.find(pick)) as Key
			main._unhandled_input(ev)
		else:
			main.map_btns[pick].emit_signal("pressed")
		await drain()
	if main.map_open() and guard >= 10:
		bad("map loop: never left town (%s at %s)" % [gs.at_place, gs.clock_text()])
		main.close_map()

func _after_terminal() -> void:
	if main.summary_root.visible and main.summary_kind == "postmortem":
		note(main.summary_label.text)
		await audit("postmortem")
		main.dismiss_summary()

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
			if gs.day == 3 and seed_v % 5 == 0:
				# save/load round trip mid-week must restore the exact morning
				if not gs.save_game("user://bot_save_%d.json" % OS.get_process_id()): bad("save failed")
				gs.load_game("user://bot_save_%d.json" % OS.get_process_id())   # saves are "morning of": compare against that morning
				var snap := [gs.day, gs.energy, gs.closeness, gs.fridge_drawings, gs.money, gs.drinks_week]
				gs.energy = 3; gs.closeness = 1; gs.fridge_drawings = 99
				if not gs.load_game("user://bot_save_%d.json" % OS.get_process_id()): bad("load failed")
				var snap2 := [gs.day, gs.energy, gs.closeness, gs.fridge_drawings, gs.money, gs.drinks_week]
				if snap != snap2: bad("save/load mismatch %s vs %s" % [snap, snap2])
				stats["saveloads"] = int(stats.get("saveloads", 0)) + 1
				await drain()
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
		var timed: Array = allowed.filter(func(a): return gs.action_blocks(a) > 0 or a == "sleep")
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
			if a == "text_jess" and rng.randf() < 0.5:
				main.queue_cutscene("phone")   # the T key path: phone overlay with reply choices
			else:
				act(a)
			if main.assembly_open(): main.assembly_auto()
			if main.desktop_open(): main.close_desktop()
			if main.term_open():
				await play_terminal(strat, rng)
			await play_map(strat, rng)
			if gs.minutes < before_min and gs.day == last_day and not gs.week_over: bad("clock went backwards on " + a)
		check_state()
		if rng.randf() < 0.05: await audit("play")
		await drain(rng.randf() < 0.3)
		await process_frame
		if main.term_open():
			await play_terminal(strat, rng)
			await drain()
		main.auto_map()
		await play_map(strat, rng)
		if main.summary_root.visible:
			main.dismiss_summary() if not gs.week_over else null
			if gs.week_over:
				stats["endings"] += 1
				break
			await drain()
	if not gs.week_over: bad("week never finished")
	var b: Dictionary = bal.get(strat, {"n": 0, "stress": 0, "perf": 0, "jess": 0, "girls": 0, "drawings": 0, "bedtimes": 0, "drinks": 0, "pouches": 0, "rx_extra": 0, "money": 0})
	b["n"] += 1; b["stress"] += gs.stress; b["perf"] += gs.performance; b["jess"] += gs.closeness; b["girls"] += gs.girls_connected
	b["drawings"] += gs.fridge_drawings; b["bedtimes"] += gs.week_stats["bedtimes"]; b["drinks"] += gs.week_stats["drinks"]
	b["pouches"] += gs.week_stats["pouches"]; b["rx_extra"] += gs.week_stats["rx_extra"]; b["money"] += gs.money
	bal[strat] = b
	for c in gs.skills:
		skill_sum[c] = snappedf(float(skill_sum.get(c, 0.0)) + gs.skill_level(c) / 100.0, 0.01)
	stats["missed_pickups"] = int(stats.get("missed_pickups", 0)) + int(gs.week_stats.get("missed_pickups", 0))
	var en: String = gs.ending_id()
	if gs.farm_has("server") > 0:
		stats["farm_runs"] = int(stats.get("farm_runs", 0)) + 1
		stats["farm_servers_online"] = int(stats.get("farm_servers_online", 0)) + gs.farm_online()
		stats["farm_net"] = int(stats.get("farm_net", 0)) + gs.farm_income_total
		stats["farm_outages"] = int(stats.get("farm_outages", 0)) + gs.farm_outages
	stats["endings_by"][en] = int(stats["endings_by"].get(en, 0)) + 1
	stats["endings_by"][strat + ":" + en] = int(stats["endings_by"].get(strat + ":" + en, 0)) + 1
	main.summary_root.visible = false
