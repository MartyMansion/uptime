extends Node2D
## Game shell: loads a Location for the current phase, runs Dan, the HUD,
## LifeOS popups, scripted cutscenes, and the day/week summaries.
## All UI lives in containers under a 1280x720 base (stretch: canvas_items/keep).

const SPEED := 70.0                     # world px / sec
const WORLD_SIZE := Vector2(320, 200)
const LOCATIONS := {
	"house": "res://scenes/locations/house.tscn",
	"office": "res://scenes/locations/office.tscn",
	"gas_station": "res://scenes/locations/gas_station.tscn",
	"school": "res://scenes/locations/school.tscn",
}
const PHASE_LOC := {"home_am": "house", "work": "office", "drive": "gas_station", "home_pm": "house", "weekend": "house"}
const GLOBAL_KEYS := ["text_jess", "pouch", "rx_dose", "breathe"]
const SPEAKERS := {"dan": "Dan", "jess": "Jess", "lily": "Lily", "june": "June", "gary": "Gary", "lifeos": "LifeOS"}
const FONT := 15

var world: Node2D
var loc: Location
var loc_name := ""
var dan: Actor
var near_station := ""

# UI
var ui: Control
var world_slot: Control
var hud_day: Label
var hud_phase: Label
var hud_clock: Label
var hud_status: Label
var energy_bar: ProgressBar
var meters := {}
var log_label: Label
var prompt: Label
var lifeos_panel: PanelContainer
var lifeos_label: Label
var lifeos_timer := 0.0
var dialog_panel: PanelContainer
var dialog_portrait: TextureRect
var dialog_name: Label
var dialog_text: Label
var dialog_hint: Label
var summary_root: Control
var summary_title: Label
var summary_label: Label
var summary_hint: Label
var dimmer: ColorRect

# Cutscenes
var cs_queue: Array = []        # [[id, ctx], ...]
var cs_steps: Array = []
var cs_id := ""
var cs_waiting := ""            # "", "say", "move", "wait"
var cs_wait_t := 0.0
var cs_mover: Actor
var pending_summary := ""
var pending_title := ""
var summary_is_week := false
var did_jess_home := false
var autoload_save := true    # tests turn this off
var cs_choices: Array = []          # [[label, effect], ...] while a choice is open
var random_choices := false         # bot: pick choices at random when skipping
var choice_rng := RandomNumberGenerator.new()

func _on_day_started() -> void:
	GameState.save_game()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	_build_ui()
	GameState.state_changed.connect(_refresh)
	GameState.lifeos_message.connect(show_lifeos)
	GameState.day_ended.connect(_on_day_ended)
	GameState.week_ended.connect(_on_week_ended)
	GameState.action_performed.connect(_on_action)
	GameState.day_started.connect(_on_day_started)
	GameState.moment.connect(func(k): queue_cutscene("moment", {"id": k}))
	if autoload_save and GameState.has_save():
		GameState.load_game()
	get_viewport().size_changed.connect(_layout_world)
	sync_location()
	_refresh()
	queue_cutscene("wake")
	_layout_world.call_deferred()

# ------------------------------------------------------------------ UI build
func _theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.1, 0.14, 0.94)
	panel.border_color = Color(0.35, 0.38, 0.5)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(10)
	t.set_stylebox("panel", "PanelContainer", panel)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.26)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.4, 0.75, 0.5)
	fill.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_font_size("font_size", "ProgressBar", 12)
	t.set_color("font_color", "Label", Color(0.93, 0.93, 0.96))
	return t

