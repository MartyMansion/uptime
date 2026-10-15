extends "res://tests/playtest_bot.gd"
## Persona playtesters: distinct decision policies (incl. imperfect play).
##   godot --headless --path . -s res://tests/persona_bot.gd -- <persona> [runs] [outdir]
## Personas: sysadmin, cozy, speedrunner, newbie, struggling, completionist

const PERSONAS := ["sysadmin", "cozy", "speedrunner", "newbie", "struggling", "completionist"]
const REAL_CMDS := ["uptime", "journalctl -xe", "dig tc-web01", "top", "ip a", "ping -c 3 tc-web01", "sudo systemctl restart nginx",
	"curl -I https://tc-web01", "ls", "cat /var/log/syslog", "history", "man ssh", "systemctl status", "free -h", "who", "ps aux", "nmap tc-web01", "host tc-web01", "telnet tc-web01 443", "reboot"]
const NEWBIE_CMDS := ["fix it", "restart", "help me", "turn it off and on again", "why", "hello?", "ok", "printer", "internet", "cd ..", "please work", "?"]
const MASH_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_T, KEY_P, KEY_R, KEY_B, KEY_ENTER, KEY_SPACE, KEY_ESCAPE, KEY_H, KEY_F6, KEY_F7, KEY_KP_ENTER]
const SIZES := [Vector2i(1280, 720), Vector2i(1024, 600), Vector2i(1920, 1080), Vector2i(800, 600), Vector2i(1366, 768), Vector2i(2560, 1440)]

var persona := ""
var want_audit := ""
var ps := {}            # persona stats
var f7_today := -1
var harsh_hits: Array = []
const HARSH := ["loser", "pathetic", "junkie", "drunk idiot", "disgusting", "worthless", "addict", "failure of a"]

func inc(k: String, n := 1) -> void:
	ps[k] = int(ps.get(k, 0)) + n

func _run() -> void:
	gs = root.get_node("GameState")
	gs.lifeos_message.connect(func(t): note(str(t)); _harsh(str(t)))
	gs.action_performed.connect(func(_id, r): note(str(r)); _harsh(str(r)))
	var args := OS.get_cmdline_user_args()
	persona = args[0] if args.size() > 0 else "sysadmin"
	var runs := int(args[1]) if args.size() > 1 else 100
	var outdir: String = args[2] if args.size() > 2 else "/workspace/uptime-build/playtest"
	main.choice_policy = _choice
	await process_frame
	var all_ach := {}
	var all_moments := {}
	for i in runs:
		cur = "%s run %d" % [persona, i + 1]
		await play_week(persona, 5000 + i * 7 + PERSONAS.find(persona) * 100000)
		stats["runs"] += 1
		for a in gs.achievements: all_ach[a] = int(all_ach.get(a, 0)) + 1
		for m in gs.moments_seen: all_moments[m] = int(all_moments.get(m, 0)) + 1
		var maxed := 0
		for c in gs.skills: if gs.skill_level(c) >= 5: maxed += 1
		inc("skills_maxed_total", maxed)
		inc("perf_ge_90", 1 if gs.performance >= 90 else 0)
		inc("pip_weeks", 1 if int(gs.week_stats.get("pip", 0)) > 0 else 0)
		inc("gary_checkins", 1 if gs.notices_seen.has("gary_checkin") else 0)
		inc("bonus_weeks", 1 if int(gs.week_stats.get("bonus", 0)) > 0 else 0)
		inc("jess_dinners", int(gs.week_stats.get("jess_dinners", 0)))
		inc("sla_breaches", int(gs.week_stats.get("sla_breaches", 0)))
	if persona == "speedrunner": root.size = Vector2i(1280, 720)
	var f := FileAccess.open(outdir + "/persona_%s.txt" % persona, FileAccess.WRITE)
	f.store_line("PERSONA %s RUNS %d DAYS %d ACTIONS %d AUDITS %d PROBLEMS %d" % [persona, stats["runs"], stats["days"], stats["actions"], stats["audits"], problems.size()])
	f.store_line("TERMINAL tickets %d autopilot %d (locked %d) walked %d great %d good %d slow %d" % [int(stats.get("terminal", 0)), int(stats.get("t_autopilot", 0)), int(stats.get("t_autopilot_locked", 0)), int(stats.get("t_walk", 0)), int(stats.get("grade_great", 0)), int(stats.get("grade_good", 0)), int(stats.get("grade_slow", 0))])
	f.store_line("INCIDENTS %d (after-hours %d, breached %d) %s" % [int(stats.get("incidents", 0)), int(stats.get("inc_after_hours", 0)), int(stats.get("inc_breached", 0)), JSON.stringify(stats.get("inc_ids", {}))])
	f.store_line("SKILLS avg end level " + JSON.stringify(skill_sum))
	f.store_line("PSTATS " + JSON.stringify(ps))
	f.store_line("MAP opens %d waits %d dest %s missed_pickups %d" % [int(stats.get("map_opens", 0)), int(stats.get("map_waits", 0)), JSON.stringify(stats.get("map_dest", {})), int(stats.get("missed_pickups", 0))])
	f.store_line("ENDINGS " + JSON.stringify(stats["endings_by"]))
	f.store_line("ACHIEVEMENTS " + JSON.stringify(all_ach))
	f.store_line("MOMENTS %d kinds %s" % [all_moments.size(), JSON.stringify(all_moments)])
	f.store_line("ACTIONS " + JSON.stringify(stats["actions_used"]))
	f.store_line("CUTSCENES " + JSON.stringify(stats["cutscenes"]))
	for k in bal:
		var b: Dictionary = bal[k]
		var n: float = b["n"]
		f.store_line("BALANCE %s | stress %d perf %d jess %d girls %d | drawings %.1f bedtimes %.1f | drinks %.1f pouches %.1f rx_extra %.1f | money %d" % [k, b["stress"] / n, b["perf"] / n, b["jess"] / n, b["girls"] / n, b["drawings"] / n, b["bedtimes"] / n, b["drinks"] / n, b["pouches"] / n, b["rx_extra"] / n, b["money"] / n])
	for h in harsh_hits.slice(0, 20): f.store_line("HARSH " + h)
	for p in problems: f.store_line("PROBLEM " + p)
	f.close()
	print("PERSONA %s done runs=%d problems=%d" % [persona, stats["runs"], problems.size()])
	for p in problems.slice(0, 30): print("  ", p)
	quit(1 if not problems.is_empty() else 0)

