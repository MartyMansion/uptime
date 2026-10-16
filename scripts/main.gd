extends Node2D
## Game shell: loads a Location for the current phase, runs Dan, the HUD,
## LifeOS popups, scripted cutscenes, and the day/week summaries.
## All UI lives in containers under a 1280x720 base (stretch: canvas_items/keep).
## Presentation: the 2D Location is logic only (hidden); a paper Diorama (3D, SubViewport) mirrors it.

const SPEED := 70.0                     # world px / sec
const WORLD_SIZE := Vector2(320, 200)
const LOCATIONS := {
	"house": "res://scenes/locations/house.tscn",
	"office": "res://scenes/locations/office.tscn",
	"gas_station": "res://scenes/locations/gas_station.tscn",
	"school": "res://scenes/locations/school.tscn",
	"road": "res://scenes/locations/road.tscn",
	"garage": "res://scenes/locations/garage.tscn",
}
const PHASE_LOC := {"home_am": "house", "work": "office", "drive": "road", "home_pm": "house", "weekend": "house"}
const GLOBAL_KEYS := ["text_jess", "pouch", "rx_dose", "breathe"]
const SPEAKERS := {"dan": "Dan", "jess": "Jess", "lily": "Lily", "june": "June", "gary": "Gary", "lifeos": "LifeOS"}
const FONT := 15

var world: Node2D
var paper := true                # paper-diorama presentation (the 2D plan stays as the logic layer)
var diorama: Diorama
var paper_view: SubViewportContainer
var _paper_key := ""
var talk_who := ""               # who is speaking (mouth flaps follow the typewriter)
var talk_flap := 0.0
var _type_t := 0.0
const TYPE_CPS := 48.0
var skip_seen := false            # F4: dialogue you've seen before (any playthrough) shows instantly
var cs_fast := false
var seen_scenes := {}
var type_cps := TYPE_CPS          # F3: 48 / 96 / instant (a11y)
const INK := Color(0.13, 0.1, 0.1)
const PAPER := Color(0.99, 0.96, 0.87)
const KRAFT := Color(0.8, 0.64, 0.44)
var loc: Location
var in_garage := false           # home phases: Dan walked through the garage door
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
# Terminal minigame (Work a ticket)
var use_terminal := true
var term: TicketSim
var term_panel: PanelContainer
var term_header: Label
var term_out: Label
var term_prompt: Label
var term_input: LineEdit
var term_suggest: HFlowContainer
var term_status: Label
var term_hint_btn: Button
var term_show_btn: Button
var term_done := false
var term_xp_bar: ProgressBar
var term_xp_label: Label
var term_ap_btn: Button
# incident state
var inc_id := ""
var inc_idx := 0
var inc_used := 0
var inc_breached := false
var inc_after_hours := false
var inc_cmds := 0
var inc_hints := 0
const INC_BUDGET := 90   # legacy default; real SLA is computed per incident (pass 2)
const INC_SLACK := 14     # minutes of slack on top of the fastest path
const INC_HINT_MIN := 6   # reading the runbook costs time during an incident
var inc_budget := 90
var inc_optimal := 0
var inc_slack := INC_SLACK
const INC_CMD_MIN := 4
const SLACK_BY_LEVEL := [[22, 38], [22, 38], [16, 32], [10, 24], [8, 20], [6, 16]]   # index = avg skill level
const CURVEBALL_P := 0.2
const CURVEBALLS := [["Gary walks over to ask for an ETA. Then asks again.", 5], ["The vendor puts you on hold. The hold music is a ukulele.", 8],
	["Karen forwards the suspicious email to 'all staff' to ask if it's suspicious.", 4], ["Your laptop picks now to install updates.", 6], ["The CEO joins the bridge call to 'listen in'.", 5]]
var inc_curve := 0

## Average skill level across an incident's stages (rounded).
func incident_level(id: String) -> int:
	var lv := 0.0
	var st: Array = TicketSim.INCIDENTS[id]["stages"]
	for k in st: lv += GameState.skill_level(GameState.skill_of(k))
	return clampi(roundi(lv / maxf(1.0, st.size())), 1, 5)

## Reading the runbook is cheap for a new Dan (he's expected to), pricier for an expert.
static func hint_cost(level: int) -> int:
	return 2 if level <= 2 else (4 if level == 3 else INC_HINT_MIN)

static func incident_slack(level: int, rng: RandomNumberGenerator) -> int:
	var r: Array = SLACK_BY_LEVEL[clampi(level, 0, 5)]
	return rng.randi_range(r[0], r[1])
var summary_kind := ""     # "", "week", "postmortem"
var term_rng := RandomNumberGenerator.new()
var cs_choices: Array = []          # [[label, effect], ...] while a choice is open
var choice_policy: Callable          # bot personas: opts -> index
var random_choices := false         # bot: pick choices at random when skipping
var choice_rng := RandomNumberGenerator.new()

func _on_day_started() -> void:
	GameState.save_game()

func _ready() -> void:
	_load_seen()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	_build_ui()
	if paper:
		_build_paper()
	_build_desktop()
	_build_assembly()
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
func _paper_box(bg: Color, border := INK, bw := 3, shadow := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(10)
	if shadow:
		sb.shadow_color = Color(0.1, 0.06, 0.04, 0.35)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(4, 5)
	return sb

## Paper & cardboard UI: cream paper panels, ink outlines, kraft buttons, dark ink text.
func _theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT
	t.set_stylebox("panel", "PanelContainer", _paper_box(PAPER))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.86, 0.8, 0.68)
	bg.border_color = INK
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.4, 0.75, 0.5)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_font_size("font_size", "ProgressBar", 12)
	t.set_color("font_color", "ProgressBar", INK)
	t.set_color("font_color", "Label", INK)
	var bn := _paper_box(Color(0.95, 0.88, 0.7), INK, 2, false); bn.set_content_margin_all(5)
	var bh := _paper_box(Color(1, 0.8, 0.45), INK, 2, false); bh.set_content_margin_all(5)
	var bd := _paper_box(Color(0.78, 0.74, 0.68), Color(0.45, 0.4, 0.36), 2, false); bd.set_content_margin_all(5)
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bh)
	t.set_stylebox("focus", "Button", _paper_box(Color(1, 0.85, 0.3, 0.25), Color(0.85, 0.2, 0.1), 4, false))   # a11y: thick, filled focus ring
	t.set_stylebox("disabled", "Button", bd)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(k, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.38, 0.34, 0.32))
	var le := _paper_box(Color(0.05, 0.07, 0.05), Color(0.3, 0.7, 0.4), 2, false); le.set_content_margin_all(4)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", _paper_box(Color(0, 0, 0, 0), Color(0.5, 1, 0.6), 2, false))
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
	top.add_theme_stylebox_override("panel", _paper_box(KRAFT, INK, 3, false))
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
		var ml := _label(key, 13)
		if key == "Girls: Fed": fed_label = ml
		sv.add_child(ml)
		var b := _bar(colors[key])
		sv.add_child(b)
		meters[key] = b
	sv.add_child(HSeparator.new())
	sv.add_child(_label("WASD / Arrows  move    1-4  action\nT text Jess   B breathe\nP nic pouch   R Rx dose\nEnter continue   Esc skip\nF6 save   F7 load (autosaves daily)\nF2 text size   F3 text speed\nF4 seen dialogue: instant", 14))
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
	bottom.add_theme_stylebox_override("panel", _paper_box(KRAFT, INK, 3, false))
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
	lp.texture = load("res://assets/paper/lifeos.png") if paper else load("res://assets/portraits/lifeos.png")
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
	dialog_panel.offset_bottom = -10
	dialog_panel.offset_top = -138
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
	dialog_name.add_theme_color_override("font_color", Color(0.75, 0.2, 0.15))
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
	# Lives inside the game area (not over the sidebar) so it never clips the meters.
	world_slot.add_child(summary_root)
	summary_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cc := MarginContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for mside in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		cc.add_theme_constant_override(mside, 18)
	summary_root.add_child(cc)
	var sp := PanelContainer.new()
	sp.custom_minimum_size = Vector2(0, 0)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cc.add_child(sp)
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 12)
	sp.add_child(svb)
	summary_title = _label("", 22)
	summary_title.add_theme_color_override("font_color", Color(0.75, 0.2, 0.15))
	svb.add_child(summary_title)
	summary_label = _label("", 16, true)
	summary_label.custom_minimum_size = Vector2(0, 0)
	svb.add_child(summary_label)
	summary_hint = _label("", 14)
	summary_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	svb.add_child(summary_hint)
	summary_root.visible = false
	_build_terminal()
	_build_map()