func _label(text := "", size := FONT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(0, 16)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f := StyleBoxFlat.new()
	f.bg_color = color
	f.set_corner_radius_all(3)
	b.add_theme_stylebox_override("fill", f)
	return b

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.name = "UI"
	ui.theme = _theme()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var root := VBoxContainer.new()
	root.name = "HUD"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	# top bar
	var top := PanelContainer.new()
	top.custom_minimum_size = Vector2(0, 48)
	root.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 18)
	top.add_child(th)
	hud_day = _label("", 20)
	th.add_child(hud_day)
	hud_clock = _label("", 20)
	th.add_child(hud_clock)
	hud_phase = _label("", FONT)
	hud_phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_phase.clip_text = true
	hud_phase.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	th.add_child(hud_phase)
	th.add_child(_label("Energy", FONT))
	energy_bar = _bar(Color(0.95, 0.8, 0.3))
	energy_bar.custom_minimum_size = Vector2(180, 18)
	energy_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(energy_bar)
	# middle: world slot + sidebar
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mid)
	world_slot = Control.new()
	world_slot.name = "WorldSlot"
	world_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_slot.resized.connect(_layout_world)
	mid.add_child(world_slot)
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	mid.add_child(side)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	side.add_child(sv)
	hud_status = _label("", 13, true)
	sv.add_child(hud_status)
	var colors := {"Stress": Color(0.9, 0.4, 0.35), "Job Performance": Color(0.4, 0.6, 0.95), "Jess: Closeness": Color(0.4, 0.8, 0.8),
		"Girls: Fed": Color(0.95, 0.65, 0.3), "Girls: Connected": Color(0.85, 0.5, 0.8)}
	for key in colors:
		sv.add_child(_label(key, 13))
		var b := _bar(colors[key])
		sv.add_child(b)
		meters[key] = b
	sv.add_child(HSeparator.new())
	sv.add_child(_label("WASD / Arrows  move    1-4  action\nT text Jess   B breathe\nP nic pouch   R Rx dose\nEnter continue   Esc skip\nF6 save   F7 load (autosaves daily)", 13))
	sv.add_child(HSeparator.new())
	log_label = _label("", 13, true)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.clip_text = true
	log_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	log_label.max_lines_visible = 9
	sv.add_child(log_label)
	# bottom prompt
	var bottom := PanelContainer.new()
	bottom.custom_minimum_size = Vector2(0, 72)
	root.add_child(bottom)
	prompt = _label("", FONT, true)
	prompt.max_lines_visible = 3
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(prompt)
	# dimmer (night) covers only the world slot
	dimmer = ColorRect.new()
	dimmer.color = Color(0.02, 0.02, 0.1, 0.0)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_slot.add_child(dimmer)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	# LifeOS toast: top-right of the world slot
	lifeos_panel = PanelContainer.new()
	lifeos_panel.name = "LifeOS"
	world_slot.add_child(lifeos_panel)
	lifeos_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lifeos_panel.offset_left = -440
	lifeos_panel.offset_right = -10
	lifeos_panel.offset_top = 10
	lifeos_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 10)
	lifeos_panel.add_child(lh)
	var lp := TextureRect.new()
	lp.texture = load("res://assets/portraits/lifeos.png")
	lp.custom_minimum_size = Vector2(48, 48)
	lp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	lh.add_child(lp)
	lifeos_label = _label("", 14, true)
	lifeos_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(lifeos_label)
	lifeos_panel.visible = false
	# Dialogue box: bottom of world slot
	dialog_panel = PanelContainer.new()
	dialog_panel.name = "Dialogue"
	world_slot.add_child(dialog_panel)
	dialog_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dialog_panel.offset_left = 16
	dialog_panel.offset_right = -16
	dialog_panel.offset_bottom = -12
	dialog_panel.offset_top = -150
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 14)
	dialog_panel.add_child(dh)
	dialog_portrait = TextureRect.new()
	dialog_portrait.custom_minimum_size = Vector2(96, 96)
	dialog_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialog_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dh.add_child(dialog_portrait)
	var dv := VBoxContainer.new()
	dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(dv)
	dialog_name = _label("", 18)
	dialog_name.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	dv.add_child(dialog_name)
	dialog_text = _label("", 17, true)
	dialog_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(dialog_text)
	var hint := _label("Enter: next    Esc: skip", 12)
	hint.name = "Hint"
	dialog_hint = hint
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.modulate = Color(1, 1, 1, 0.6)
	dv.add_child(hint)
	dialog_panel.visible = false
	# Summary: centered modal over everything
	summary_root = ColorRect.new()
	summary_root.name = "Summary"
	(summary_root as ColorRect).color = Color(0, 0, 0, 0.55)
	summary_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(summary_root)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	summary_root.add_child(cc)
	var sp := PanelContainer.new()
	sp.custom_minimum_size = Vector2(760, 0)
	cc.add_child(sp)
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 12)
	sp.add_child(svb)
	summary_title = _label("", 22)
	summary_title.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	svb.add_child(summary_title)
	summary_label = _label("", 16, true)
	summary_label.custom_minimum_size = Vector2(720, 0)
	svb.add_child(summary_label)
	summary_hint = _label("", 14)
	summary_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	svb.add_child(summary_hint)
	summary_root.visible = false

