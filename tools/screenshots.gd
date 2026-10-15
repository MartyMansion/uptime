extends SceneTree
## Renders gameplay/cutscene screenshots + runs the UI audit.
## Needs a real renderer: xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/screenshots.gd -- <outdir> [prefix]

var main: Node
var gs: Node
var out := "user://screens"
var prefix := ""
var problems := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	if args.size() > 1: prefix = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	main.autoload_save = false
	main.use_map = false   # the scripted tour drives phases directly; map shots at the end
	root.add_child(main)
	gs = root.get_node("GameState")
	run()

func frames(n: int) -> void:
	for i in n:
		await process_frame

func until_say(max_frames := 600) -> void:
	for i in max_frames:
		if main.cs_waiting == "say" or main.cs_id == "":
			break
		await process_frame
	await frames(3)

func shot(n: String) -> void:
	if main.paper: main.dialog_text.visible_characters = -1   # show the whole line (typewriter)
	await frames(12)
	var p: Array[String] = main.audit_ui()
	for x in p:
		printerr("UI AUDIT [%s]: %s" % [n, x])
	problems += p.size()
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s%s.png" % [out, prefix, n])
	print("saved ", n, " (", img.get_width(), "x", img.get_height(), ") audit problems: ", p.size())

func say_steps(k: int) -> void:
	for i in k:
		main.advance()
		await until_say()

func walk_dan_to(station: String) -> void:
	var r: Rect2 = main.loc.stations[station]["rect"]
	main.dan.position = Vector2(r.get_center().x, r.end.y + 6).clamp(main.loc.bounds.position, main.loc.bounds.end)
	await frames(3)