func _harsh(t: String) -> void:
	var low := t.to_lower()
	for w in HARSH:
		if w in low and harsh_hits.size() < 50:
			harsh_hits.append("%s :: %s" % [w, t])

## Choice policy per persona (applied when cutscene choices are skipped).
func _choice(opts: Array) -> int:
	var labels := opts.map(func(o): return str(o[1]))
	var take := -1
	for i in labels.size():
		if str(labels[i]).begins_with("incident_take"): take = i
	if take >= 0:
		inc("pages")
		match persona:
			"sysadmin", "completionist": inc("pages_taken"); return take
			"cozy": return 1 - take
			"struggling": if randf() < 0.3: inc("pages_taken"); return take
			_: if randf() < 0.5: inc("pages_taken"); return take
		return 1 - take
	if persona == "struggling" and gs.day >= 3:
		for i in labels.size():
			if "honest" in str(labels[i]): inc("chose_honest"); return i
	if persona == "completionist":
		var best := 0
		for i in labels.size():
			if not gs.notices_seen.has("choice_" + str(labels[i])): return i
		return best
	return randi() % opts.size()

func map_pref(strat: String, rng: RandomNumberGenerator) -> Array:
	match persona:
		"sysadmin": return ["coffee", "school", "home"]
		"cozy": return ["coffee", "school", "park", "diner", "home"]
		"struggling": return ["gas", "pharmacy", "school", "home"] if rng.randf() < 0.7 else ["diner", "gas", "park", "school", "home"]
		"newbie":
			var a: Array = gs.PLACES.keys(); a.shuffle(); return a
		"speedrunner":
			# click locked places first: they must be refused without side effects
			for o in gs.map_options():
				if o[3] != "" and rng.randf() < 0.5:
					var before := [gs.minutes, gs.phase, gs.at_place, gs.money]
					main.map_pick(o[0])
					if [gs.minutes, gs.phase, gs.at_place, gs.money] != before: bad("locked map place %s changed state" % o[0])
					inc("locked_map_clicks")
			var b: Array = gs.PLACES.keys(); b.shuffle(); return b
		"completionist":
			var c: Array = gs.PLACES.keys()
			c.sort_custom(func(x, y): return int(ps.get("visit_" + x, 0)) < int(ps.get("visit_" + y, 0)))
			for x in c: inc("visit_" + x)
			return c
	return super(strat, rng)