func _layout_world() -> void:
	if world_slot == null:
		return
	var r := world_slot.get_global_rect()
	if r.size.x <= 0:
		return
	var sc := minf(r.size.x / WORLD_SIZE.x, r.size.y / WORLD_SIZE.y)
	world.scale = Vector2(sc, sc)
	world.position = r.position + (r.size - WORLD_SIZE * sc) / 2.0

# ------------------------------------------------------------------ locations
func load_location(n: String) -> void:
	if loc_name == n and loc != null:
		return
	if loc != null:
		world.remove_child(loc)
		loc.queue_free()
	loc = load(LOCATIONS[n]).instantiate()
	world.add_child(loc)
	loc_name = n
	dan = loc.spawn("dan", loc.spot("entry"))
	near_station = ""
	if hud_phase:
		_refresh()

## Puts the world in the right place for the current phase, with default NPCs.
func sync_location() -> void:
	var want: String = PHASE_LOC[GameState.phase]
	load_location(want)
	var npcs := {}
	match GameState.phase:
		"home_am":
			npcs = {"lily": "table_l", "june": "table_r"}
		"home_pm", "weekend":
			npcs = {"lily": "girls", "june": "girls_dan", "jess": "couch_l"}
		"work":
			npcs = {"gary": "gary_desk"}
	for n in ["jess", "lily", "june", "gary"]:
		if npcs.has(n):
			if not loc.actors.has(n):
				loc.spawn(n, loc.spot(npcs[n]))
			loc.actors[n].visible = true
		else:
			loc.despawn(n)
	dan.visible = true
	_update_fridge()
	_refresh_prompt()

## Cozy loop made visible: one little drawing per fridge_drawings on the house fridge.
func _update_fridge() -> void:
	if loc_name != "house":
		return
	var g: Node2D = loc.get_node_or_null("FridgeGallery")
	if g == null:
		g = Node2D.new()
		g.name = "FridgeGallery"
		g.z_index = 30
		g.draw.connect(func():
			var cols := [Color(0.95, 0.5, 0.5), Color(0.5, 0.75, 0.95), Color(0.95, 0.85, 0.4), Color(0.6, 0.9, 0.6), Color(0.85, 0.6, 0.95)]
			for i in mini(GameState.fridge_drawings, 12):
				var p := Vector2(198 + (i % 4) * 4, 22 + (i / 4) * 5)
				g.draw_rect(Rect2(p, Vector2(3, 4)), cols[i % cols.size()]))
		loc.add_child(g)
	g.queue_redraw()
	var pl: Node2D = null
	for c in loc.get_children():
		if c is Sprite2D and str(c.name).begins_with("Plant") and c.position.x > 280:
			pl = c
	if pl:
		var sc := 0.7 + 0.08 * mini(GameState.plant, 6)
		pl.scale = Vector2(sc, sc)
		pl.modulate = Color(1, 0.85, 0.85) if GameState.plant >= 6 else Color.WHITE

# ------------------------------------------------------------------ loop
func is_busy() -> bool:
	return cs_id != "" or summary_root.visible

