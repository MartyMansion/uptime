extends Node2D
## House scene for the "One Week" slice. Everything is placeholder ColorRects,
## built in code so the scene file stays trivial.

const SPEED := 260.0
const HOUSE := Rect2(40, 110, 880, 570)

# station id -> rect, color, label, actions (key order = 1, 2)
var stations := {
	"kitchen": {"rect": Rect2(80, 150, 160, 90), "color": Color(0.85, 0.65, 0.3), "label": "Kitchen", "actions": ["feed_girls", "cereal"]},
	"girls": {"rect": Rect2(700, 150, 180, 110), "color": Color(0.9, 0.5, 0.75), "label": "Girls' room", "actions": ["play_girls", "bedtime_story"]},
	"desk": {"rect": Rect2(420, 560, 170, 80), "color": Color(0.35, 0.5, 0.9), "label": "PC desk", "actions": ["work_ticket", "gaming"]},
	"bed": {"rect": Rect2(80, 540, 170, 110), "color": Color(0.5, 0.45, 0.7), "label": "Bed", "actions": ["sleep"]},
}

var dan: ColorRect
var hud_day: Label
var hud_clock: Label
var energy_bar: ProgressBar
var meters := {}
var prompt: Label
var toast: Label
var lifeos_panel: PanelContainer
var lifeos_label: Label
var summary_panel: PanelContainer
var summary_label: Label
var near_station := ""
var modal_open := false

func _ready() -> void:
	_build_house()
	_build_hud()
	GameState.state_changed.connect(_refresh)
	GameState.lifeos_message.connect(show_lifeos)
	GameState.day_ended.connect(_on_day_ended)
	GameState.week_ended.connect(_on_week_ended)
	_refresh()
	show_lifeos("LifeOS: Good morning, Dan! You have 37 blocks, 0 of which are yours. Let's optimize!")

func _build_house() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.15)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.32, 0.27, 0.22)
	floor_rect.position = HOUSE.position
	floor_rect.size = HOUSE.size
	add_child(floor_rect)
	for id in stations:
		var s: Dictionary = stations[id]
		var r: Rect2 = s["rect"]
		var c := ColorRect.new()
		c.color = s["color"]
		c.position = r.position
		c.size = r.size
		add_child(c)
		var l := Label.new()
		l.text = s["label"]
		l.position = r.position + Vector2(8, 6)
		l.add_theme_color_override("font_color", Color.BLACK)
		add_child(l)
	dan = ColorRect.new()
	dan.color = Color(0.3, 0.85, 0.4)
	dan.size = Vector2(28, 40)
	dan.position = Vector2(460, 380)
	add_child(dan)
	var dl := Label.new()
	dl.text = "Dan"
	dl.position = Vector2(0, -22)
	dan.add_child(dl)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_day = Label.new()
	hud_day.position = Vector2(40, 12)
	hud_day.add_theme_font_size_override("font_size", 26)
	layer.add_child(hud_day)
	hud_clock = Label.new()
	hud_clock.position = Vector2(40, 50)
	hud_clock.add_theme_font_size_override("font_size", 22)
	layer.add_child(hud_clock)
	var el := Label.new()
	el.text = "Energy"
	el.position = Vector2(320, 20)
	layer.add_child(el)
	energy_bar = ProgressBar.new()
	energy_bar.position = Vector2(390, 20)
	energy_bar.size = Vector2(300, 26)
	layer.add_child(energy_bar)
	var y := 120
	for key in ["Stress", "Job Performance", "Jess: Closeness", "Girls: Fed", "Girls: Connected"]:
		var lab := Label.new()
		lab.position = Vector2(950, y)
		lab.text = key
		layer.add_child(lab)
		var bar := ProgressBar.new()
		bar.position = Vector2(950, y + 22)
		bar.size = Vector2(290, 20)
		layer.add_child(bar)
		meters[key] = bar
		y += 60
	var help := Label.new()
	help.position = Vector2(950, 440)
	help.text = "WASD/Arrows: move\n1 / 2: station action\nT: text Jess (phone)\nEnter/Space: dismiss popups"
	layer.add_child(help)
	prompt = Label.new()
	prompt.position = Vector2(40, 684)
	prompt.add_theme_font_size_override("font_size", 18)
	layer.add_child(prompt)
	toast = Label.new()
	toast.position = Vector2(950, 560)
	toast.size = Vector2(300, 140)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(toast)
	# LifeOS popup (top-right phone notification)
	lifeos_panel = PanelContainer.new()
	lifeos_panel.position = Vector2(720, 12)
	lifeos_panel.custom_minimum_size = Vector2(540, 80)
	lifeos_label = Label.new()
	lifeos_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lifeos_label.custom_minimum_size = Vector2(520, 0)
	lifeos_panel.add_child(lifeos_label)
	lifeos_panel.visible = false
	layer.add_child(lifeos_panel)
	# Day-end summary (modal)
	summary_panel = PanelContainer.new()
	summary_panel.position = Vector2(240, 140)
	summary_panel.custom_minimum_size = Vector2(800, 440)
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.custom_minimum_size = Vector2(780, 0)
	summary_label.add_theme_font_size_override("font_size", 18)
	summary_panel.add_child(summary_label)
	summary_panel.visible = false
	layer.add_child(summary_panel)