func drain(step := false) -> void:
	if want_audit != "":
		var w := want_audit
		want_audit = ""
		await audit(w)
	await super(step)

var trail: Array = []
func check_state() -> void:
	super()
	if OS.has_environment("TRAIL") and gs.day == int(OS.get_environment("TRAIL")): print("%s %s %s inc=%s cs=%s sum=%s term=%s" % [gs.day, gs.clock_text(), gs.phase, main.inc_id, main.cs_id, main.summary_root.visible, main.term_open()])
	if gs.girls_fed == 0: inc("girls_fed_zero_moments")
	if gs.girls_fed < 25: inc("girls_fed_low_moments")

func choose(strat: String, allowed: Array, rng: RandomNumberGenerator) -> String:
	var pref: Array = []
	match persona:
		"sysadmin":
			pref = ["leave_for_work", "rx_dose", "work_ticket", "head_home", "pickup_girls", "feed_girls", "text_jess", "bedtime_story", "gaming", "sleep"]
			if gs.today.get("rx_dose", 0) >= 1: pref.erase("rx_dose")
			if gs.minutes < 1170 and gs.today.get("bedtime_story", 0) == 0: pref.erase("sleep")
			if gs.today.get("gaming", 0) >= 1: pref.erase("gaming")
		"cozy":
			return super("cozy", allowed, rng)
		"struggling":
			if gs.day < 3 or rng.randf() < 0.3:
				pref = ["pouch", "rx_dose", "cereal", "leave_for_work", "work_ticket", "head_home", "buy_beer", "buy_pouches", "pickup_girls", "drink", "gaming", "sleep"]
				if gs.today.get("drink", 0) >= 4: pref.erase("drink")
				if gs.today.get("pouch", 0) >= 4: pref.erase("pouch")
				if gs.today.get("rx_dose", 0) >= 2: pref.erase("rx_dose")
				if rng.randf() < 0.25: return allowed[rng.randi() % allowed.size()]   # lets meters slip
			else:
				return super("quitter", allowed, rng)
		"completionist":
			var best := ""
			var bc := 1 << 30
			for a in allowed:
				var c := int(ps.get("act_" + a, 0))
				if a == "sleep" and gs.minutes < 1260: c += 1000
				if c < bc: bc = c; best = a
			inc("act_" + best)
			if rng.randf() < 0.6:
				var r := super("stardew", allowed, rng)
				if r != "": inc("act_" + r); return r
			return best
		"newbie":
			return super("balanced", allowed, rng) if rng.randf() < 0.7 else allowed[rng.randi() % allowed.size()]
		"speedrunner":
			_chaos(rng)
			# spam actions incl. disallowed ones (must be rejected cleanly)
			if rng.randf() < 0.3:
				var ids: Array = gs.ACTIONS.keys()
				var bad_id: String = ids[rng.randi() % ids.size()]
				var before := [gs.minutes, gs.energy, gs.money]
				if gs.can_do(bad_id) != "":
					main.perform(bad_id)
					if main.term_open(): main.term_close(false)
					if [gs.minutes, gs.energy, gs.money] != before: bad("disallowed action %s changed state" % bad_id)
					inc("rejected_spam")
			if main.term_open() or main.cs_id != "" or main.summary_root.visible: return ""
			# recompute after chaos
			var now: Array = []
			for id in gs.phase_actions():
				if gs.can_do(id) == "": now.append(id)
			if now.is_empty() or rng.randf() < 0.5: return ""   # harness falls back to a timed action
			return now[rng.randi() % now.size()]
	for p in pref:
		if p in allowed: return p
	return allowed[rng.randi() % allowed.size()] if not allowed.is_empty() else ""

func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	main._unhandled_input(e)