func _process(delta: float) -> void:
	if lifeos_panel.visible and not dialog_panel.visible:
		lifeos_timer -= delta
		if lifeos_timer <= 0:
			lifeos_panel.visible = false
	_cs_tick(delta)
	if is_busy() or loc == null:
		return
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	dan.walk(dir)
	if dir != Vector2.ZERO:
		var b := loc.bounds
		var step := dir.normalized() * SPEED * delta
		var stuck := loc.blocked(dan.position)   # never trap Dan if a cutscene left him inside furniture
		for cand in [dan.position + step, dan.position + Vector2(step.x, 0), dan.position + Vector2(0, step.y)]:
			var np: Vector2 = cand.clamp(b.position, b.end)
			if stuck or not loc.blocked(np):
				dan.position = np
				break
	var s := loc.station_at(dan.position)
	if s != near_station:
		near_station = s
		loc.set_highlight(s)
		_refresh_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: Key = (event as InputEventKey).keycode
	var confirm := k == KEY_ENTER or k == KEY_SPACE or k == KEY_KP_ENTER
	if cs_id != "" and cs_waiting == "choice":
		if k >= KEY_1 and k < KEY_1 + cs_choices.size():
			pick_choice(k - KEY_1)
		return
	if cs_id != "":
		if k == KEY_ESCAPE:
			skip_cutscene()
		elif confirm:
			advance()
		return
	if summary_root.visible:
		if confirm:
			dismiss_summary()
		return
	if confirm and lifeos_panel.visible:
		lifeos_panel.visible = false
		return
	match k:
		KEY_T:
			var why: String = GameState.can_do("text_jess")
			if why == "":
				queue_cutscene("phone")
			else:
				_log(why)
		KEY_P: perform("pouch")
		KEY_R: perform("rx_dose")
		KEY_B: perform("breathe")
		KEY_F6:
			show_lifeos("LifeOS: Saved. Your progress is safe. Your inbox is not." if GameState.save_game() else "LifeOS: Save failed. Classic.")
		KEY_F7:
			if GameState.load_game():
				cs_queue.clear(); cs_id = ""; summary_root.visible = false
				loc_name = ""; sync_location(); queue_cutscene("wake")
				show_lifeos("LifeOS: Loaded the morning of %s. Déjà vu is a feature." % GameState.day_name())
			else:
				show_lifeos("LifeOS: No save found. Living in the moment, then.")
		KEY_1, KEY_2, KEY_3, KEY_4:
			var acts := _current_actions()
			var idx: int = k - KEY_1
			if idx < acts.size():
				perform(acts[idx])

func _current_actions() -> Array[String]:
	var out: Array[String] = []
	if near_station == "" or loc == null:
		return out
	for aid in loc.stations[near_station]["actions"]:
		if GameState.phase in GameState.ACTIONS[aid]["phases"]:
			out.append(aid)
	return out

func perform(aid: String) -> void:
	var res: String = GameState.do_action(aid)
	_log(res)
	_refresh_prompt()

func _log(t: String) -> void:
	log_label.text = t

func _on_action(id: String, _res: String) -> void:
	if GameState.pending_choice != "":
		queue_cutscene(GameState.pending_choice)
		GameState.pending_choice = ""
	match id:
		"leave_for_work":
			queue_cutscene("dropoff")
			queue_cutscene("arrive_work")
		"head_home":
			queue_cutscene("drive_stop")
		"pickup_girls":
			queue_cutscene("pickup", {"bought": GameState.today.get("buy_beer", 0) + GameState.today.get("buy_pouches", 0) > 0})
			queue_cutscene("jess_home")
			if GameState.rng.randf() < 0.3:
				queue_cutscene("chaos", {"n": GameState.rng.randi()})
		"bedtime_story":
			queue_cutscene("bedtime")

func _on_day_ended(s: Dictionary) -> void:
	queue_cutscene("day_end", s)
	pending_title = "END OF %s" % str(s["day"]).to_upper()
	pending_summary = "Moment of the day: %s\n\nBedtime: %s\n%s\nTickets closed: %d\nThoughtful texts to Jess: %d\nBedtime story: %s\nKid moments: %d (Lily %s, June %s)\nFridge drawings: %d\nEnergy: %d -> %d" % [
		s.get("moment", ""), s["bed_time"], s["sleep_text"], s["tickets"], s["texts"],
		"Attended" if s["bedtime"] else "Missed (Mommy did the voices; the girls said goodnight to you)", s["kid_actions"], "✓" if s.get("lily", false) else "-", "✓" if s.get("june", false) else "-", s.get("drawings", 0), s["energy_before"], s["energy_after"]]
	summary_is_week = false

func _on_week_ended(review: String) -> void:
	queue_cutscene("review")
	pending_title = "LIFEOS QUARTERLY-WEEKLY PERFORMANCE REVIEW"
	pending_summary = review.substr(review.find("\n") + 1)
	summary_is_week = true

func show_summary() -> void:
	summary_title.text = pending_title
	summary_label.text = pending_summary
	summary_hint.text = "[Enter] Play the week again" if summary_is_week else "[Enter] Next day"
	summary_root.visible = true
	pending_summary = ""

func dismiss_summary() -> void:
	summary_root.visible = false
	if summary_is_week:
		summary_is_week = false
		GameState.new_game()
	queue_cutscene("wake")

func show_lifeos(text: String) -> void:
	lifeos_label.text = text
	lifeos_panel.visible = true
	lifeos_timer = 6.0

