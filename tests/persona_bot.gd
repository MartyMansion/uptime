extends "res://tests/playtest_bot.gd"
## Persona playtesters: distinct decision policies (incl. imperfect play).
##   godot --headless --path . -s res://tests/persona_bot.gd -- <persona> [runs] [outdir]
## Personas: sysadmin, cozy, speedrunner, newbie, struggling, completionist, paperfan,
##   homelab (datacenter vet), tycoon (management sim fan), therapist (family therapist), a11y (accessibility/UX), comedy (comedy writer)
## Every persona also checks the paper presentation (cards, camera, prompts, banner) at each audit.

const PERSONAS := ["sysadmin", "cozy", "speedrunner", "newbie", "struggling", "completionist", "paperfan", "homelab", "tycoon", "therapist", "a11y", "comedy"]
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
	f.store_line("FARM runs %d orders %d builds %d servers_online %d net $%d outages %d" % [int(stats.get("farm_runs", 0)), int(ps.get("farm_orders", 0)), int(ps.get("farm_builds", 0)), int(stats.get("farm_servers_online", 0)), int(stats.get("farm_net", 0)), int(stats.get("farm_outages", 0))])
	f.store_line("ACHIEVEMENTS " + JSON.stringify(all_ach))
	f.store_line("MOMENTS %d kinds %s" % [all_moments.size(), JSON.stringify(all_moments)])
	f.store_line("ACTIONS " + JSON.stringify(stats["actions_used"]))
	f.store_line("CUTSCENES " + JSON.stringify(stats["cutscenes"]))
	for k in bal:
		var b: Dictionary = bal[k]
		var n: float = b["n"]
		f.store_line("BALANCE %s | stress %d perf %d jess %d girls %d | drawings %.1f bedtimes %.1f | drinks %.1f pouches %.1f rx_extra %.1f | money %d" % [k, b["stress"] / n, b["perf"] / n, b["jess"] / n, b["girls"] / n, b["drawings"] / n, b["bedtimes"] / n, b["drinks"] / n, b["pouches"] / n, b["rx_extra"] / n, b["money"] / n])
	for h in harsh_hits.slice(0, 20): f.store_line("HARSH " + h)
	if persona in ["comedy", "therapist"]:
		var ks: Array = lines.keys()
		ks.sort_custom(func(a, b): return lines[a] > lines[b])
		f.store_line("UNIQUE_LINES %d  TOTAL_SHOWN %d" % [ks.size(), lines.values().reduce(func(a, b): return a + b, 0)])
		for k in ks.slice(0, 40): f.store_line("REPEAT %6d | %s" % [lines[k], str(k).replace("\n", " / ").left(220)])
		var lf := FileAccess.open(outdir + "/lines_%s.txt" % persona, FileAccess.WRITE)
		for k in ks: lf.store_line("%6d | %s" % [lines[k], str(k).replace("\n", " / ")])
		lf.close()
	for p in problems: f.store_line("PROBLEM " + p)
	f.close()
	print("PERSONA %s done runs=%d problems=%d" % [persona, stats["runs"], problems.size()])
	for p in problems.slice(0, 30): print("  ", p)
	quit(1 if not problems.is_empty() else 0)

func _harsh(t: String) -> void:
	var low := t.to_lower()
	for w in HARSH:
		if RegEx.create_from_string("\\b" + w + "\\b").search(low) != null and harsh_hits.size() < 50:   # word match ("closer" is not "loser")
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
	if persona == "therapist":
		for i in labels.size():
			for w in ["honest", "talk", "sorry", "listen", "ask"]:
				if w in str(labels[i]).to_lower(): inc("therapist_kind_choice"); return i
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
		"tycoon": return ["school", "home"]
		"therapist": return ["park", "school", "diner", "home"]
		"comedy":
			var e: Array = gs.PLACES.keys(); e.shuffle(); return e
		"completionist":
			var c: Array = gs.PLACES.keys()
			c.sort_custom(func(x, y): return int(ps.get("visit_" + x, 0)) < int(ps.get("visit_" + y, 0)))
			for x in c: inc("visit_" + x)
			return c
	return super(strat, rng)