func _chaos(rng: RandomNumberGenerator) -> void:
	for i in rng.randi() % 6:
		var k: Key = MASH_KEYS[rng.randi() % MASH_KEYS.size()]
		if k == KEY_F7:
			if f7_today == gs.day or rng.randf() < 0.7: continue
			f7_today = gs.day
			inc("f7_loads")
		if k == KEY_F6: inc("f6_saves")
		_key(k)
		inc("keys_mashed")
		if main.term_open() and rng.randf() < 0.5:
			main.term_submit(["", "   ", "x".repeat(300), "rm -rf /", "ssh", "ssh ssh ssh", "ping", "💀", "firewall allow 99999", "systemctl restart", "set vlan -1"][rng.randi() % 11], rng.randf() < 0.5)
			main.term_hint(); main.term_hint(); main.term_hint(); main.term_hint(); main.term_hint()
			if main.term_open() and main.term != null and not main.autopilot_allowed():
				main.term_autopilot()   # must be refused
				if main.term == null: bad("locked autopilot closed the ticket")
			if rng.randf() < 0.5: main.term_close(false); inc("rage_quits")
	if rng.randf() < 0.08:
		root.size = SIZES[rng.randi() % SIZES.size()]
		inc("resizes")
		want_audit = "resize %s" % root.size
	if rng.randf() < 0.03 and f7_today != gs.day:
		f7_today = gs.day
		# save/load abuse: save now, scramble, load
		if gs.save_game("user://sr_save_%d.json" % OS.get_process_id()):
			var d: int = gs.day
			gs.energy = 0; gs.money = 99999
			if not gs.load_game("user://sr_save_%d.json" % OS.get_process_id()): bad("speedrun load failed")
			elif gs.day != d or gs.money == 99999: bad("load did not restore state")
			main.cs_queue.clear(); main.cs_id = ""; main.summary_root.visible = false
			main.loc_name = ""; main.sync_location()
			inc("save_load_abuse")

## Persona-specific terminal play.
func play_terminal(strat: String, rng: RandomNumberGenerator) -> void:
	var t: TicketSim = main.term
	if t == null: return
	var is_inc: bool = main.inc_id != ""
	stats["terminal"] = int(stats.get("terminal", 0)) + 1
	if is_inc:
		stats["incidents"] = int(stats.get("incidents", 0)) + 1
		stats["inc_ids"] = stats.get("inc_ids", {})
		stats["inc_ids"][main.inc_id] = int(stats["inc_ids"].get(main.inc_id, 0)) + 1
		if main.inc_after_hours: stats["inc_after_hours"] = int(stats.get("inc_after_hours", 0)) + 1
	var perf0: int = gs.performance
	match persona:
		"sysadmin":
			if rng.randf() < 0.35:
				var c: String = REAL_CMDS[rng.randi() % REAL_CMDS.size()]
				main.term_submit(c, false)
				var out: String = "\n".join(main.term.log_lines.slice(-2)) if main.term else ""
				inc("probe")
				if "command not found" in out: ps["unknown_" + c.split(" ")[0]] = int(ps.get("unknown_" + c.split(" ")[0], 0)) + 1
			if main.term and rng.randf() < 0.5:
				# types like a shell user: first letters + Tab
				var ns: String = main.term.next_step()
				main.term_input.text = ns.substr(0, 3); main.term_tab()
				inc("tab_tries")
				if ns.begins_with(main.term_input.text.strip_edges()) and main.term_input.text.length() > 3: inc("tab_ok")
				main.term_input.text = ""
			await _solve(false, 40)
		"cozy":
			if main.autopilot_allowed() and rng.randf() < 0.8:
				main.term_autopilot(); stats["t_autopilot"] = int(stats.get("t_autopilot", 0)) + 1
			else:
				if not main.autopilot_allowed(): stats["t_autopilot_locked"] = int(stats.get("t_autopilot_locked", 0)) + 1
				if rng.randf() < 0.1: main.term_close(false); stats["t_walk"] = int(stats.get("t_walk", 0)) + 1
				else:
					main.term_hint()
					await _solve(true, 40)
		"newbie":
			await _newbie(rng)
		"struggling":
			if main.autopilot_allowed() and rng.randf() < 0.6:
				main.term_autopilot(); stats["t_autopilot"] = int(stats.get("t_autopilot", 0)) + 1
			elif rng.randf() < 0.15:
				main.term_close(false); stats["t_walk"] = int(stats.get("t_walk", 0)) + 1
			else:
				for i in rng.randi() % 5:
					if main.term == null or main.term_done: break
					var sug: Array[String] = main.term.suggestions(false)
					main.term_submit(sug[rng.randi() % sug.size()].trim_suffix(" …"), false)
				await _solve(false, 40)
		"completionist":
			if main.autopilot_allowed() and rng.randf() < 0.1:
				main.term_autopilot(); stats["t_autopilot"] = int(stats.get("t_autopilot", 0)) + 1
			else:
				await _solve(true, 40)
		"speedrunner":
			if rng.randf() < 0.4: main.term_close(false); stats["t_walk"] = int(stats.get("t_walk", 0)) + 1
			elif main.autopilot_allowed() and rng.randf() < 0.5:
				main.term_autopilot(); stats["t_autopilot"] = int(stats.get("t_autopilot", 0)) + 1
			else:
				for i in 3: main.term_submit(main.term.next_step() if main.term else "", rng.randf() < 0.5)
				_key(KEY_H); _key(KEY_ENTER)
				await _solve(true, 40)
	if is_inc: inc("inc_perf_delta", gs.performance - perf0)
	else: inc("ticket_perf_delta", gs.performance - perf0)
	await _after_terminal()
	if main.term_open(): main.term_close(false)