# ------------------------------------------------------------------ cutscenes
func queue_cutscene(id: String, ctx: Dictionary = {}) -> void:
	cs_queue.append([id, ctx])
	if cs_id == "":
		_next_cutscene()

func _next_cutscene() -> void:
	if cs_queue.is_empty():
		cs_id = ""
		dialog_panel.visible = false
		if pending_summary != "":
			show_summary()
		else:
			dimmer.color.a = 0.0
			sync_location()
		return
	var item: Array = cs_queue.pop_front()
	cs_id = item[0]
	cs_steps = Cutscenes.build(cs_id, GameState, item[1])
	cs_waiting = ""
	if loc:
		loc.set_highlight("")
		dan.stop_walking()

func _actor(who: String) -> Actor:
	if loc.actors.has(who):
		return loc.actors[who]
	return loc.spawn(who, loc.spot("entry"))

func _pos(p) -> Vector2:
	return p if p is Vector2 else loc.spot(str(p))

## Runs steps until one needs to wait.
func _cs_tick(delta: float) -> void:
	if cs_id == "":
		return
	match cs_waiting:
		"say", "choice":
			return
		"move":
			if cs_mover and is_instance_valid(cs_mover) and cs_mover._tween and cs_mover._tween.is_running():
				return
		"wait":
			cs_wait_t -= delta
			if cs_wait_t > 0:
				return
	cs_waiting = ""
	while cs_waiting == "" and not cs_steps.is_empty():
		_run_step(cs_steps.pop_front(), false)
	if cs_waiting == "" and cs_steps.is_empty():
		_next_cutscene()

func _run_step(st: Array, instant: bool) -> void:
	match st[0]:
		"loc":
			load_location(st[1])
			dialog_panel.visible = false
		"place":
			var a := _actor(st[1])
			a.stop_walking()
			a.position = _pos(st[2])
			a.visible = true
		"face":
			_actor(st[1]).face(st[2])
		"move":
			var a := _actor(st[1])
			if instant:
				a.stop_walking()
				a.position = _pos(st[2])
			else:
				cs_mover = a
				a.walk_to(_pos(st[2]))
				cs_waiting = "move"
		"hide":
			if loc.actors.has(st[1]):
				loc.despawn(st[1])
		"choice":
			var opts: Array = st[1]
			if instant:
				var pick: int = choice_rng.randi() % opts.size() if random_choices else 0
				_log(GameState.apply_choice(opts[pick][1]))
			else:
				cs_choices = opts
				dialog_name.text = "Your call"
				var t := ""
				for i in opts.size():
					t += "[%d] %s\n" % [i + 1, opts[i][0]]
				dialog_text.text = t.strip_edges()
				dialog_portrait.texture = load("res://assets/portraits/dan.png")
				dialog_portrait.visible = true
				dialog_panel.visible = true
				lifeos_panel.visible = false
				cs_waiting = "choice"
				dialog_hint.text = "1-%d: choose    Esc: kindest option" % opts.size()
		"say", "lifeos":
			var who: String = "lifeos" if st[0] == "lifeos" else st[1]
			var text: String = st[1] if st[0] == "lifeos" else st[2]
			dialog_name.text = SPEAKERS.get(who, who)
			dialog_text.text = text
			var p := "res://assets/portraits/%s.png" % who
			dialog_portrait.texture = load(p) if ResourceLoader.exists(p) else (load("res://assets/portraits/lifeos.png") if who != "" else null)
			dialog_portrait.visible = who != ""
			dialog_panel.visible = true
			dialog_hint.text = "Enter: next    Esc: skip"
			lifeos_panel.visible = false
			if not instant:
				cs_waiting = "say"
		"dim":
			var target := 0.6 if st[1] else 0.0
			if instant:
				dimmer.color.a = target
			else:
				create_tween().tween_property(dimmer, "color:a", target, 0.6)
		"wait":
			if not instant:
				cs_wait_t = st[1]
				cs_waiting = "wait"

func pick_choice(i: int) -> void:
	if cs_waiting != "choice" or i < 0 or i >= cs_choices.size():
		return
	_log(GameState.apply_choice(cs_choices[i][1]))
	cs_choices = []
	cs_waiting = ""
	dialog_panel.visible = false

func advance() -> void:
	if cs_waiting == "say":
		cs_waiting = ""
		dialog_panel.visible = false