func drain(step := false) -> void:
	if persona in ["paperfan", "comedy", "a11y"] and main.cs_id != "" and randf() < (0.35 if persona == "paperfan" else 0.6):
		await watch_cutscene()
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

# Vet: power protection and the circuit before density; cooling before the 3rd box.
const HOMELAB_PLAN := ["rack", "switch", "server", "server", "ups", "electrician", "server", "fans", "drives", "foam", "nic"]

## Tycoon: greedy ROI. Buys whatever raises daily net the most per dollar right now.
func _tycoon_plan() -> Array:
	var best := ""
	var best_roi := -1.0
	for id in gs.CATALOG:
		var saved: Dictionary = gs.farm.duplicate()
		var base: int = gs.farm_income_day() - gs.farm_bill_day()
		gs.farm[id] = gs.farm_has(id) + 1
		for o in gs.orders: gs.farm[o[0]] = gs.farm_has(o[0]) + 1
		var gain: int = gs.farm_income_day() - gs.farm_bill_day() - base
		gs.farm = saved
		var roi: float = (gain + 0.5) / float(gs.CATALOG[id]["price"])
		if gain > 0 and roi > best_roi: best_roi = roi; best = id
	if best == "":   # nothing pays alone: unlock the next tier
		# unlock the bottleneck first: shelf (1) -> rack + switch (2) -> circuit (3+)
		var pending: Array = gs.orders.map(func(o): return o[0]) + gs.boxes
		for id in ["server", "rack", "switch"]:
			if gs.farm_has(id) == 0 and not (id in pending): best = id; break
		if best == "" and not ("server" in pending) and not ("electrician" in pending):
			best = "electrician" if gs.farm_has("server") >= 2 and gs.farm_has("electrician") == 0 else "server"
	return [best] if best != "" else []

## Datacenter vet / tycoon: sanity-check the farm model every time they look at it.
func farm_judge() -> void:
	inc("farm_judged")
	var on: int = gs.farm_online()
	if on > gs.farm_has("server"): bad("more servers online than installed")
	if gs.farm_has("server") > 0 and gs.farm_watts() < on * 150: bad("farm draws less power than its servers")
	if gs.farm_bill_day() < 0 or gs.farm_income_day() < 0: bad("negative farm economics")
	var kwh: float = gs.farm_watts() * 24 / 1000.0
	if absf(gs.farm_bill_day() - kwh * gs.POWER_RATE) > 1.0: bad("power bill doesn't match draw")
	if gs.farm_has("fans") > 0 and gs.farm_heat() > on * 2: bad("fans make it hotter")
	ps["max_online"] = maxi(int(ps.get("max_online", 0)), on)
	ps["max_watts"] = maxi(int(ps.get("max_watts", 0)), gs.farm_watts())
	inc("net_day_sum", gs.farm_income_day() - gs.farm_bill_day())
	inc("net_day_n")
	if gs.farm_has("server") > gs.farm_online(): inc("idle_server_looks")

const FARM_PLAN := ["server", "rack", "switch", "server", "ups", "fans", "drives", "foam", "electrician", "server", "nic"]