func _solve(clicked: bool, guard_max: int) -> void:
	var guard := 0
	while main.term_open() and main.term != null and not main.term_done and guard < guard_max:
		guard += 1
		main.term_submit(main.term.next_step(), clicked)
	if main.term_open() and main.term != null and not main.term_done:
		bad("terminal %s not solvable via next_step" % main.term.kind)
		main.term_close(false); return
	if main.term_open() and main.term != null:
		var is_inc: bool = main.inc_id != ""
		if is_inc: stats["inc_breached"] = int(stats.get("inc_breached", 0)) + (1 if main.inc_breached else 0)
		else: stats["grade_" + main.term.grade()] = int(stats.get("grade_" + main.term.grade(), 0)) + 1
		if randf() < 0.1: await audit("terminal solved")
		main.term_close(true)

## Never used a CLI: types nonsense, clicks around, reads hints literally, often gives up.
func _newbie(rng: RandomNumberGenerator) -> void:
	var cmds := 0
	var gave_up_today := int(ps.get("gu_%d_%d" % [stats["runs"], gs.day], 0))
	while main.term_open() and main.term != null and not main.term_done and cmds < 18:
		cmds += 1
		var r := rng.randf()
		if r < 0.05:
			main.term_input.text = "p"; main.term_tab(); main.term_tab(); inc("newbie_tab"); main.term_input.text = ""
		elif r < 0.25:
			main.term_submit(NEWBIE_CMDS[rng.randi() % NEWBIE_CMDS.size()], false); inc("newbie_nonsense")
		elif r < 0.45:
			var before: int = main.term.hints_used
			main.term_hint()
			if main.term.hints_used == before and not gs.rx_active(): inc("newbie_hint_refused")
			var h: String = main.term.log_lines[-1]
			if "Try: " in h:
				main.term_submit(h.split("Try: ")[1].strip_edges(), true); inc("newbie_followed_hint")
		else:
			var sug: Array[String] = main.term.suggestions(false)
			main.term_submit(sug[rng.randi() % sug.size()].trim_suffix(" …"), true)
	if main.term_open() and main.term != null and main.term_done:
		var is_inc: bool = main.inc_id != ""
		if not is_inc: stats["grade_" + main.term.grade()] = int(stats.get("grade_" + main.term.grade(), 0)) + 1
		else: stats["inc_breached"] = int(stats.get("inc_breached", 0)) + (1 if main.inc_breached else 0)
		inc("newbie_solved")
		main.term_close(true)
	elif main.term_open():
		inc("newbie_gave_up")
		stats["t_walk"] = int(stats.get("t_walk", 0)) + 1
		main.term_close(false)
