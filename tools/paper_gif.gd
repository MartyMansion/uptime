extends SceneTree
## Renders a short gameplay clip (PNG frames) of the paper port: walk + flip in the house,
## a line with mouth flaps, the office with Gary, the town board.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/paper_gif.gd -- <framedir>
var main: Node
var gs: Node
var out := "/tmp/gif"
var n := 0
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	main.autoload_save = false
	main.use_map = false
	root.add_child(main)
	gs = root.get_node("GameState")
	run()
func grab(k := 1) -> void:
	for i in k:
		var d := 1.0 / 15.0
		if main.dan._tween and main.dan._tween.is_valid(): main.dan._tween.custom_step(d)
		if main.cs_mover and is_instance_valid(main.cs_mover) and main.cs_mover._tween and main.cs_mover._tween.is_valid(): main.cs_mover._tween.custom_step(d)
		main._process(d)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/%04d.png" % [out, n]); n += 1
func walk(to: Vector2, frames: int) -> void:
	main.dan.walk_to(to)
	await grab(frames)
	main.dan.stop_walking()
func say(who: String, t: String, frames: int) -> void:
	main.cs_id = "gif"
	main._run_step(["say", who, t], false)
	await grab(frames)
	main.advance(); main.cs_id = ""
func run() -> void:
	for i in 5: await process_frame
	gs.new_game(11)
	gs.fridge_drawings = 8; gs.plant = 4
	main.skip_all_cutscenes()
	gs.minutes = 430
	main.sync_location()
	main._update_fridge()
	main.dan.position = Vector2(60, 150)
	for i in 30: main._process(1.0 / 15.0)
	await walk(Vector2(150, 150), 18)
	await walk(Vector2(120, 140), 8)
	await walk(Vector2(176, 132), 12)
	main.loc.spawn("jess", Vector2(206, 132))
	await grab(4)
	await say("jess", "You said that Tuesday. Eat a pancake. A real one.", 34)
	await say("dan", "The server's fine, honey. I'm the one who needs a reboot.", 36)
	gs.phase = "work"; gs.minutes = 540
	main.sync_location()
	main.dan.position = Vector2(110, 110)
	for i in 30: main._process(1.0 / 15.0)
	main.loc.spawn("gary", Vector2(170, 110))
	await walk(Vector2(140, 110), 10)
	await say("gary", "Dan! Buddy! Quick one... is 'the cloud' down, or is that just weather?", 40)
	await walk(Vector2(250, 104), 22)
	gs.phase = "drive"; gs.at_place = "gas"; gs.minutes = 900
	main.sync_location()
	main.use_map = true
	main.open_map()
	await grab(20)
	quit(0)