## Homelab builders: shop on the home PC, build boxes in the garage (exercises the desktop + assembly UI).
func farm_routine(rng: RandomNumberGenerator) -> void:
	if not (persona in ["sysadmin", "completionist", "paperfan", "homelab", "tycoon"]) or main.is_busy(): return
	var pro: bool = persona in ["homelab", "tycoon"]
	var eager := 0.9 if pro else 0.4
	if not (gs.phase in ["home_pm", "weekend", "home_am"]) or (gs.phase == "home_am" and persona != "tycoon") or rng.randf() > eager: return
	if pro: farm_judge()
	if not gs.boxes.is_empty():
		main.near_station = "garage"; main.perform("go_garage")
		if main.loc_name != "garage": bad("garage door did not open the garage")
		for k in (3 if pro else 1):
			if gs.boxes.is_empty() or gs.minutes >= gs.DAY_END - 60: break
			if gs.can_do("build_farm") != "": inc("farm_build_blocked"); break   # too tired / too late: the game says why
			main.near_station = "boxes"; main.perform("build_farm")
			if not main.assembly_open(): bad("boxes did not open the assembly"); return
			if persona == "paperfan": main.assembly_step(main.asm_order.find(2)); inc("farm_fumbles")
			main.relayout(main.ui); main.relayout(main.ui)
			for p in main.audit_ui(): bad("assembly UI: " + p)
			var id: String = gs.boxes[0]
			var n0: int = gs.farm_has(id)
			main.assembly_auto()
			if gs.farm_has(id) != n0 + 1: bad("assembly did not install " + id)
			inc("farm_builds")
		main.perform("go_inside")
		if main.loc_name == "garage": bad("garage exit did not return to the house")
		if not pro: return
	var have := {}
	for x in gs.farm: have[x] = int(gs.farm[x])
	for o in gs.orders: have[o[0]] = int(have.get(o[0], 0)) + 1
	for x in gs.boxes: have[x] = int(have.get(x, 0)) + 1
	var plan: Array = FARM_PLAN
	if persona == "homelab": plan = HOMELAB_PLAN
	elif persona == "tycoon": plan = _tycoon_plan()
	var reserve: int = {"tycoon": 0, "homelab": 0}.get(persona, 40)
	var need := {}
	var buy: Array = []
	var budget: int = gs.money - reserve
	for id in plan:
		need[id] = int(need.get(id, 0)) + 1
		if int(need[id]) > int(have.get(id, 0)):
			if int(gs.CATALOG[id]["price"]) > budget:
				inc("farm_cant_afford"); break
			buy.append(id); budget -= int(gs.CATALOG[id]["price"])
			if not pro: break
	if buy.is_empty(): return
	main.near_station = "desk"; main.perform("pc")
	if not main.desktop_open(): bad("PC did not open the desktop"); return
	var cost := 0
	for id in buy:
		main.desk_app(gs.CATALOG[id]["shop"])
		main.relayout(main.ui); main.relayout(main.ui)
		for p in main.audit_ui(): bad("desktop UI: " + p)
		main.cart_add(id); cost += int(gs.CATALOG[id]["price"])
	main.desk_app("cart")
	var m0: int = gs.money
	var res: String = main.cart_checkout()
	if not res.begins_with("Order placed") or gs.money != m0 - cost: bad("checkout failed: " + res)
	inc("farm_orders", buy.size())
	inc("farm_checkouts")
	main.desk_app("farm")
	main.close_desktop()