func run() -> void:
	await frames(5)
	gs.new_game(7)
	main.skip_all_cutscenes()
	main.queue_cutscene("wake")
	await until_say()
	await say_steps(2)
	await shot("01_wake_cutscene")
	if prefix != "":
		main.skip_all_cutscenes()
		await walk_dan_to("kitchen")
		gs.lifeos_message.emit("LifeOS: Tip: Your daughters can't be optimized. Our engineers say this is a feature. This is a long notification to check wrapping at odd window sizes.")
		await shot("02_house_morning")
		await map_shots()
		print("AUDIT TOTAL: ", problems)
		quit(0)
		return
	main.skip_all_cutscenes()
	await walk_dan_to("kitchen")
	main.perform("feed_girls")
	await shot("02_house_morning")
	await walk_dan_to("door")
	main.perform("leave_for_work")
	await until_say()
	await shot("03_school_dropoff")
	main.skip_cutscene()
	await until_say()
	await shot("04_office_gary")
	main.skip_all_cutscenes()
	gs.minutes = 990
	await walk_dan_to("desk")
	main.perform("rx_dose")
	# Terminal minigame shots
	gs.today["tickets"] = 0
	main.open_terminal("port")
	await shot("T1_terminal_new_ticket")
	main.term_submit("ping " + main.term.host, true)
	main.term_submit("ssh " + main.term.host, true)
	main.term_submit("ss -tlnp", false)
	main.term_hint()
	await shot("T2_terminal_hint")
	main.term_submit("firewall list", true)
	main.term_submit("firewall allow %d" % main.term.port, true)
	await shot("T3_terminal_solved")
	main.term_close(true)
	gs.do_action("rx_dose")
	gs.today["tickets"] = 0
	main.open_terminal("vlan")
	main.term_submit("ipconfig desk-%d" % main.term.sw_port, true)
	await shot("T4_terminal_rx_focus")
	main.term_close(false)
	var e_keep: int = gs.energy
	gs.energy = 13
	gs.today["tickets"] = 0
	main.open_terminal("dns")
	main.term_submit("nslookup " + main.term.svc, false)
	main.term_submit("ssh tc-dc01", false)
	await shot("T5_terminal_fumes")
	main.term_close(false)
	gs.energy = e_keep
	gs.today["tickets"] = 0
	main.open_terminal("service")
	main.term_submit("ping " + main.term.host, false)
	main.term_input.text = "ssh tc-"; main.term_tab(); main.term_tab()
	main.term_input.text = "sys"; main.term_tab()
	await shot("T9_terminal_tab_complete")
	main.term_input.text = ""
	main.term_close(false)
	main.open_incident("ransomware")
	main.term_submit("ssh tc-dc01", true)
	main.term_submit("aduser " + main.term.user, true)
	await shot("T6_incident_stage1")
	var g := 0
	while not main.term_done and g < 30:
		g += 1
		main.term_submit(main.term.next_step(), true)
	main.term_close(true)
	await shot("T7_postmortem")
	main.dismiss_summary()
	gs.skills["printers"] = 300
	gs.today["tickets"] = 0
	main.open_terminal("printer")
	await shot("T8_terminal_skill_max")
	main.term_close(false)
	main.use_terminal = false
	gs.today["tickets"] = 0
	main.perform("work_ticket")
	main.use_terminal = true
	await shot("05_office_desk")
	await walk_dan_to("exit")
	main.perform("head_home")
	await until_say()
	await shot("06_drive_stop_cutscene")
	main.skip_all_cutscenes()
	await walk_dan_to("beer")
	await shot("07_gas_station")
	main.perform("buy_beer")
	await walk_dan_to("car")
	main.perform("pickup_girls")
	await until_say()
	await shot("08_school_pickup")
	main.skip_cutscene()
	await until_say()
	await shot("09_jess_home")
	main.skip_all_cutscenes()
	await walk_dan_to("girls")
	await shot("10_house_evening")
	gs.minutes = 1170
	main.perform("bedtime_story")
	await until_say()
	await shot("11_bedtime")
	main.skip_all_cutscenes()
	await walk_dan_to("bed")
	main.perform("sleep")
	await until_say()
	await shot("12_day_end")
	main.skip_all_cutscenes()
	await shot("13_day_summary")
	main.dismiss_summary()
	main.skip_all_cutscenes()
	# Pass 2 features: choice, chaos, weekend, fridge gallery
	main.queue_cutscene("chaos", {"n": 0})
	for i in 6:
		await until_say()
		if main.cs_waiting == "choice": break
		main.advance()
	for i in 200:
		if main.cs_waiting == "choice": break
		await process_frame
	await shot("15_chaos_choice")
	main.skip_all_cutscenes()
	for i in 4:
		gs.end_day()
		main.skip_all_cutscenes()
		main.summary_root.visible = false
	gs.fridge_drawings = 9
	main.sync_location()
	await walk_dan_to("couch")
	await shot("16_weekend_house")
	for i in 2:
		gs.do_action("sleep") if gs.phase == "home_pm" else gs.end_day()
		main.skip_all_cutscenes()
		if main.summary_root.visible and not main.summary_is_week:
			main.summary_root.visible = false
	main.skip_all_cutscenes()
	await shot("14_weekly_review")
	await map_shots()
	print("AUDIT TOTAL: ", problems)
	quit(0)

func map_shots() -> void:
	main.use_map = true
	main.summary_root.visible = false
	gs.new_game(17)
	main.skip_all_cutscenes(); main.sync_location()
	main.perform("leave_for_work")
	await shot("M1_town_map_morning")
	main.map_pick("office"); main.skip_all_cutscenes()
	gs.today["tickets"] = 2
	gs.minutes = 840
	main.perform_direct("head_home"); main.skip_all_cutscenes(); main.auto_map()
	await shot("M2_town_map_after_work")
	gs.minutes = gs.PICKUP_OPEN + 30
	main.map_pick("school")
	await shot("M3_town_map_with_girls")
	main.close_map()
	main.use_map = false
	# pass 2: real commands + incident SLA feedback
	main.summary_root.visible = false
	gs.today["tickets"] = 0
	gs.phase = "work"; gs.minutes = 600; gs.energy = 80
	main.open_terminal("cert")
	main.term_submit("uptime", false)
	main.term_submit("curl -I https://" + main.term.host, false)
	main.term_submit("dig tc-web01", false)
	main.term_input.text = "sudo cert"; main.term_tab()
	await shot("P1_real_commands")
	main.term_input.text = ""
	main.term_close(false)
