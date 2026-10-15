extends SceneTree
## Desktop + garage screenshots (dev tool):
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/farm_shots.gd -- <outdir>
var main: Node
var gs: Node
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.autoload_save = false
	main.use_map = false
	root.add_child(main)
	gs = root.get_node("GameState")
	run()
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(out: String, n: String) -> void:
	await frames(40)
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
	print("saved ", n, " audit=", main.audit_ui())
func run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/fs"
	DirAccess.make_dir_recursive_absolute(out)
	await frames(5)
	gs.new_game(7)
	main.skip_all_cutscenes()
	gs.phase = "home_pm"; gs.minutes = 1100; gs.money = 400
	main.sync_location()
	main.lifeos_panel.visible = false
	main.dan.position = Vector2(30, 176)
	await shot(out, "house_garage_door")
	main.perform("pc")
	await shot(out, "desktop")
	main.desk_app("pceggo")
	await shot(out, "desktop_pceggo")
	main.cart_add("server"); main.cart_add("rack"); main.cart_add("switch")
	main.desk_app("cart")
	await shot(out, "desktop_cart")
	main.cart_checkout()
	main.close_desktop()
	gs.end_day(); main.skip_all_cutscenes(); main.summary_root.visible = false; main.pending_summary = ""
	gs.phase = "home_pm"; gs.minutes = 1100
	main.lifeos_panel.visible = false
	main.in_garage = true; main.sync_location()
	main.dan.position = Vector2(110, 160)
	await shot(out, "garage_boxes")
	main.perform("build_farm")
	main.assembly_step(1)
	await shot(out, "garage_assembly")
	main.assembly_auto()
	while not gs.boxes.is_empty():
		main.perform("build_farm"); main.assembly_auto()
	gs.farm["server"] = 3; gs.farm["ups"] = 1; gs.farm["fans"] = 1; gs.farm["foam"] = 1; gs.farm["electrician"] = 1
	main.diorama.refresh_farm(gs)
	main.dan.position = Vector2(120, 110)
	main.lifeos_panel.visible = false
	await shot(out, "garage_farm")
	main.perform("farm_check")
	await shot(out, "desktop_farmstat")
	quit(0)