func choose(strat: String, allowed: Array, rng: RandomNumberGenerator) -> String:
	farm_routine(rng)
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
		"paperfan":
			# here for the craft: goes where the sets and cutscenes are, walks around a lot
			if main.loc and rng.randf() < 0.25: stroll(rng)
			return super("stardew", allowed, rng)
		"homelab":
			pref = ["feed_girls", "leave_for_work", "rx_dose", "work_ticket", "head_home", "pickup_girls", "text_jess", "family_dinner", "bedtime_story", "sleep"]
			if gs.today.get("rx_dose", 0) >= 1: pref.erase("rx_dose")
			if gs.today.get("tickets", 0) >= 3: pref.erase("work_ticket")
			if gs.minutes < 1170 and gs.today.get("bedtime_story", 0) == 0: pref.erase("sleep")
		"tycoon":
			# min-maxer: money first, family is "upkeep" (one text, bedtime only if cheap)
			pref = ["cereal", "leave_for_work", "rx_dose", "work_ticket", "side_hustle", "head_home", "pickup_girls", "work_ticket", "sleep"]
			if gs.today.get("text_jess", 0) == 0: pref.push_front("text_jess")
			if gs.today.get("rx_dose", 0) >= 1: pref.erase("rx_dose")
			if gs.minutes < 1080: pref.erase("sleep")
		"therapist":
			if gs.day == 0 and gs.today.get("drink", 0) < 1 and "drink" in allowed: inc("therapist_slip"); return "drink"   # tests the relapse/recovery thread
			return super("quitter" if gs.day < 4 else "family_first", allowed, rng)
		"a11y":
			if gs.phase in ["home_pm", "weekend"] and rng.randf() < 0.15: a11y_desktop()
			return super("stardew" if rng.randf() < 0.6 else "balanced", allowed, rng)
		"comedy":
			# wants to see every bit: random-ish, but makes sure set pieces happen
			return super("random" if rng.randf() < 0.4 else ("heavy" if rng.randf() < 0.2 else "stardew"), allowed, rng)
		"newbie":
			return super("balanced", allowed, rng) if rng.randf() < 0.7 else allowed[rng.randi() % allowed.size()]
		"speedrunner":
			_chaos(rng)
			# spam actions incl. disallowed ones (must be rejected cleanly)
			if rng.randf() < 0.3 and not main.is_busy():
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
		"paperfan":
			# not a sysadmin: reads one hint, then types what the live suggestions say
			if main.autopilot_allowed() and rng.randf() < 0.4:
				main.term_autopilot(); stats["t_autopilot"] = int(stats.get("t_autopilot", 0)) + 1
			else:
				if rng.randf() < 0.5: main.term_hint()
				if main.term and rng.randf() < 0.3:
					var sug: Array[String] = main.term.suggestions(false)
					main.term_submit(sug[rng.randi() % sug.size()].trim_suffix(" …"), false)
				await _solve(rng.randf() < 0.5, 40)
		"homelab", "tycoon":
			if persona == "tycoon" and main.autopilot_allowed() and rng.randf() < 0.5:
				main.term_autopilot(); stats["t_autopilot"] = int(stats.get("t_autopilot", 0)) + 1
			else:
				await _solve(false, 40)
		"therapist":
			if main.autopilot_allowed() and rng.randf() < 0.7:
				main.term_autopilot(); stats["t_autopilot"] = int(stats.get("t_autopilot", 0)) + 1
			else:
				main.term_hint(); await _solve(true, 40)
		"a11y":
			# keyboard only: type, Tab-complete, Enter; H for a hint
			var g := 0
			while main.term_open() and main.term != null and not main.term_done and g < 40:
				g += 1
				var ns: String = main.term.next_step()
				main.term_input.text = ns.substr(0, mini(3, ns.length())); main.term_tab()
				if not ns.begins_with(main.term_input.text.strip_edges()): inc("a11y_tab_wrong")
				main.term_input.text = ns
				main.term_submit(main.term_input.text, false)
				if g == 1 and rng.randf() < 0.3: main.term_input.release_focus(); _key(KEY_H); inc("a11y_hint_key")
			if main.term_open() and main.term_done:
				if main.inc_id != "": stats["inc_breached"] = int(stats.get("inc_breached", 0)) + (1 if main.inc_breached else 0); inc("inc_by_hand")
				_key(KEY_ENTER)
				if main.term_open(): bad("Enter does not close a finished ticket"); main.term_close(true)
		"comedy":
			if rng.randf() < 0.5: main.term_hint()
			main.term_submit(NEWBIE_CMDS[rng.randi() % NEWBIE_CMDS.size()], false)
			await _solve(rng.randf() < 0.5, 40)
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
		if is_inc: stats["inc_breached"] = int(stats.get("inc_breached", 0)) + (1 if main.inc_breached else 0); inc("inc_by_hand")
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
		else: stats["inc_breached"] = int(stats.get("inc_breached", 0)) + (1 if main.inc_breached else 0); inc("inc_by_hand")
		inc("newbie_solved")
		main.term_close(true)
	elif main.term_open():
		inc("newbie_gave_up")
		stats["t_walk"] = int(stats.get("t_walk", 0)) + 1
		main.term_close(false)

# ------------------------------------------------------------ paper presentation checks (all personas)
func audit(where: String) -> void:
	await super(where)
	paper_check(where)

