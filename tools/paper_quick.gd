extends SceneTree
## Quick look at every paper set (dev tool):
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/paper_quick.gd -- <outdir>
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
	print("saved ", n, " leaks=", main.diorama.edge_leaks(main.paper_view.size.x / maxf(1.0, main.paper_view.size.y)))
func run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/pq"
	DirAccess.make_dir_recursive_absolute(out)
	await frames(5)
	gs.new_game(7)
	gs.fridge_drawings = 7; gs.plant = 6
	main.skip_all_cutscenes()
	main.sync_location()
	main.dan.position = Vector2(150, 70)
	await shot(out, "house_kitchen")
	main.dan.position = Vector2(150, 186)
	await shot(out, "house_front")
	for ph in [["work", "office", Vector2(56, 100)], ["drive", "gas", Vector2(124, 150)]]:
		gs.phase = ph[0]; gs.at_place = ph[1]
		main.sync_location()
		main.dan.position = ph[2]
		await shot(out, ph[0])
	main.load_location("school")
	await shot(out, "school")
	gs.phase = "drive"
	main.load_location("gas_station")
	for p in ["park", "diner", "coffee"]:
		gs.at_place = p
		await shot(out, "place_" + p)
	quit(0)