const TERM_GREEN := Color(0.45, 1.0, 0.55)

func _build_terminal() -> void:
	term_panel = PanelContainer.new()
	term_panel.name = "Terminal"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.03, 0.97)
	sb.border_color = KRAFT          # cardboard monitor bezel around the CRT
	sb.set_border_width_all(10)
	sb.shadow_color = Color(0.1, 0.06, 0.04, 0.4)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(5, 6)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	term_panel.add_theme_stylebox_override("panel", sb)
	world_slot.add_child(term_panel)
	term_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	term_panel.offset_left = 12; term_panel.offset_top = 10; term_panel.offset_right = -12; term_panel.offset_bottom = -10
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "Courier New", "monospace"])
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	term_panel.add_child(v)
	term_header = _label("", 15, true)
	term_header.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	v.add_child(term_header)
	var xr := HBoxContainer.new()
	xr.add_theme_constant_override("separation", 10)
	v.add_child(xr)
	term_xp_label = _label("", 13)
	term_xp_label.add_theme_color_override("font_color", TERM_GREEN)
	xr.add_child(term_xp_label)
	term_xp_bar = _bar(Color(0.3, 0.85, 0.45))
	term_xp_bar.custom_minimum_size = Vector2(160, 12)
	term_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	term_xp_bar.show_percentage = false
	xr.add_child(term_xp_bar)
	term_out = _label("", 14, true)
	term_out.add_theme_font_override("font", mono)
	term_out.add_theme_color_override("font_color", TERM_GREEN)
	term_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	term_out.clip_text = true
	term_out.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	v.add_child(term_out)
	var row := HBoxContainer.new()
	v.add_child(row)
	term_prompt = _label("dan-laptop$", 14)
	term_prompt.add_theme_font_override("font", mono)
	term_prompt.add_theme_color_override("font_color", TERM_GREEN)
	row.add_child(term_prompt)
	term_input = LineEdit.new()
	term_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	term_input.add_theme_font_override("font", mono)
	term_input.add_theme_font_size_override("font_size", 14)
	term_input.add_theme_color_override("font_color", TERM_GREEN)
	term_input.placeholder_text = "type a command, or click one below    (Tab completes · H = hint · S = show me)"
	term_input.text_submitted.connect(func(t): term_submit(t, false))
	term_input.gui_input.connect(_term_input_key)
	if "keep_editing_on_text_submit" in term_input: term_input.set("keep_editing_on_text_submit", true)
	row.add_child(term_input)
	term_suggest = HFlowContainer.new()
	term_suggest.add_theme_constant_override("h_separation", 6)
	v.add_child(term_suggest)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 8)
	v.add_child(br)
	term_hint_btn = Button.new(); term_hint_btn.text = "Hint (H)"; term_hint_btn.pressed.connect(term_hint); br.add_child(term_hint_btn)
	term_show_btn = Button.new(); term_show_btn.text = "Show me (S)"; term_show_btn.pressed.connect(term_showme); br.add_child(term_show_btn)
	var ap := Button.new(); ap.text = "Autopilot (worse results)"; ap.pressed.connect(term_autopilot); br.add_child(ap)
	term_ap_btn = ap
	var wa := Button.new(); wa.text = "Walk away (Esc)"; wa.pressed.connect(term_close.bind(false)); br.add_child(wa)
	term_status = _label("", 13, true)
	term_status.add_theme_color_override("font_color", TERM_GREEN)
	term_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	term_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(term_status)
	term_panel.visible = false

func term_open() -> bool:
	return term_panel != null and term_panel.visible

func _cat() -> String:
	return GameState.skill_of(term.kind) if term else "networking"

func autopilot_allowed() -> bool:
	if term == null: return false
	if inc_id != "":
		for k in TicketSim.INCIDENTS[inc_id]["stages"]:
			if not GameState.autopilot_unlocked(GameState.skill_of(k)): return false
		return true
	return GameState.autopilot_unlocked(_cat())

## Opens a multi-stage incident (at work, or after hours from a page).
func open_incident(id: String, after_hours := false) -> void:
	inc_id = id; inc_idx = 0; inc_used = 0; inc_breached = false; inc_after_hours = after_hours; inc_cmds = 0; inc_hints = 0
	term_rng.seed = GameState.rng.randi()
	# SLA = fastest path + a little slack: a clean run makes it, wandering or leaning on hints doesn't.
	inc_optimal = 0
	var est := RandomNumberGenerator.new()
	for si in TicketSim.INCIDENTS[id]["stages"].size():
		est.seed = 1000 + si
		inc_optimal += TicketSim.make_stage(est, id, si).optimal()
	# Pass 3: the SLA scales with Dan's skill in the incident's areas. Early on the business
	# expects less (generous slack); an expert gets the tight P1 SLA. Curveballs (Gary, vendors,
	# Karen) can still eat minutes, so even experts sometimes breach.
	inc_slack = incident_slack(incident_level(id), term_rng)
	inc_budget = inc_optimal * INC_CMD_MIN + inc_slack
	inc_curve = 0
	term = TicketSim.make_stage(term_rng, id, 0)
	term_done = false
	term_panel.visible = true
	term_input.editable = true
	term_input.text = ""
	if loc: dan.stop_walking()
	_term_refresh()

func open_terminal(kind := "") -> void:
	var why := GameState.can_do("work_ticket")
	if why != "":
		_log(why)
		return
	inc_id = ""
	# Occasionally a ticket is really an incident (at work, max 2 a week).
	if kind == "" and GameState.phase == "work" and GameState.incidents_week < 2 and GameState.minutes <= GameState.DAY_END - 180 and GameState.rng.randf() < 0.12:
		open_incident(TicketSim.INCIDENTS.keys()[GameState.rng.randi() % TicketSim.INCIDENTS.size()])
		return
	term_rng.seed = GameState.rng.randi()
	term = TicketSim.new(term_rng, kind)
	term_done = false
	term_panel.visible = true
	term_input.editable = true
	term_input.text = ""
	if loc: dan.stop_walking()
	_term_refresh()
	if is_inside_tree() and term_input.is_inside_tree():
		term_input.grab_focus.call_deferred()

func _max_hints() -> int:
	return GameState.max_hints(_cat())

func _term_refresh() -> void:
	var focus := GameState.rx_active()
	var flags := ""
	if focus: flags = "   [FOCUS: next step highlighted, free hints]"
	elif GameState.is_on_fumes(): flags = "   [RUNNING ON FUMES: typos likely, 1 hint]"
	var cat := _cat()
	var pr: Array = GameState.skill_progress(cat)
	term_xp_label.text = "Dan's %s: Lv %d  %s" % [GameState.SKILL_NAMES[cat], GameState.skill_level(cat), ("%d/%d XP" % pr) if pr[1] > 0 else "MAX"]
	term_xp_bar.max_value = maxi(1, pr[1]); term_xp_bar.value = pr[0] if pr[1] > 0 else 1
	if inc_id != "":
		flags += "   [INCIDENT: %d/%d min%s]" % [inc_used, inc_budget, " — SLA BREACHED" if inc_breached else ""]
	var unlocked := autopilot_allowed()
	term_ap_btn.disabled = term_done or not unlocked
	term_ap_btn.text = ("Autopilot (%s)" % ("decent results" if GameState.autopilot_grade(cat) == "good" else "worse results")) if unlocked else ("Autopilot suspended (Gary's Plan)" if GameState.on_pip() else "Autopilot locked (needs Lv %d)" % GameState.PROFICIENT)
	term_header.text = "TermOS · %s · %d command%s · hints %d/%s%s" % [term.title, term.commands, "" if term.commands == 1 else "s", term.hints_used, "∞" if focus else str(_max_hints()), flags]
	var lines := term.log_lines.slice(maxi(0, term.log_lines.size() - 14))
	term_out.text = "\n".join(lines)
	term_prompt.text = term.cur_host + "$"
	for c in term_suggest.get_children():
		term_suggest.remove_child(c); c.queue_free()
	if term_done:
		var b := Button.new(); b.text = "Close ticket (Enter)"; b.pressed.connect(term_close.bind(true)); term_suggest.add_child(b)
	else:
		var sug := term.suggestions(focus)
		for i in sug.size():
			var b := Button.new()
			b.text = ("▶ " if focus and i == 0 else "") + sug[i]
			b.add_theme_font_size_override("font_size", 13)
			var cmd: String = sug[i]
			b.pressed.connect(func(): _term_click(cmd))
			term_suggest.add_child(b)
	term_hint_btn.disabled = term_done or (not focus and term.hints_used >= _max_hints())
	term_show_btn.disabled = term_hint_btn.disabled
	term_status.text = "Estimated grade: %s" % term.grade().capitalize() if not term_done else "Solved! Grade: %s" % term.grade().capitalize()