## Esc: finish the current cutscene instantly (positions/state still applied).
func skip_cutscene() -> void:
	if cs_id == "":
		return
	if cs_mover and is_instance_valid(cs_mover):
		cs_mover.stop_walking()
	while not cs_steps.is_empty():
		_run_step(cs_steps.pop_front(), true)
	if cs_waiting == "choice":   # Esc on an open choice: take the first (kindest) option
		pick_choice(0)
	cs_waiting = ""
	dialog_panel.visible = false
	_next_cutscene()

## Test helper: skip every queued cutscene.
func skip_all_cutscenes() -> void:
	var guard := 0
	while cs_id != "" and guard < 1000:
		skip_cutscene()
		guard += 1

# ------------------------------------------------------------------ HUD refresh
func _refresh_prompt() -> void:
	if loc == null or prompt == null:
		return
	if near_station == "":
		var names: Array[String] = []
		for id in loc.stations:
			names.append(loc.stations[id]["label"])
		prompt.text = ("%s. Walk to: %s. (T, P, R work anywhere.)" % [loc.title, ", ".join(names)]) if not names.is_empty() else loc.title + "."
		return
	var parts: Array[String] = []
	var i := 1
	for aid in _current_actions():
		var a: Dictionary = GameState.ACTIONS[aid]
		var cost := "%d min, %+d energy" % [int(a["blocks"]) * GameState.BLOCK, int(a["energy"])]
		if aid == "sleep":
			cost = "ends the day"
		var blocked := GameState.can_do(aid)
		parts.append("[%d] %s (%s)%s" % [i, a["name"], cost, " - " + blocked if blocked != "" else ""])
		i += 1
	if parts.is_empty():
		prompt.text = "%s: nothing to do here right now." % loc.stations[near_station]["label"]
	else:
		prompt.text = loc.stations[near_station]["label"] + ":   " + "     ".join(parts)

func _refresh() -> void:
	hud_day.text = "%s  (Day %d/7)" % [GameState.day_name(), GameState.day + 1]
	hud_clock.text = GameState.clock_text()
	hud_phase.text = GameState.phase_name() if loc == null or loc_name == PHASE_LOC[GameState.phase] else loc.title
	var flags: Array[String] = []
	if GameState.is_on_fumes(): flags.append("RUNNING ON FUMES")
	if GameState.rx_active(): flags.append("focused")
	hud_status.text = "%s\n$%d   Beer: %d   Tin: %d   Drawings: %d%s" % [GameState.calendar_text(), GameState.money, GameState.beers, GameState.pouches, GameState.fridge_drawings,
		("\n" + ", ".join(flags)) if not flags.is_empty() else ""]
	energy_bar.value = GameState.energy
	meters["Stress"].value = GameState.stress
	meters["Job Performance"].value = GameState.performance
	meters["Jess: Closeness"].value = GameState.closeness
	meters["Girls: Fed"].value = GameState.girls_fed
	meters["Girls: Connected"].value = GameState.girls_connected
	_refresh_prompt()

# ------------------------------------------------------------------ UI audit
## Returns problems: visible labels outside the viewport, or overlapping
## each other (HUD labels only; modal/overlay panels checked for bounds).
func audit_ui() -> Array[String]:
	var problems: Array[String] = []
	var vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1)
	var labels: Array[Label] = []
	_collect_labels(ui, labels)
	for l in labels:
		var r := l.get_global_rect()
		if not vp.encloses(r):
			problems.append("out of bounds: '%s' %s" % [l.text.left(30), r])
		if not l.clip_text and l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.get_minimum_size().x > l.size.x + 1:
			problems.append("clipped: '%s'" % l.text.left(30))
	for i in labels.size():
		for j in range(i + 1, labels.size()):
			var a := labels[i]
			var b := labels[j]
			if _overlay_of(a) != _overlay_of(b):
				continue
			if a.get_global_rect().grow(-1).intersects(b.get_global_rect().grow(-1)):
				problems.append("overlap: '%s' / '%s'" % [a.text.left(25), b.text.left(25)])
	return problems

func _overlay_of(n: Node) -> String:
	while n != null and n != ui:
		if n.name in ["LifeOS", "Dialogue", "Summary"]:
			return n.name
		n = n.get_parent()
	return "HUD"

func _collect_labels(n: Node, out: Array[Label]) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Label and (n as Label).text != "":
		out.append(n)
	for c in n.get_children():
		_collect_labels(c, out)