func _process(delta: float) -> void:
	if modal_open:
		return
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	if dir != Vector2.ZERO:
		dan.position += dir.normalized() * SPEED * delta
		dan.position.x = clampf(dan.position.x, HOUSE.position.x, HOUSE.end.x - dan.size.x)
		dan.position.y = clampf(dan.position.y, HOUSE.position.y, HOUSE.end.y - dan.size.y)
	_update_near()

func _update_near() -> void:
	var c := dan.position + dan.size / 2
	var found := ""
	for id in stations:
		var r: Rect2 = stations[id]["rect"]
		if r.grow(40).has_point(c):
			found = id
	if found != near_station:
		near_station = found
		_refresh_prompt()

func _refresh_prompt() -> void:
	if near_station == "":
		prompt.text = "Walk to a station (Kitchen, Girls' room, PC desk, Bed). T texts Jess from anywhere."
		return
	var parts: Array[String] = []
	var i := 1
	for aid in stations[near_station]["actions"]:
		var a: Dictionary = GameState.ACTIONS[aid]
		var cost := "%d min, %+d energy" % [int(a["blocks"]) * GameState.BLOCK, int(a["energy"])]
		if aid == "sleep":
			cost = "ends the day"
		var blocked := GameState.can_do(aid)
		parts.append("[%d] %s (%s)%s" % [i, a["name"], cost, "  ✗ " + blocked if blocked != "" else ""])
		i += 1
	prompt.text = "   ".join(parts)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: Key = (event as InputEventKey).keycode
	if modal_open or lifeos_panel.visible:
		if k == KEY_ENTER or k == KEY_SPACE or k == KEY_KP_ENTER:
			if summary_panel.visible and not GameState.week_over:
				summary_panel.visible = false
				modal_open = false
			elif summary_panel.visible and GameState.week_over:
				GameState.new_game()
				summary_panel.visible = false
				modal_open = false
			else:
				lifeos_panel.visible = false
			return
		if modal_open:
			return
	if k == KEY_T:
		perform("text_jess")
	elif (k == KEY_1 or k == KEY_2) and near_station != "":
		var idx := 0 if k == KEY_1 else 1
		var acts: Array = stations[near_station]["actions"]
		if idx < acts.size():
			perform(acts[idx])

func perform(aid: String) -> void:
	toast.text = GameState.do_action(aid)
	_refresh_prompt()

func show_lifeos(text: String) -> void:
	lifeos_label.text = "📱 " + text + "\n[Enter to dismiss]"
	lifeos_panel.visible = true

func _on_day_ended(s: Dictionary) -> void:
	summary_label.text = "END OF %s\n\nBedtime: %s\n%s\nTickets closed: %d\nThoughtful texts to Jess: %d\nBedtime story: %s\nKid moments: %d\nEnergy: %d -> %d\n\n[Enter] Next day" % [
		str(s["day"]).to_upper(), s["bed_time"], s["sleep_text"], s["tickets"], s["texts"],
		"Attended" if s["bedtime"] else "Missed (Mommy already did the voices)", s["kid_actions"], s["energy_before"], s["energy_after"]]
	summary_panel.visible = true
	modal_open = true
	dan.position = Vector2(180, 500)

func _on_week_ended(review: String) -> void:
	summary_label.text = review + "\n\n[Enter] Play the week again"
	summary_panel.visible = true
	modal_open = true

func _refresh() -> void:
	hud_day.text = "%s — Day %d/7" % [GameState.day_name(), GameState.day + 1]
	hud_clock.text = GameState.clock_text() + ("   RUNNING ON FUMES" if GameState.is_on_fumes() else "")
	energy_bar.value = GameState.energy
	meters["Stress"].value = GameState.stress
	meters["Job Performance"].value = GameState.performance
	meters["Jess: Closeness"].value = GameState.closeness
	meters["Girls: Fed"].value = GameState.girls_fed
	meters["Girls: Connected"].value = GameState.girls_connected
	_refresh_prompt()