func _term_click(cmd: String) -> void:
	if cmd.ends_with(" …"):
		term_input.text = cmd.trim_suffix(" …") + " "
		term_input.caret_column = term_input.text.length()
		term_input.grab_focus()
	else:
		term_submit(cmd, true)

## Runs a command in the ticket. Low energy can fumble typed (not clicked) commands.
func term_submit(cmd: String, clicked := false) -> void:
	if term == null or term_done or cmd.strip_edges() == "":
		return
	cmd = cmd.strip_edges()
	if not clicked and GameState.is_on_fumes() and cmd.length() > 4 and term_rng.randf() < 0.25:
		var i := 1 + term_rng.randi() % (cmd.length() - 2)
		cmd = cmd.substr(0, i) + cmd[i + 1] + cmd[i] + cmd.substr(i + 2)
		term.log_lines.append("(your fingers are tired)")
	if clicked: term.clicked_cmds += 1
	term.run(cmd)
	term_input.text = ""
	_tab_last = ""
	if inc_id != "":
		inc_cmds += 1
		# a typo / unknown command costs a minute, not a full step (newbies flail; that's allowed)
		inc_used += 1 if "command not found" in str(term.log_lines[-1] if not term.log_lines.is_empty() else "") else INC_CMD_MIN
		if term_rng.randf() < CURVEBALL_P:
			var cb: Array = CURVEBALLS[term_rng.randi() % CURVEBALLS.size()]
			inc_used += cb[1]; inc_curve += cb[1]
			term.log_lines.append("⏱ Curveball: %s (+%d min)" % [cb[0], cb[1]])
		if _inc_check_breach():
			term.log_lines.append("Gary: Hey. We're past the SLA. That's okay. Just... keep going. I'm telling the CEO you're 'in the zone'.")
		if term.solved and inc_idx + 1 < TicketSim.INCIDENTS[inc_id]["stages"].size():
			inc_hints += term.hints_used
			var done_line: String = "✔ Stage %d done. %s" % [inc_idx + 1, term.reply]
			inc_idx += 1
			term = TicketSim.make_stage(term_rng, inc_id, inc_idx)
			term.log_lines.insert(0, done_line)
			_term_refresh()
			_term_focus()
			return
	if term.solved:
		term_done = true
		term_input.editable = false
		term.log_lines.append("")
		term.log_lines.append("✔ TICKET RESOLVED. " + term.reply)
	_term_refresh()
	_term_focus()

var _tab_last := ""
## Tab: complete commands, hosts and args; a second Tab with nothing to add lists the options.
func term_tab() -> void:
	if term == null or term_done: return
	var line := term_input.text
	var r: Array = term.complete(line)
	if r[0] != line:
		term_input.text = r[0]
		_tab_last = ""
	elif not (r[1] as Array).is_empty():
		if _tab_last == line:
			term.log_lines.append(term.cur_host + "$ " + line)
			term.log_lines.append("  ".join(r[1]))
			_term_refresh()
		_tab_last = line
	term_input.caret_column = term_input.text.length()
	_term_focus()