func paper_check(where: String) -> void:
	var d: Diorama = main.diorama
	if d == null: bad("no paper diorama"); return
	inc("paper_checks")
	if main.loc == null: return
	if d.set_name != main.loc_name: bad("paper set %s doesn't match location %s (%s)" % [d.set_name, main.loc_name, where])
	var vis: Array[String] = []
	for n in main.loc.actors:
		var a: Actor = main.loc.actors[n]
		if is_instance_valid(a) and a.visible and (d.place == "" or n == "dan"): vis.append(n)
	for n in vis:
		if not d.cards.has(n) or not d.cards[n].visible: bad("%s has no visible paper card (%s)" % [n, where]); continue
		var c: PaperCard = d.cards[n]
		if absf(c.position.x) > d.XW - 0.2: bad("%s card outside the set walls x=%.2f (%s)" % [n, c.position.x, where])
	# lanes: after spacing, no two cards on one depth lane overlap much
	d._space(vis, main.loc, 0.0)
	for i in vis.size():
		for j in range(i + 1, vis.size()):
			var pa: Vector3 = d.to3(main.loc.actors[vis[i]].position) + Vector3(float(d._vis_off.get(vis[i], 0.0)), 0, 0)
			var pb: Vector3 = d.to3(main.loc.actors[vis[j]].position) + Vector3(float(d._vis_off.get(vis[j], 0.0)), 0, 0)
			if absf(pa.z - pb.z) <= 1.0 and absf(pa.x - pb.x) < (d.card(vis[i]).size.x + d.card(vis[j]).size.x) * 0.3:
				bad("cards %s/%s overlap on one lane (%s)" % [vis[i], vis[j], where])
	var leaks := d.edge_leaks(1.63)
	if leaks > 0: bad("camera sees past the set (%d corners) in %s (%s)" % [leaks, d.set_name + d.place, where])
	if main.dialog_panel.visible and main.cs_waiting == "say" and main.talk_who in PaperCard.HEIGHTS and not main.loc.actors.has(main.talk_who):
		inc("offscreen_speaker")   # voice-over lines (phone, page): fine, but counted

## Paper fan: walks around the set (exercises flips, walk cycle, camera follow).
func stroll(rng: RandomNumberGenerator) -> void:
	if main.is_busy() or main.loc == null: return
	var d: Diorama = main.diorama
	var f0: int = d.cards["dan"].flips if d.cards.has("dan") else 0
	for k in 3:
		var tgt: Vector2 = main.loc.bounds.position + Vector2(rng.randf() * main.loc.bounds.size.x, rng.randf() * main.loc.bounds.size.y)
		main.dan.walk_to(tgt)
		for i in 40:
			if main.dan._tween and main.dan._tween.is_valid(): main.dan._tween.custom_step(1.0 / 30.0)
			main._process(1.0 / 30.0)
			var c: PaperCard = d.cards.get("dan")
			if c and c.flipping():
				inc("flip_frames")
				if c.layers[1].position.z == c.layers[3].position.z: bad("flip shows no card thickness")
			if d.edge_leaks(1.63) > 0: inc("stroll_leak_frames")
			inc("stroll_frames")
	main.dan.stop_walking()
	if d.cards.has("dan"): inc("stroll_flips", d.cards["dan"].flips - f0)

## Paper fan: watches a cutscene in "real time" (30 fps) and judges timing, flaps and framing.
func watch_cutscene() -> void:
	inc("watched_cutscenes")
	var d: Diorama = main.diorama
	var frames := 0
	while main.cs_id != "" and frames < 4000:
		frames += 1
		if main.cs_waiting == "choice":
			main.pick_choice(_choice(main.cs_choices) if main.cs_choices.size() > 0 else 0); continue
		if main.cs_waiting == "move" and main.cs_mover and is_instance_valid(main.cs_mover) and main.cs_mover._tween and main.cs_mover._tween.is_valid():
			main.cs_mover._tween.custom_step(1.0 / 30.0)
		main._process(1.0 / 30.0)
		if main.cs_waiting == "say":
			if main.typing():
				inc("type_frames")
				if main.talk_flap > 0.0: inc("flap_frames")
			else:
				if main.talk_flap > 0.0: bad("mouth flapping after the line finished")
				inc("lines_watched")
				var t: String = main.dialog_text.text
				inc("chars_watched", t.length())
				if persona == "comedy": note("SAY %s: %s" % [main.talk_who, t])
				if persona == "a11y" and main.dialog_text.get_theme_font_size("font_size") < 14: bad("dialogue font below 14px")
				if t.length() > 150: inc("long_lines")
				if t.ends_with("?") or t.ends_with("!") or t.ends_with("."): inc("lines_with_button")
				var sp: String = main.talk_who
				if sp in PaperCard.HEIGHTS and main.loc.actors.has(sp) and d.cards.has(sp):
					var cam: Camera3D = d.cam
					if not cam.is_position_in_frustum(d.cards[sp].position + Vector3(0, 0.8, 0)): inc("speaker_offframe")
					else: inc("speaker_inframe")
				for l in d.signs:
					if not is_instance_valid(l) or l.name.begins_with("Foreground") or l.global_position.y < 0.3: continue
					if cam_in_banner(l.global_position): inc("sign_under_banner"); break
				main.advance()
		if d.edge_leaks(1.63) > 0: inc("cutscene_leak_frames")
		inc("cutscene_frames")
	if main.cs_id != "": main.skip_all_cutscenes()