func _term_input_key(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_TAB:
		term_tab()
		term_input.accept_event()

## Keep the cursor in the prompt so you can keep typing (Marty's playtest bug).
func _term_focus() -> void:
	if term_open() and not term_done and term_input.is_inside_tree() and term_input.is_visible_in_tree():
		term_input.grab_focus()
		term_input.grab_focus.call_deferred()   # again after the suggestion buttons are rebuilt

## Returns true the moment the SLA is first breached.
func _inc_check_breach() -> bool:
	if inc_id != "" and inc_used > inc_budget and not inc_breached:
		inc_breached = true
		return true
	return false

## "Show me": runs the next step for you and says what it was, so it teaches (costs a hint).
func term_showme() -> void:
	if term == null or term_done:
		return
	var focus := GameState.rx_active()
	if not focus and term.hints_used >= _max_hints():
		return
	var cmd: String = term.next_step()
	term.hints_used += 0 if focus else 1
	if inc_id != "":
		inc_used += hint_cost(incident_level(inc_id)) / (2 if focus else 1)
	term.log_lines.append("Show me: this step is  %s  (next time type the first letters and press Tab)." % cmd)
	shown_steps += 1
	term_submit(cmd, true)

var shown_steps := 0

func term_hint() -> void:
	if term == null or term_done:
		return
	var focus := GameState.rx_active()
	if not focus and term.hints_used >= _max_hints():
		return
	var h := term.hint()
	if focus: term.hints_used -= 1   # Rx focus: hints are free
	term.log_lines.append(h)
	if inc_id != "":
		inc_used += hint_cost(incident_level(inc_id)) / (2 if focus else 1)
		if _inc_check_breach():
			term.log_lines.append("Gary: Hey. We're past the SLA. That's okay. Just... keep going. I'm telling the CEO you're 'in the zone'.")
	_term_refresh()

func _finish_incident(autopilot: bool) -> void:
	var id := inc_id
	inc_hints += term.hints_used if term else 0
	var used := inc_used if not autopilot else inc_budget - 5
	var pm: String = GameState.resolve_incident(id, maxi(used, 15), inc_breached, inc_after_hours, autopilot, inc_cmds, inc_hints, inc_budget, inc_optimal)
	if inc_curve > 0 and not autopilot:
		pm += "\nCurveballs: %d min went to interruptions you couldn't control (SLA for your level: %d min)." % [inc_curve, inc_budget]
	inc_id = ""
	term_panel.visible = false
	term = null
	_log("Incident resolved. Postmortem filed.")
	if not summary_root.visible and pending_summary == "":
		summary_title.text = "POSTMORTEM"
		summary_label.text = pm.substr(pm.find("\n") + 1)
		summary_hint.text = "[Enter] Back to it"
		_fit_summary()
		summary_kind = "postmortem"
		summary_root.visible = true
	_refresh_prompt()

func term_autopilot() -> void:
	if term == null:
		return
	if not autopilot_allowed():
		return
	if GameState.on_pip(): GameState.today["pip_autopilot"] = true
	if inc_id != "":
		_finish_incident(true)
		return
	var res := GameState.resolve_ticket(GameState.autopilot_grade(_cat()), term.title, "%s: Thanks! It works now. (You couldn't tell anyone why.)" % term.from, term.kind)
	term_panel.visible = false
	term = null
	_log(res)
	_refresh_prompt()

func term_close(resolve: bool) -> void:
	if term == null:
		term_panel.visible = false
		return
	if inc_id != "":
		if resolve and term_done:
			_finish_incident(false)
		else:
			GameState.charge_walkaway(maxi(inc_cmds, 3) if inc_cmds > 0 else 0)
			_log("You hand the incident to Gary, who hands it to 'the vendor'. It gets fixed tomorrow. Performance -6.")
			GameState.performance = clampi(GameState.performance - 6, 0, 100)
			GameState.stress = clampi(GameState.stress + 5, 0, 100)
			inc_id = ""
			term_panel.visible = false
			term = null
			GameState.state_changed.emit()
		return
	if resolve and term_done:
		var res := GameState.resolve_ticket(term.grade(), term.title, term.reply, term.kind, term.typed_bonus())
		_log(res)
	else:
		var spent: int = GameState.charge_walkaway(term.commands)
		_log("You walk away from the ticket. It'll still be there. Tickets are loyal like that." + (" (%d min you won't get back.)" % spent if spent > 0 else ""))
	term_panel.visible = false
	term = null
	_refresh_prompt()

# ------------------------------------------------------------ town map
var use_map := true
var fed_label: Label
var map_root: Control
var map_header: Label
var map_tex: TextureRect
var map_hint: Label
var map_btns := {}
var map_order: Array = []

func _build_map() -> void:
	map_root = ColorRect.new()
	map_root.name = "TownMap"
	(map_root as ColorRect).color = Color(0.32, 0.24, 0.17, 0.82) if paper else Color(0.05, 0.07, 0.05, 0.9)
	world_slot.add_child(map_root)
	map_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: mc.add_theme_constant_override("margin_" + side, 8)
	map_root.add_child(mc)
	var vb := VBoxContainer.new()
	mc.add_child(vb)
	var mhp := PanelContainer.new()
	vb.add_child(mhp)
	map_header = _label("", 16, true)
	map_header.add_theme_color_override("font_color", INK)
	map_header.custom_minimum_size = Vector2(0, 0)
	mhp.add_child(map_header)
	var ar := AspectRatioContainer.new()
	ar.ratio = 16.0 / 9.0
	ar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(ar)
	map_tex = TextureRect.new()
	map_tex.texture = load("res://assets/paper/town_board.png") if paper else load("res://assets/map/town_map.png")
	map_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_tex.stretch_mode = TextureRect.STRETCH_SCALE
	map_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ar.add_child(map_tex)
	for id in GameState.PLACES:
		var b := Button.new()
		b.name = "Place_" + id
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(0, 25)   # a11y: click targets >= 24 px
		var p: Array = GameState.PLACES[id]
		b.anchor_left = p[1]; b.anchor_right = p[1]; b.anchor_top = p[2]; b.anchor_bottom = p[2]
		b.grow_horizontal = Control.GROW_DIRECTION_BOTH if p[1] < 0.8 else Control.GROW_DIRECTION_BEGIN
		if p[1] >= 0.8: b.offset_left = 30; b.offset_right = 30
		b.grow_vertical = Control.GROW_DIRECTION_END
		b.offset_top = 14
		b.pressed.connect(map_pick.bind(id))
		map_tex.add_child(b)
		map_btns[id] = b
	map_hint = _label("Click a place, or press its number. Arrows + Enter work too. M opens the map from the car.", 13, true)
	var mhp2 := PanelContainer.new()
	vb.add_child(mhp2)
	mhp2.add_child(map_hint)
	map_root.visible = false

func map_open() -> bool:
	return map_root != null and map_root.visible

func _map_can_close() -> bool:
	return GameState.phase == "home_am" or GameState.at_place == "gas"

func open_map() -> void:
	map_root.visible = true
	if loc: dan.stop_walking()
	_map_refresh()
	if text_scale != 1.0: apply_text_scale(map_root)

func close_map() -> void:
	map_root.visible = false
	_refresh_prompt()

func _map_refresh() -> void:
	var opts: Array = GameState.map_options()
	map_order = []
	var n := 0
	var first_ok: Button = null
	for o in opts:
		var b: Button = map_btns[o[0]]
		var why: String = o[3]
		var short: String = str(o[1]).split(" (")[0]
		if why == "You're here." or (GameState.phase == "home_am" and o[0] != "office"):
			b.visible = o[0] == "home" or why == "You're here."
			b.disabled = true
			b.text = "• " + short + " (you)"
			if b.visible and o[0] != "home" and GameState.phase == "home_am": b.visible = false
			continue
		b.visible = true
		n += 1
		map_order.append(o[0])
		b.disabled = why != ""
		b.text = "[%d] %s · %d min" % [n, short, o[2]] if why == "" else "[%d] %s 🔒" % [n, short]
		b.tooltip_text = str(GameState.PLACES[o[0]][6]) if why == "" else why
		if why == "" and first_ok == null: first_ok = b
	var who := "with the girls" if GameState.girls_picked else ("Jess has the girls" if GameState.jess_has_girls() else "girls at after-care")
	map_header.text = "Brookfield · %s · %s · Where to?" % [GameState.clock_text(), who if GameState.phase == "drive" else "school run"]
	if GameState.phase == "drive" and not GameState.girls_picked and not GameState.jess_has_girls():
		if GameState.minutes < GameState.PICKUP_OPEN:
			map_header.text += "  (after-care opens in %d min: coffee, park, pharmacy or Lou's?)" % (GameState.PICKUP_OPEN - GameState.minutes)
		else:
			map_header.text += "  (after-care closes in %d min)" % maxi(0, GameState.PICKUP_CLOSE - GameState.minutes)
	var locked: Array[String] = []
	for o in opts:
		if o[3] != "" and o[0] in map_order: locked.append("%s: %s" % [str(o[1]).split(" (")[0], o[3]])
	map_hint.text = ("🔒 " + "  ·  ".join(locked) + "\n" if not locked.is_empty() else "") + "Click a place or press its number (arrows + Enter work too). M reopens the map from the car."
	if first_ok and is_inside_tree() and first_ok.is_inside_tree() and first_ok.is_visible_in_tree():
		first_ok.grab_focus()

## Player picked a destination on the map.
func map_pick(id: String) -> void:
	var why := ""
	for o in GameState.map_options():
		if o[0] == id: why = o[3]
	if why != "":
		_log(why); _map_refresh(); return
	map_root.visible = false
	if id == "office":
		perform_direct("leave_for_work")
	elif id == "home":
		perform_direct("pickup_girls")
	else:
		var res: String = GameState.travel(id)
		_log(res)
		if id != "gas" and GameState.phase == "drive":
			open_map()
	sync_location()
	_refresh_prompt()

func perform_direct(aid: String) -> void:
	var res: String = GameState.do_action(aid)
	_log(res)
	_refresh_prompt()

## In town without being at the Gas-N-Sip: the map is the world (after cutscenes finish).
func auto_map() -> void:
	if use_map and GameState.phase == "drive" and GameState.at_place != "gas" and not map_open() and cs_id == "" and not summary_root.visible and not term_open():
		open_map()

func _layout_world() -> void:
	if world_slot == null:
		return
	var r := world_slot.get_global_rect()
	if r.size.x <= 0:
		return
	var sc := minf(r.size.x / WORLD_SIZE.x, r.size.y / WORLD_SIZE.y)
	world.scale = Vector2(sc, sc)
	world.position = r.position + (r.size - WORLD_SIZE * sc) / 2.0

# ------------------------------------------------------------------ paper diorama
func _build_paper() -> void:
	paper_view = SubViewportContainer.new()
	paper_view.name = "PaperView"
	paper_view.stretch = true
	paper_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_slot.add_child(paper_view)
	world_slot.move_child(paper_view, 0)
	paper_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.handle_input_locally = false
	paper_view.add_child(vp)
	diorama = Diorama.new()
	diorama.main = self
	vp.add_child(diorama)
	world.visible = false

## Which paper set to show: the plan's location, or a town destination while driving.
func _paper_place() -> String:
	if loc_name == "road" and GameState.phase == "drive" and GameState.at_place in ["park", "pharmacy", "dental", "diner", "coffee"]:
		return GameState.at_place
	return ""

func _paper_sync() -> void:
	if diorama == null or loc == null:
		return
	var key := loc_name + "/" + _paper_place() + "/" + str(loc.get_instance_id())
	if key != _paper_key:
		_paper_key = key
		diorama.build(loc, loc_name, _paper_place())
		diorama.refresh_cozy(GameState.fridge_drawings, GameState.plant)
		diorama.refresh_farm(GameState)

## Short proximity prompt for the paper tag over a station.
func _tag_text() -> String:
	if near_station == "" or loc == null or not loc.stations.has(near_station):
		return ""
	var n := _current_actions().size()
	return "%s  [1%s]" % [loc.stations[near_station]["label"], "-%d" % n if n > 1 else ""] if n > 0 else ""

## Typewriter + mouth flaps: the speaker's head flips open on vowels as the letters appear,
## and pauses on punctuation (comic timing: the beat before the punchline).
func _type_tick(delta: float) -> void:
	talk_flap = 0.0
	if not dialog_panel.visible or cs_waiting != "say":
		return
	var total := dialog_text.get_total_character_count()
	if dialog_text.visible_characters < 0 or dialog_text.visible_characters >= total:
		dialog_text.visible_characters = -1
		return
	_type_t += delta * (type_cps if type_cps > 0 and not cs_fast else 100000.0)
	while _type_t >= 1.0 and dialog_text.visible_characters < total:
		_type_t -= 1.0
		dialog_text.visible_characters += 1
		var ch := dialog_text.text.substr(dialog_text.visible_characters - 1, 1)
		if ch in [".", "!", "?", "…"]: _type_t -= 9.0     # ~0.2 s beat
		elif ch in [",", ";", ":", "—"]: _type_t -= 4.0
	var i := maxi(0, dialog_text.visible_characters - 1)
	var c := dialog_text.text.substr(i, 1).to_lower()
	if talk_who == "": return       # narration: letters type out, nobody's mouth moves
	if c in ["a", "e", "i", "o", "u", "y"]: talk_flap = 0.28
	elif c.is_valid_identifier() or c.is_valid_int(): talk_flap = 0.1

## Dialogue banner goes bottom (default) or top, whichever covers fewer wall signs / the speaker.
var banner_top := false
func _place_banner() -> void:
	if not paper or diorama == null or world_slot == null:
		return
	var vp_size: Vector2 = diorama.cam.get_viewport().get_visible_rect().size
	var ws := world_slot.size
	var bot_n := 0
	var top_n := 0
	var bh := 138.0
	if vp_size.x > 10:
		var pts := diorama.banner_keepouts(talk_who)
		for hh in [138.0, 116.0]:   # both sides blocked? try the compact banner (pass 3: signs under the banner)
			bh = hh
			var h: float = hh * vp_size.y / maxf(1.0, ws.y)
			bot_n = 0; top_n = 0
			for p in pts:
				if p.y > vp_size.y - h: bot_n += 1
				if p.y < h: top_n += 1
			if top_n == 0 or bot_n == 0: break
	var want_top := top_n < bot_n
	banner_top = want_top
	compact_banner = bh < 138.0
	dialog_hint.visible = not compact_banner   # pass 3: the compact banner drops the key hint so nothing spills out
	dialog_panel.grow_vertical = Control.GROW_DIRECTION_END if banner_top else Control.GROW_DIRECTION_BEGIN
	if banner_top:
		dialog_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
		dialog_panel.offset_left = 16; dialog_panel.offset_right = -16
		dialog_panel.offset_top = 10; dialog_panel.offset_bottom = 10 + bh - 10
	else:
		dialog_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		dialog_panel.offset_left = 16; dialog_panel.offset_right = -16
		dialog_panel.offset_top = -bh; dialog_panel.offset_bottom = -10

var compact_banner := false

func typing() -> bool:
	return dialog_panel.visible and cs_waiting == "say" and dialog_text.visible_characters >= 0 and dialog_text.visible_characters < dialog_text.get_total_character_count()

func _portrait(who: String) -> Texture2D:
	if paper and diorama and who in PaperCard.HEIGHTS:
		var at := AtlasTexture.new()
		at.atlas = diorama.card(who).texture()
		at.region = Rect2(36, 0, 184, 172)
		return at
	if paper and who != "":
		return load("res://assets/paper/lifeos.png")
	var p := "res://assets/portraits/%s.png" % who
	return load(p) if ResourceLoader.exists(p) else (load("res://assets/portraits/lifeos.png") if who != "" else null)

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
	_paper_sync()
	if hud_phase:
		_refresh()

## Logic location for the current phase. After work Dan is on the road; the Gas-N-Sip only
## when he picked it on the map (Marty: no forced stop).
func phase_loc() -> String:
	if GameState.phase == "drive" and GameState.at_place == "gas":
		return "gas_station"
	if in_garage and GameState.phase in ["home_am", "home_pm", "weekend"]:
		return "garage"
	return PHASE_LOC[GameState.phase]

## Puts the world in the right place for the current phase, with default NPCs.
func sync_location() -> void:
	var want: String = phase_loc()
	load_location(want)
	var npcs := {}
	match GameState.phase if want != "garage" else "garage":
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
	_paper_sync()
	_update_fridge()
	_refresh_prompt()

## Cozy loop made visible: one little drawing per fridge_drawings on the house fridge.
func _update_fridge() -> void:
	if loc_name != "house":
		return
	if diorama:
		diorama.refresh_cozy(GameState.fridge_drawings, GameState.plant)
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
	return cs_id != "" or summary_root.visible or term_open() or map_open() or desktop_open() or assembly_open()

func _process(delta: float) -> void:
	if lifeos_panel.visible and not dialog_panel.visible:
		lifeos_timer -= delta
		if lifeos_timer <= 0:
			lifeos_panel.visible = false
	_cs_tick(delta)
	auto_map()
	if diorama and loc:
		_type_tick(delta)
		_paper_sync()
		diorama.set_time(GameState.minutes)
		diorama.tick(delta, loc, near_station if not is_busy() else "", talk_who, talk_flap, _tag_text())
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
	if assembly_open() and cs_id == "":
		if k >= KEY_1 and k <= KEY_3: assembly_step(k - KEY_1)
		elif k == KEY_ESCAPE: close_assembly()
		return
	if desktop_open() and cs_id == "":
		if k == KEY_ESCAPE: (close_window() if desk_window.visible else close_desktop())
		return
	if map_open() and cs_id == "" and not summary_root.visible:
		if k >= KEY_1 and k <= KEY_9:
			var i: int = k - KEY_1
			if i < map_order.size(): map_pick(map_order[i])
		elif k == KEY_ESCAPE and _map_can_close():
			close_map()
		return
	if k == KEY_M and GameState.phase == "drive" and cs_id == "" and not term_open():
		open_map(); return
	if term_open():
		if k == KEY_ESCAPE:
			term_close(false)
		elif term_done and (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE):
			term_close(true)
		elif k == KEY_S and not term_input.has_focus():
			term_showme()
		elif k == KEY_H and not term_input.has_focus():
			term_hint()
		return
	var confirm := k == KEY_ENTER or k == KEY_SPACE or k == KEY_KP_ENTER
	if cs_id != "" and cs_waiting == "choice":
		if k >= KEY_1 and k < KEY_1 + cs_choices.size():
			pick_choice(k - KEY_1)
		return
	if cs_id != "":
		if k == KEY_ESCAPE:
			skip_cutscene()
		elif confirm:
			if typing(): dialog_text.visible_characters = -1   # first press: finish the line
			else: advance()
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
		KEY_F2:
			set_text_scale([1.0, 1.25, 1.5][([1.0, 1.25, 1.5].find(text_scale) + 1) % 3])
			show_lifeos("LifeOS: Text size %d%%. Squinting is optional now." % int(text_scale * 100))
		KEY_F3:
			type_cps = {48.0: 96.0, 96.0: 0.0, 0.0: 48.0}.get(type_cps, 48.0)
			show_lifeos("LifeOS: Text speed: %s." % ("instant" if type_cps == 0 else "%d characters/s" % int(type_cps)))
		KEY_F4:
			skip_seen = not skip_seen
			_save_seen()
			show_lifeos("LifeOS: Seen dialogue: %s." % ("instant" if skip_seen else "plays normally"))
		KEY_F6:
			show_lifeos("LifeOS: Saved (the morning of %s; F7 rewinds to it). Your progress is safe. Your inbox is not." % GameState.day_name() if GameState.save_game() else "LifeOS: Save failed. Classic.")
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
		if aid == "go_inside" or GameState.phase in GameState.ACTIONS[aid]["phases"]:
			out.append(aid)
	return out

func perform(aid: String) -> void:
	# Leaving a place opens the town map (Marty: Stardew-style travel instead of a fixed sequence).
	if use_map and ((aid == "leave_for_work" and GameState.phase == "home_am") or (aid == "pickup_girls" and GameState.phase == "drive")):
		if GameState.can_do(aid) != "":
			_log(GameState.can_do(aid)); return
		open_map()
		return
	if aid == "work_ticket" and use_terminal:
		open_terminal()
		return
	match aid:
		"pc": open_desktop(); return
		"farm_check": open_desktop(); desk_app("farm"); return
		"go_garage", "go_inside":
			in_garage = aid == "go_garage"
			sync_location()
			_log("The garage. It smells like cardboard and ambition." if in_garage else "Back inside. The hum follows you a little.")
			return
		"build_farm":
			if GameState.can_do(aid) != "": _log(GameState.can_do(aid)); return
			open_assembly(); return
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
	_fit_summary()
	pending_summary = ""

func _fit_summary() -> void:
	# Long weeks make long reviews: shrink text until the panel fits the game area.
	var lines := summary_label.text.count("\n") + 1 + int(summary_label.text.length() / 90)
	var avail := world_slot.size.y - 120.0
	var fs := 16
	while fs > 10 and lines * fs * 1.45 > avail:
		fs -= 1
	summary_label.add_theme_font_size_override("font_size", fs)

func dismiss_summary() -> void:
	summary_root.visible = false
	if summary_kind == "postmortem":
		summary_kind = ""
		if pending_summary != "":
			show_summary()
		return
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
		talk_who = ""
		dialog_panel.visible = false
		if pending_summary != "":
			show_summary()
		else:
			dimmer.color.a = 0.0
			sync_location()
			_check_pending_incident()
		return
	var item: Array = cs_queue.pop_front()
	cs_id = item[0]
	cs_fast = skip_seen and seen_scenes.has(cs_id)
	if not seen_scenes.has(cs_id):
		seen_scenes[cs_id] = true
		_save_seen()
	if cs_id != "moment": in_garage = false
	if desktop_open(): close_desktop()
	if assembly_open(): close_assembly()
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
				if choice_policy.is_valid(): pick = clampi(int(choice_policy.call(opts)), 0, opts.size() - 1)
				_log(GameState.apply_choice(opts[pick][1]))
				_check_pending_incident.call_deferred()
			else:
				cs_choices = opts
				dialog_name.text = "Your call"
				var t := ""
				for i in opts.size():
					t += "[%d] %s\n" % [i + 1, opts[i][0]]
				dialog_text.text = t.strip_edges()
				dialog_portrait.texture = _portrait("dan")
				talk_who = ""
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
			dialog_portrait.texture = _portrait(who)
			talk_who = who
			_type_t = 0.0
			_place_banner()
			dialog_text.visible_characters = 0 if (paper and not instant) else -1
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
	_check_pending_incident.call_deferred()
	cs_choices = []
	cs_waiting = ""
	dialog_panel.visible = false

func _check_pending_incident() -> void:
	if GameState.pending_incident != "" and cs_id == "" and not term_open():
		var id := GameState.pending_incident
		GameState.pending_incident = ""
		open_incident(id, true)

func advance() -> void:
	if cs_waiting == "say":
		cs_waiting = ""
		dialog_panel.visible = false
		dialog_text.visible_characters = -1
		talk_who = ""

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
		if a.get("ui", false):
			parts.append("[%d] %s" % [i, a["name"]]); i += 1; continue
		var cost := "%d min, %+d energy" % [GameState.action_blocks(aid) * GameState.BLOCK, int(a["energy"])]
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
	hud_phase.text = GameState.phase_name() if loc == null or loc_name == phase_loc() else loc.title
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
	if fed_label: fed_label.text = "Girls: Fed — HUNGRY ⚠" if GameState.girls_fed < GameState.FED_WARN else "Girls: Fed"
	if fed_label: fed_label.add_theme_color_override("font_color", Color(0.8, 0.12, 0.08) if GameState.girls_fed < GameState.FED_WARN else INK)
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
	labels = labels.filter(func(l: Label) -> bool:
		var p := l.get_parent()
		while p != null and p != ui:
			if p is ScrollContainer: return (p as ScrollContainer).get_global_rect().intersects(l.get_global_rect())
			p = p.get_parent()
		return true)
	for l in labels:
		var r := l.get_global_rect()
		if not vp.encloses(r):
			problems.append("out of bounds: '%s' %s" % [l.text.left(30), r])
		if not l.clip_text and l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.get_minimum_size().x > l.size.x + 1:
			problems.append("clipped: '%s'" % l.text.left(30))
	var game_area := world_slot.get_global_rect().grow(1)
	for l in labels:
		if _overlay_of(l) != "HUD" and not game_area.encloses(l.get_global_rect()):
			problems.append("popup outside game area (covers sidebar): '%s'" % l.text.left(30))
	for i in labels.size():
		for j in range(i + 1, labels.size()):
			var a := labels[i]
			var b := labels[j]
			if _overlay_of(a) != _overlay_of(b):
				continue
			if a.size.x < 3 or a.size.y < 3 or b.size.x < 3 or b.size.y < 3:
				continue
			if a.get_global_rect().grow(-1).intersects(b.get_global_rect().grow(-1)):
				problems.append("overlap: '%s' / '%s'" % [a.text.left(25), b.text.left(25)])
	if map_open():
		var btns: Array = map_btns.values()
		for i in btns.size():
			var r: Rect2 = btns[i].get_global_rect()
			if not game_area.encloses(r): problems.append("map button outside game area: '%s'" % btns[i].text.left(25))
			for j in range(i + 1, btns.size()):
				if r.grow(-1).intersects(btns[j].get_global_rect().grow(-1)):
					problems.append("map buttons overlap: '%s' / '%s'" % [btns[i].text.left(20), btns[j].text.left(20)])
	return problems

func _overlay_of(n: Node) -> String:
	while n != null and n != ui:
		if n.name in ["LifeOS", "Dialogue", "Summary", "Terminal", "TownMap", "Desktop", "Assembly"]:
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


# ------------------------------------------------------------------ home PC desktop (BrookOS)
var desktop: Control
var desk_window: PanelContainer
var desk_title: Label
var desk_body: VBoxContainer
var desk_clock: Label
var desk_start: PanelContainer
var desk_tab: Button
var desk_app_id := ""
var desk_close_btn: Button
var cart: Array = []
var desk_msg := ""
const DESK_APPS := [["tickets", "▤", "Tickets"], ["games", "♞", "Vapor Games"], ["hustle", "✎", "Bakery Script"], ["pceggo", "◒", "PCEggo"],
	["rackbay", "▦", "RackBay"], ["kevin", "ϟ", "Kilowatt Kevin's"], ["cart", "▣", "Cart"], ["farm", "≋", "FarmStat"], ["trophies", "★", "Trophies"]]
const SHOP_TAG := {"pceggo": "PCEggo — parts with a little egg on them. Free next-day shipping on anything that fits in a box.",
	"rackbay": "RackBay — pre-loved enterprise gear. Previous owner: a bank that no longer exists.",
	"kevin": "Kilowatt Kevin's Power & Cooling — fans, foam, and a guy who knows a guy (licensed, mostly)."}

func desktop_open() -> bool:
	return desktop != null and desktop.visible

func _build_desktop() -> void:
	desktop = Control.new()
	desktop.name = "Desktop"
	world_slot.add_child(desktop)
	desktop.set_anchors_preset(Control.PRESET_FULL_RECT)
	var wall := Control.new()
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_STOP
	wall.draw.connect(func():
		var sz := wall.size
		wall.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.55, 0.74, 0.86))
		wall.draw_rect(Rect2(0, sz.y * 0.35, sz.x, sz.y * 0.1), Color(0.62, 0.79, 0.9))
		wall.draw_circle(Vector2(sz.x * 0.8, sz.y * 0.24), 46, Color(1, 0.86, 0.4))
		for k in 3:   # cut-paper hills with an ink edge
			var pts := PackedVector2Array()
			var base := sz.y * (0.62 + 0.08 * k)
			for i in 33:
				var x := sz.x * i / 32.0
				pts.append(Vector2(x, base - 40 * sin(i * 0.4 + k * 1.7) - 18 * k))
			pts.append(Vector2(sz.x, sz.y)); pts.append(Vector2(0, sz.y))
			wall.draw_colored_polygon(pts, [Color(0.46, 0.66, 0.4), Color(0.4, 0.58, 0.34), Color(0.8, 0.64, 0.44)][k])
			wall.draw_polyline(pts.slice(0, 33), INK, 2.0)
		wall.draw_string(ThemeDB.fallback_font, Vector2(sz.x - 240, sz.y - 54), "BrookOS 98 · Home Edition", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.75)))
	desktop.add_child(wall)
	var icons := GridContainer.new()
	icons.columns = 2
	icons.position = Vector2(12, 10)
	icons.add_theme_constant_override("h_separation", 8)
	icons.add_theme_constant_override("v_separation", 6)
	desktop.add_child(icons)
	for a in DESK_APPS:
		var b := Button.new()
		b.name = "Icon_" + a[0]
		b.text = "%s\n%s" % [a[1], a[2]]
		b.custom_minimum_size = Vector2(118, 54)
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(desk_app.bind(a[0]))
		icons.add_child(b)
	var bar := PanelContainer.new()
	bar.name = "Taskbar"
	bar.add_theme_stylebox_override("panel", _paper_box(KRAFT, INK, 2, false))
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -38
	desktop.add_child(bar)
	var hb := HBoxContainer.new()
	bar.add_child(hb)
	var st := Button.new()
	st.text = "◆ Start"
	st.pressed.connect(func(): desk_start.visible = not desk_start.visible)
	hb.add_child(st)
	desk_tab = Button.new()
	desk_tab.text = ""
	desk_tab.visible = false
	hb.add_child(desk_tab)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var esc := _label("Esc: close · Tab/arrows: move · Enter: open", 14)
	esc.add_theme_color_override("font_color", INK)
	hb.add_child(esc)
	desk_clock = _label("", 14)
	desk_clock.custom_minimum_size = Vector2(130, 0)
	desk_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desk_clock.add_theme_color_override("font_color", INK)
	hb.add_child(desk_clock)
	desk_start = PanelContainer.new()
	desk_start.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	desk_start.offset_bottom = -40; desk_start.offset_top = -40 - 300; desk_start.offset_right = 230
	desk_start.grow_vertical = Control.GROW_DIRECTION_BEGIN
	desktop.add_child(desk_start)
	var sv := VBoxContainer.new()
	desk_start.add_child(sv)
	for a in DESK_APPS:
		var b := Button.new(); b.text = "%s  %s" % [a[1], a[2]]; b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): desk_start.visible = false; desk_app(a[0]))
		sv.add_child(b)
	var off := Button.new(); off.text = "⏻  Shut down (back to the room)"; off.pressed.connect(close_desktop)
	sv.add_child(off)
	desk_start.visible = false
	desk_window = PanelContainer.new()
	desk_window.name = "Window"
	desk_window.set_anchors_preset(Control.PRESET_FULL_RECT)
	desk_window.offset_left = 268; desk_window.offset_right = -16; desk_window.offset_top = 12; desk_window.offset_bottom = -48
	desktop.add_child(desk_window)
	var wv := VBoxContainer.new()
	desk_window.add_child(wv)
	var tb := PanelContainer.new()
	tb.add_theme_stylebox_override("panel", _paper_box(Color(0.3, 0.42, 0.62), INK, 2, false))
	wv.add_child(tb)
	var th := HBoxContainer.new()
	tb.add_child(th)
	desk_title = _label("", 15)
	desk_title.add_theme_color_override("font_color", Color(1, 1, 1))
	desk_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desk_title.clip_text = true
	th.add_child(desk_title)
	var x := Button.new(); x.text = "✕"; x.pressed.connect(close_window)
	desk_close_btn = x
	th.add_child(x)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wv.add_child(sc)
	desk_body = VBoxContainer.new()
	desk_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(desk_body)
	desk_window.visible = false
	desktop.visible = false

func open_desktop() -> void:
	desktop.visible = true
	desk_start.visible = false
	desk_msg = ""
	close_window()
	desk_clock.text = "%s  %s" % [GameState.day_name().left(3), GameState.clock_text()]
	var first: Button = desktop.find_child("Icon_tickets", true, false)
	if first: first.grab_focus()   # keyboard parity: arrows + Enter work on the icons
	_log("BrookOS boots in 4 seconds. It used to take 90. You did that.")

func close_desktop() -> void:
	close_window()
	desktop.visible = false
	_refresh_prompt()

func close_window() -> void:
	desk_window.visible = false
	desk_app_id = ""
	desk_tab.visible = false

func _dl(t: String, size := 14, col := INK) -> Label:
	var l := _label(t, size, true)
	l.add_theme_color_override("font_color", col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(560, 0)
	desk_body.add_child(l)
	return l

## Opens an app on the desktop (also the API the bots and tests use).
func desk_app(id: String) -> void:
	_desk_build(id)
	if text_scale != 1.0: apply_text_scale(desktop)
	if desktop_open() and desk_window.visible: _desk_focus()

func _desk_build(id: String) -> void:
	match id:
		"tickets", "games", "hustle":
			var aid: String = {"tickets": "work_ticket", "games": "gaming", "hustle": "side_hustle"}[id]
			var why: String = GameState.can_do(aid)
			if why != "":
				desk_msg = why; _desk_popup(id, why); return
			close_desktop()
			perform(aid)
			return
	desk_app_id = id
	desk_window.visible = true
	desk_tab.visible = true
	desk_start.visible = false
	for c in desk_body.get_children(): c.free()
	var names := {"pceggo": "PCEggo.web — Deals", "rackbay": "RackBay — Used Enterprise", "kevin": "Kilowatt Kevin's — Power & Cooling", "cart": "Cart — Checkout", "farm": "FarmStat 1.0 — Mercer Data Center", "trophies": "Trophies"}
	desk_title.text = names.get(id, id)
	desk_tab.text = desk_title.text.left(18)
	match id:
		"pceggo", "rackbay", "kevin":
			_dl(SHOP_TAG[id], 14, Color(0.3, 0.2, 0.15))
			for iid in GameState.CATALOG:
				var it: Dictionary = GameState.CATALOG[iid]
				if it["shop"] != id: continue
				var row := HBoxContainer.new()
				desk_body.add_child(row)
				var l := _label("%s — $%d%s\n   → %s" % [it["name"], it["price"], ("  · %d W" % it["watts"]) if it["watts"] > 0 else "", GameState.item_effect(iid)], 14, true)
				l.add_theme_color_override("font_color", INK)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.custom_minimum_size = Vector2(440, 0)
				row.add_child(l)
				var b := Button.new(); b.text = "Add to cart"; b.pressed.connect(cart_add.bind(iid))
				row.add_child(b)
			_dl("Cart: %d item%s ($%d) · You have $%d · Delivery: tomorrow morning" % [cart.size(), "" if cart.size() == 1 else "s", cart_total(), GameState.money], 14)
			if desk_msg != "": _dl(desk_msg, 14, Color(0.6, 0.2, 0.1))
		"cart":
			if cart.is_empty(): _dl("Your cart is empty. Like the rack.")
			for i in cart.size():
				var row := HBoxContainer.new()
				desk_body.add_child(row)
				var it: Dictionary = GameState.CATALOG[cart[i]]
				var l := _label("%s (%s) — $%d" % [it["name"], GameState.SHOPS[it["shop"]], it["price"]], 14, true)
				l.add_theme_color_override("font_color", INK)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.custom_minimum_size = Vector2(440, 0)
				row.add_child(l)
				var b := Button.new(); b.text = "Remove"; b.pressed.connect(func(): cart.remove_at(i); desk_app("cart"))
				row.add_child(b)
			_dl("Total: $%d   ·   Balance: $%d" % [cart_total(), GameState.money], 15)
			var co := Button.new(); co.text = "Checkout (next-day delivery)"; co.pressed.connect(func(): cart_checkout())
			desk_body.add_child(co)
			if desk_msg != "": _dl(desk_msg, 14, Color(0.6, 0.2, 0.1))
		"trophies":
			_dl("Trophies — this week (%d/%d)" % [GameState.achievements.size(), GameState.ACHIEVEMENTS.size()], 16)
			for k in GameState.ACHIEVEMENTS:
				var a: Array = GameState.ACHIEVEMENTS[k]
				var got: bool = k in GameState.achievements
				_dl(("★ %s — %s" if got else "☆ %s — %s (locked)") % [a[0], a[1]], 14, INK if got else Color(0.45, 0.42, 0.4))
			_dl("Speedrun tip: Clean Sprint = work-from-home Monday, take every page, no breaches.", 13, Color(0.35, 0.35, 0.5))
		"farm":
			var r := Button.new(); r.text = "Refresh"; r.pressed.connect(desk_app.bind("farm"))
			desk_body.add_child(r)
			_dl(GameState.farm_status(), 15)
			var bars := ""
			for k in 10: bars += "█" if k < GameState.farm_heat() else "░"
			_dl("Heat  " + bars, 14, Color(0.7, 0.25, 0.15))
			bars = ""
			for k in 10: bars += "█" if k < GameState.farm_noise() else "░"
			_dl("Noise " + bars, 14, Color(0.3, 0.3, 0.6))
			if not GameState.farm_history.is_empty():
				var hist := "This week ($ net per night)\n"
				for h in GameState.farm_history:
					var bar := ""
					for k in clampi(int(h[1]) / 4, 0, 20): bar += "█"
					hist += "%s  %s $%d%s\n" % [GameState.DAY_NAMES[int(h[0])].left(3), bar, int(h[1]), ("   ⚠ outage: " + str(h[3])) if h[3] != "" else ""]
				_dl(hist.strip_edges(), 14, Color(0.2, 0.3, 0.2))
			_dl("Tip: a rack, a switch and the electrician's circuit let more servers run. A UPS keeps blips from becoming outages. Fans fight heat; foam fights Jess's eyebrows.", 14, Color(0.35, 0.3, 0.25))

func _desk_focus() -> void:
	for b in desk_body.find_children("*", "Button", true, false):
		(b as Button).grab_focus(); return
	desk_close_btn.grab_focus()

func _desk_popup(id: String, t: String) -> void:
	desk_app_id = id
	desk_window.visible = true
	desk_tab.visible = true
	for c in desk_body.get_children(): c.free()
	desk_title.text = "BrookOS"
	_dl(t)

func cart_total() -> int:
	var t := 0
	for id in cart: t += int(GameState.CATALOG[id]["price"])
	return t

func cart_add(id: String) -> void:
	cart.append(id)
	desk_msg = "Added: %s." % GameState.CATALOG[id]["name"].split(" (")[0]
	if desktop_open() and desk_app_id != "": desk_app(desk_app_id)

func cart_checkout() -> String:
	var res: String = GameState.checkout(cart)
	if res.begins_with("Order placed"): cart.clear()
	desk_msg = res
	_log(res)
	if desktop_open(): desk_app("cart")
	return res

# ------------------------------------------------------------------ garage assembly (interactive build)
var asm_panel: PanelContainer
var asm_title: Label
var asm_info: Label
var asm_btns: Array[Button] = []
var asm_steps: Array = []       # correct order
var asm_order: Array = []       # display order (indices into asm_steps)
var asm_done := 0
var asm_mistakes := 0
const ASM_STEPS := {"server": ["Slide it into the rack", "Cable power + network", "Power on"], "rack": ["Bolt the frame together", "Level it (ish)", "Anchor it to the wall"],
	"switch": ["Mount the switch", "Patch the servers in", "Power on (cover your ears)"], "ups": ["Connect the battery", "Plug the rack into it", "Self-test"],
	"drives": ["Screw drives into sleds", "Slide them into the bays", "Start the RAID build"], "nic": ["Open the server lid", "Seat the cards", "Plug in the fiber"],
	"fans": ["Zip-tie the fans together", "Aim them at the rack", "Plug in"], "foam": ["Peel the backing", "Stick it to the walls", "Admire the silence"]}

func assembly_open() -> bool:
	return asm_panel != null and asm_panel.visible

func _build_assembly() -> void:
	asm_panel = PanelContainer.new()
	asm_panel.name = "Assembly"
	world_slot.add_child(asm_panel)
	asm_panel.set_anchors_preset(Control.PRESET_CENTER)
	asm_panel.custom_minimum_size = Vector2(620, 0)
	asm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	asm_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	asm_panel.add_child(v)
	asm_title = _label("", 18)
	asm_title.add_theme_color_override("font_color", INK)
	v.add_child(asm_title)
	asm_info = _label("", 14, true)
	asm_info.add_theme_color_override("font_color", INK)
	asm_info.custom_minimum_size = Vector2(600, 0)
	v.add_child(asm_info)
	var h := HBoxContainer.new()
	v.add_child(h)
	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(196, 40)
		b.pressed.connect(assembly_step.bind(i))
		h.add_child(b)
		asm_btns.append(b)
	asm_panel.visible = false

func open_assembly() -> void:
	var id: String = GameState.boxes[0]
	asm_steps = ASM_STEPS.get(id, ["Unbox it", "Install it", "Test it"])
	asm_order = [0, 1, 2]
	var r := (GameState.day * 7 + GameState.boxes.size() * 3 + GameState.minutes) % 3   # shuffled, deterministic
	for k in r: asm_order.push_back(asm_order.pop_front())
	if r == 1: asm_order.reverse()
	asm_done = 0
	asm_mistakes = 0
	asm_title.text = "Build: " + GameState.CATALOG[id]["name"].split(" (")[0]
	if id == "server" and not GameState.notices_seen.has("rails"):
		GameState.notices_seen["rails"] = true
		asm_info.text = "The rails don't fit the rack. Of course they don't. You zip-tie them. It's fine. It's enterprise-grade fine.\n"
	else:
		asm_info.text = ""
	asm_info.text += "Do the steps in the right order (click, or press 1-3). %d more box%s after this." % [GameState.boxes.size() - 1, "" if GameState.boxes.size() == 2 else "es"]
	_asm_refresh()
	asm_panel.visible = true

func _asm_refresh() -> void:
	for i in 3:
		var si: int = asm_order[i]
		asm_btns[i].text = ("✓ " if si < asm_done else "%d  " % (i + 1)) + asm_steps[si]
		asm_btns[i].disabled = si < asm_done

func assembly_step(i: int) -> void:
	if not assembly_open() or i >= 3: return
	var si: int = asm_order[i]
	if si < asm_done: return
	if si != asm_done:
		asm_mistakes += 1
		asm_info.text = ["You can't %s yet. The manual (one diagram, no words) disagrees." % asm_steps[si].to_lower(), "Not yet. A screw rolls under the car. It lives there now.", "Out of order. June, watching from the door: \"Daddy, that's backwards.\""][asm_mistakes % 3]
		return
	asm_done += 1
	_asm_refresh()
	if asm_done >= 3:
		asm_panel.visible = false
		var res: String = GameState.do_action("build_farm")
		_log(res + (" (%d fumble%s)" % [asm_mistakes, "" if asm_mistakes == 1 else "s"] if asm_mistakes > 0 else ""))
		if diorama: diorama.refresh_farm(GameState)
		_refresh_prompt()
	else:
		asm_info.text = "Step %d/3 done: %s." % [asm_done, asm_steps[asm_done - 1]]

func close_assembly() -> void:
	asm_panel.visible = false
	_log("You leave the box for later. It will wait. Boxes are patient.")

## Bot/test helper: does the steps in order.
func assembly_auto() -> void:
	while assembly_open():
		assembly_step(asm_order.find(asm_done))

## Lays containers out now (tests/bots audit right after opening a window, before the next frame).
func relayout(n: Node = null) -> void:
	if n == null: n = world_slot
	if n is Container: (n as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children(): relayout(c)


# ------------------------------------------------------------------ accessibility: text size
var text_scale := 1.0

func set_text_scale(sc: float) -> void:
	text_scale = sc
	apply_text_scale()

## Scales every UI font from its base size (remembered on first visit). Re-run when UI is rebuilt.
func apply_text_scale(n: Node = null) -> void:
	if n == null:
		n = ui
		if n == null: return
	if n is Label or n is Button or n is LineEdit or n is RichTextLabel:
		var c := n as Control
		if not c.has_meta("base_fs"): c.set_meta("base_fs", c.get_theme_font_size("font_size"))
		var fs := int(round(int(c.get_meta("base_fs")) * text_scale))
		if n is RichTextLabel: c.add_theme_font_size_override("normal_font_size", fs)
		else: c.add_theme_font_size_override("font_size", fs)
	for ch in n.get_children(): apply_text_scale(ch)

const SEEN_PATH := "user://seen_scenes.cfg"
func _save_seen() -> void:
	var c := ConfigFile.new()
	c.set_value("seen", "ids", seen_scenes.keys())
	c.set_value("seen", "skip", skip_seen)
	c.save(SEEN_PATH)

func _load_seen() -> void:
	var c := ConfigFile.new()
	if c.load(SEEN_PATH) == OK:
		for k in c.get_value("seen", "ids", []): seen_scenes[str(k)] = true
		skip_seen = bool(c.get_value("seen", "skip", false))