## True if a world point projects into the dialogue banner rect (bottom of the game area).
func cam_in_banner(p: Vector3) -> bool:
	var cam: Camera3D = main.diorama.cam
	if not cam.is_position_in_frustum(p): return false
	var vp := cam.get_viewport()
	var sz: Vector2 = vp.get_visible_rect().size
	if sz.x < 10: return false
	var sp := cam.unproject_position(p)
	var r: Rect2 = main.dialog_panel.get_global_rect()
	var wr: Rect2 = main.world_slot.get_global_rect()
	var gp := wr.position + sp * (wr.size / sz)
	return r.has_point(gp)


# ------------------------------------------------------------ accessibility / UX tester
const KEY_FOR := {"text_jess": KEY_T, "pouch": KEY_P, "rx_dose": KEY_R, "breathe": KEY_B}

## Keyboard-only play: walk to the station, press its number (or the global key).
func act(a: String) -> void:
	if persona != "a11y":
		main.perform(a); return
	if KEY_FOR.has(a):
		_key(KEY_FOR[a]); inc("a11y_global_key"); return
	if main.loc:
		for sid in main.loc.stations:
			if a in main.loc.stations[sid]["actions"]:
				main.dan.position = (main.loc.stations[sid]["rect"] as Rect2).get_center()
				main._process(0.0)
				var idx: int = main._current_actions().find(a)
				if main.near_station != sid: inc("a11y_station_miss")
				elif idx < 0 or idx > 3: bad("%s at %s is not on keys 1-4 (%s)" % [a, sid, main._current_actions()])
				else:
					_key((KEY_1 + idx) as Key); inc("a11y_keyed"); _ui_scan("act"); return
	inc("a11y_mouse_only_" + a)
	main.perform(a)

## Opens the PC with the keyboard and checks focus, then Esc out.
func a11y_desktop() -> void:
	if main.is_busy() or main.loc_name != "house": return
	act("pc")
	if not main.desktop_open(): bad("keyboard: PC desk did not open the desktop"); return
	inc("a11y_desktop")
	var fo: Control = root.get_viewport().gui_get_focus_owner()
	if fo == null or not main.desktop.is_ancestor_of(fo): bad("desktop opens without keyboard focus")
	main.desk_app(["pceggo", "rackbay", "kevin", "cart", "farm"][randi() % 5])
	main.relayout(main.ui); main.relayout(main.ui)
	fo = root.get_viewport().gui_get_focus_owner()
	if fo == null or not main.desk_window.is_ancestor_of(fo): bad("window opens without keyboard focus (%s)" % main.desk_app_id)
	_ui_scan("desktop " + main.desk_app_id)
	_key(KEY_ESCAPE)
	if main.desk_window.visible: bad("Esc does not close the window")
	_key(KEY_ESCAPE)
	if main.desktop_open(): bad("Esc does not close the desktop"); main.close_desktop()

## Readability scan of visible UI: font sizes, click-target sizes.
func _ui_scan(where: String) -> void:
	if persona != "a11y": return
	inc("a11y_scans")
	var stack: Array = [main.ui]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree(): continue
		for c in n.get_children(): stack.append(c)
		if n is Label or n is Button:
			var fs: int = (n as Control).get_theme_font_size("font_size")
			if fs < 12: bad("font %dpx below 12 in %s: '%s'" % [fs, where, str(n.text).left(30)])
			elif fs < 14: ps["small_font_" + str(fs)] = int(ps.get("small_font_" + str(fs), 0)) + 1
		if n is Button and (n as Button).is_visible_in_tree():
			var r := (n as Button).get_global_rect()
			if r.size.y > 0 and r.size.y < 24: bad("click target %dpx tall in %s: '%s'" % [int(r.size.y), where, (n as Button).text.left(20)])
