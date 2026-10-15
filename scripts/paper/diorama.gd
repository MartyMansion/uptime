class_name Diorama
extends Node3D
## The presentation layer: turns the current Location (logic: stations, spots, solids, actors in a
## 320x200 plan) into a cardboard diorama with paper-card characters and a Paper Mario-style
## follow camera. Game logic never reads anything from here; it only mirrors the Location.
## Plan px -> metres: x right, plan y = depth (towards the camera).

const S := 0.05
const WALL_H := 4.8
const LIP := 260.0            # floor/stage lip extends to plan y=260 (in front of the walkable area)
const XW := 8.3               # inner side-wall x
const CAM_FOV := 32.0
const CAM_PITCH := -21.0
const CAM_OFF := Vector3(0, 5.6, 11.0)
const INK := Color(0.12, 0.1, 0.1)
const FLOOR_COLS := {
	"floor_wood": Color(0.74, 0.52, 0.34), "floor_kitchen": Color(0.93, 0.89, 0.76), "floor_carpet_pink": Color(0.93, 0.66, 0.72),
	"floor_office": Color(0.55, 0.58, 0.64), "grass": Color(0.5, 0.72, 0.4), "sidewalk": Color(0.8, 0.79, 0.74),
	"asphalt": Color(0.33, 0.33, 0.36), "road_lane": Color(0.3, 0.3, 0.33), "wall": Color(0.96, 0.86, 0.62), "wall_office": Color(0.78, 0.8, 0.74),
}
const SET_LIGHT := {   # set -> [ambient, sun colour, card tint]
	"house": [Color(0.78, 0.68, 0.6), Color(1, 0.85, 0.66), Color(1.0, 0.95, 0.86)],
	"office": [Color(0.7, 0.74, 0.78), Color(0.92, 0.96, 1.0), Color(0.95, 0.97, 1.0)],
	"gas_station": [Color(0.78, 0.72, 0.66), Color(1, 0.9, 0.72), Color(1.0, 0.96, 0.88)],
	"school": [Color(0.8, 0.8, 0.78), Color(1, 0.95, 0.82), Color(1.0, 0.98, 0.92)],
}
const PLACE_SETS := ["park", "pharmacy", "dental", "diner", "coffee", "school", "home", "gas"]

var main: Node                 # Main (for talk/flap + GameState); optional in tests
var set_name := ""
var place := ""
var set_root: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var lamp: OmniLight3D
var env: Environment
var cards := {}                # name -> PaperCard (persist across sets)
var _vis_off := {}             # name -> visual x offset (auto-spacing)
var tag: Label3D               # proximity prompt
var tag_arrow: MeshInstance3D
var fridge_root: Node3D
var plant_node: Node3D
var clock_hands: Array = []
var signs: Array[Label3D] = []
var zb := -4.2                 # back wall front face z
var stage_tint := Color(1, 0.95, 0.86)
var _mats := {}
var _font: Font
var _drawings: Texture2D
var _last_pos := {}
var cam_x_range := Vector2(-2.6, 2.6)
var flips_total := 0
var flap_frames := 0
var flap_while_idle := 0

func _ready() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.15, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	we.environment = env
	add_child(we)
	cam = Camera3D.new()
	cam.fov = CAM_FOV
	cam.rotation_degrees.x = CAM_PITCH
	cam.position = CAM_OFF
	cam.current = true
	add_child(cam)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 28, 0)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.45
	add_child(sun)
	lamp = OmniLight3D.new()
	lamp.position = Vector3(0, 3.6, 1.0)
	lamp.light_color = Color(1, 0.74, 0.48)
	lamp.omni_range = 14
	add_child(lamp)
	tag = Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 44
	tag.pixel_size = 0.006
	tag.modulate = INK
	tag.outline_modulate = Color(1, 0.97, 0.86)
	tag.outline_size = 18
	tag.no_depth_test = true
	tag.visible = false
	add_child(tag)
	tag_arrow = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.3, 0.3, 0.05)
	tag_arrow.mesh = pm
	tag_arrow.rotation_degrees.z = 180
	tag_arrow.material_override = mat(Color(1, 0.78, 0.25))
	tag_arrow.visible = false
	add_child(tag_arrow)
	_drawings = load("res://assets/paper/drawings.png")

# ------------------------------------------------------------ helpers
func to3(p: Vector2) -> Vector3:
	return Vector3((p.x - 160.0) * S, 0.0, (p.y - 100.0) * S)

func mat(c: Color, glow := 0.0) -> ShaderMaterial:
	var k := "%s/%s" % [c.to_html(), glow]
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/paper.gdshader")
		m.set_shader_parameter("col", c)
		m.set_shader_parameter("glow", glow)
		_mats[k] = m
	return _mats[k]

func slab(p: Vector3, s: Vector3, c: Color, parent: Node3D = null, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = s
	mi.mesh = b
	mi.material_override = mat(c, glow)
	mi.position = p
	(parent if parent else set_root).add_child(mi)
	return mi

## A box standing on the floor, given its plan footprint rect.
func block(r: Rect2, h: float, c: Color, y0 := 0.0) -> MeshInstance3D:
	var a := to3(r.position)
	var b := to3(r.end)
	return slab(Vector3((a.x + b.x) / 2, y0 + h / 2, (a.z + b.z) / 2), Vector3(absf(b.x - a.x), h, absf(b.z - a.z)), c)

## Flat cut-out standee (tree, plant, sign) facing the camera.
func standee(p: Vector3, w: float, h: float, c: Color) -> MeshInstance3D:
	return slab(p + Vector3(0, h / 2, 0), Vector3(w, h, 0.05), c)

func text3(t: String, p: Vector3, size := 48, col := INK, width := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font_size = size
	l.pixel_size = 0.005
	l.modulate = col
	l.outline_size = 0
	l.position = p
	l.double_sided = false
	if width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width / l.pixel_size
	set_root.add_child(l)
	signs.append(l)
	return l

## A wall sign: coloured board + lettering, on the back wall (plan x centre, height y).
func wall_sign(x: float, y: float, w: float, h: float, board: Color, t: String, tcol := INK, size := 44) -> void:
	var p := Vector3((x - 160.0) * S, y, zb + 0.04)
	slab(p + Vector3(0.06, -0.06, -0.01), Vector3(w, h, 0.03), INK)
	slab(p, Vector3(w, h, 0.05), board)
	text3(t, p + Vector3(0, 0, 0.04), size, tcol, w * 0.92)

# ------------------------------------------------------------ build
func clear() -> void:
	if set_root:
		set_root.free()
	set_root = Node3D.new()
	set_root.name = "Set"
	add_child(set_root)
	signs.clear()
	clock_hands.clear()
	fridge_root = null
	plant_node = null

## Builds the set for a Location. `place_id` picks a town-map destination set while driving.
func build(loc: Location, loc_name: String, place_id := "") -> void:
	clear()
	set_name = loc_name
	place = place_id
	zb = -4.2
	var lt: Array = SET_LIGHT.get(loc_name, SET_LIGHT["house"])
	if place_id != "" and place_id in ["park", "pharmacy", "dental", "diner", "coffee"]:
		_build_place(place_id)
		lt = SET_LIGHT["school"] if place_id == "park" else SET_LIGHT["house"]
	else:
		_build_from_plan(loc)
		match loc_name:
			"house": _dress_house()
			"office": _dress_office()
			"gas_station": _dress_gas()
			"school": _dress_school()
	env.ambient_light_color = lt[0]
	sun.light_color = lt[1]
	stage_tint = lt[2]
	_enclose(loc_name == "school" or place_id == "park")
	for n in cards:
		cards[n].visible = false
	_snap_camera()

func _build_from_plan(loc: Location) -> void:
	var outdoor := false
	for it in loc.layout:
		if it[0] == "tile":
			var n: String = it[1]
			var r: Rect2 = it[2]
			var z: int = it[3]
			if n in ["grass", "asphalt"]: outdoor = true
			if (n == "wall" or n == "wall_office") and z == -10:
				continue   # the back strip: replaced by the tall back wall
			if z == -9:
				_partition(r, FLOOR_COLS.get(n, Color(0.9, 0.85, 0.7)))
			else:
				_floor(n, r)
	# back wall front face at the bottom of the plan's top strip (y=16) indoors, y=0 outdoors
	zb = to3(Vector2(0, 16 if not outdoor else 0)).z
	for it in loc.layout:
		if it[0] == "prop":
			_prop(it[1], it[2], it[3], it[4])

func _floor(n: String, r: Rect2) -> void:
	var c: Color = FLOOR_COLS.get(n, Color(0.7, 0.6, 0.5))
	var rr := r
	if rr.end.y >= 199.0: rr.size.y += LIP - 200.0      # extend to the stage lip
	var m := block(rr, 0.1, c, -0.1)
	match n:
		"floor_wood":
			var a := to3(rr.position); var b := to3(rr.end)
			var x := a.x + 0.8
			while x < b.x:
				slab(Vector3(x, 0.003, (a.z + b.z) / 2), Vector3(0.025, 0.006, b.z - a.z), c.darkened(0.18))
				x += 0.8
		"floor_kitchen":
			var a := to3(rr.position); var b := to3(rr.end)
			for i in int((b.x - a.x) / 0.6):
				for j in int((b.z - a.z) / 0.6):
					if (i + j) % 2 == 0:
						slab(Vector3(a.x + 0.3 + i * 0.6, 0.003, a.z + 0.3 + j * 0.6), Vector3(0.58, 0.006, 0.58), Color(0.55, 0.75, 0.74))
		"road_lane":
			var a := to3(rr.position); var b := to3(r.end)
			var x := a.x + 0.4
			while x < b.x:
				slab(Vector3(x, 0.004, (a.z + b.z) / 2), Vector3(0.9, 0.008, 0.12), Color(0.98, 0.85, 0.3))
				x += 1.8
	return

func _partition(r: Rect2, c: Color) -> void:
	# Dollhouse cut-away: walls running across the view are knee-high so nobody hides behind them;
	# walls running into the screen are taller (they don't block the camera).
	var across := r.size.x > r.size.y
	var h := 0.55 if across else 1.6
	block(r, h, c.darkened(0.05))
	var top := block(Rect2(r.position - Vector2(0.5, 0.5), r.size + Vector2(1, 1)), 0.05, c.lightened(0.25), h)
	top.name = "WallCap"

## Props from the plan, as cardboard constructions. Footprint = the solid part of the 2D sprite.
func _prop(n: String, pos: Vector2, sz: Vector2, flat: bool) -> void:
	var foot := Rect2(pos.x + 1, pos.y + sz.y * 0.45, sz.x - 2, sz.y * 0.55)
	var c3 := to3(foot.get_center())
	match n:
		"bed_double", "bed_kid":
			var quilt := Color(0.55, 0.62, 0.85) if n == "bed_double" else Color(0.98, 0.7, 0.8)
			var f2 := Rect2(pos.x + 1, pos.y + 4, sz.x - 2, sz.y - 6)
			block(f2, 0.3, Color(0.6, 0.42, 0.28))
			block(f2.grow(-1), 0.16, quilt, 0.3)
			block(Rect2(f2.position.x + 2, f2.position.y + 1, f2.size.x - 4, 7), 0.14, Color(0.98, 0.97, 0.94), 0.38)
			block(Rect2(f2.position.x, f2.position.y - 2, f2.size.x, 2), 1.0, Color(0.5, 0.34, 0.22))
		"kitchen_counter":
			block(foot, 0.92, Color(0.56, 0.4, 0.3))
			block(foot.grow(0.6), 0.06, Color(0.9, 0.88, 0.82), 0.92)
			slab(c3 + Vector3(-0.6, 1.18, -0.1), Vector3(0.36, 0.46, 0.3), Color(0.22, 0.22, 0.24))    # coffee maker
			slab(c3 + Vector3(-0.6, 1.0, 0.12), Vector3(0.12, 0.14, 0.12), Color(0.95, 0.95, 0.95))   # mug
			slab(c3 + Vector3(0.7, 1.0, 0.0), Vector3(0.5, 0.08, 0.35), Color(0.75, 0.75, 0.78))     # stove top
			for i in 3: slab(c3 + Vector3(-1.0 + i * 0.9, 0.55, foot.size.y * S * 0.5 + 0.01), Vector3(0.7, 0.6, 0.02), Color(0.62, 0.46, 0.35))
		"fridge":
			var f := Rect2(pos.x, pos.y + 8, sz.x, sz.y - 8)
			block(f, 2.0, Color(0.93, 0.95, 0.96))
			var front := to3(Vector2(f.get_center().x, f.end.y))
			slab(Vector3(front.x, 1.35, front.z + 0.01), Vector3(f.size.x * S, 0.03, 0.02), Color(0.7, 0.72, 0.75))
			slab(Vector3(front.x + 0.28, 1.0, front.z + 0.03), Vector3(0.04, 0.4, 0.04), Color(0.7, 0.72, 0.75))
			fridge_root = Node3D.new()
			fridge_root.position = Vector3(front.x, 0, front.z + 0.035)
			set_root.add_child(fridge_root)
		"table":
			block(Rect2(foot.position + Vector2(-2, -4), foot.size + Vector2(4, 4)), 0.06, Color(0.66, 0.46, 0.3), 0.72)
			for dx in [-0.6, 0.6]:
				slab(c3 + Vector3(dx, 0.36, -0.05), Vector3(0.08, 0.72, 0.08), Color(0.5, 0.34, 0.22))
			slab(c3 + Vector3(-0.3, 0.8, -0.1), Vector3(0.3, 0.04, 0.3), Color(1, 1, 1))     # plates
			slab(c3 + Vector3(0.35, 0.8, -0.1), Vector3(0.3, 0.04, 0.3), Color(1, 1, 1))
			slab(c3 + Vector3(0.0, 0.86, -0.15), Vector3(0.14, 0.18, 0.14), Color(0.95, 0.85, 0.3))  # juice
		"bookshelf":
			var f := Rect2(pos.x, pos.y + 10, sz.x, sz.y - 14)
			block(f, 1.8, Color(0.55, 0.38, 0.25))
			var fr := to3(Vector2(f.get_center().x, f.end.y))
			var bc := [Color(0.85, 0.3, 0.3), Color(0.3, 0.55, 0.85), Color(0.95, 0.8, 0.3), Color(0.4, 0.7, 0.45)]
			for row in 3:
				for k in 5:
					slab(Vector3(fr.x - 0.45 + k * 0.22, 0.32 + row * 0.55, fr.z + 0.02), Vector3(0.16, 0.36 - 0.05 * (k % 2), 0.05), bc[(k + row) % 4])
		"toys":
			for k in 4:
				slab(c3 + Vector3(-0.3 + k * 0.22, 0.09 + 0.18 * int(k == 2), 0.1 * (k % 2)), Vector3(0.18, 0.18, 0.18), [Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.9), Color(0.95, 0.8, 0.25), Color(0.4, 0.75, 0.4)][k])
		"rug":
			block(Rect2(pos, sz), 0.02, Color(0.82, 0.42, 0.36))
			block(Rect2(pos + Vector2(3, 3), sz - Vector2(6, 6)), 0.025, Color(0.95, 0.75, 0.45))
		"tv_stand":
			block(Rect2(pos.x, pos.y, sz.x, sz.y), 0.45, Color(0.4, 0.3, 0.24))
			var tv := slab(to3(Vector2(pos.x + sz.x / 2, pos.y + 3)) + Vector3(0, 0.74, 0), Vector3(1.0, 0.56, 0.06), Color(0.12, 0.14, 0.18), null, 0.1)
			tv.name = "TV"
		"couch":
			var f := Rect2(pos.x, pos.y + 2, sz.x, sz.y - 2)
			block(f, 0.45, Color(0.42, 0.52, 0.68))
			block(Rect2(f.position.x, f.end.y - 5, f.size.x, 5), 0.9, Color(0.36, 0.46, 0.62))       # back faces the camera
			block(Rect2(f.position.x - 2, f.position.y, 3, f.size.y), 0.65, Color(0.36, 0.46, 0.62))
			block(Rect2(f.end.x - 1, f.position.y, 3, f.size.y), 0.65, Color(0.36, 0.46, 0.62))
			slab(to3(Vector2(f.position.x + 10, f.end.y - 6)) + Vector3(0, 0.62, 0), Vector3(0.4, 0.34, 0.12), Color(0.95, 0.8, 0.35))  # cushion
		"pc_desk", "office_desk":
			var top := block(Rect2(foot.position - Vector2(1, 3), foot.size + Vector2(2, 3)), 0.06, Color(0.62, 0.45, 0.3), 0.74)
			top.name = "Desk"
			for dx in [-0.65, 0.65]:
				slab(c3 + Vector3(dx, 0.37, 0), Vector3(0.06, 0.74, foot.size.y * S * 0.8), Color(0.45, 0.32, 0.22))
			var mon := slab(c3 + Vector3(-0.05, 1.12, -0.15), Vector3(0.7, 0.45, 0.05), Color(0.16, 0.42, 0.26), null, 0.18)
			mon.name = "Monitor"
			slab(c3 + Vector3(-0.05, 0.86, -0.15), Vector3(0.08, 0.1, 0.08), Color(0.2, 0.2, 0.22))
			slab(c3 + Vector3(-0.05, 0.78, 0.12), Vector3(0.5, 0.03, 0.16), Color(0.85, 0.85, 0.82))  # keyboard
			if n == "office_desk":
				slab(c3 + Vector3(0.55, 0.85, 0.05), Vector3(0.12, 0.16, 0.12), Color(1, 1, 1))
		"plant":
			slab(c3 + Vector3(0, 0.2, 0), Vector3(0.4, 0.4, 0.4), Color(0.78, 0.45, 0.3))
			var pl := Node3D.new()
			pl.position = c3 + Vector3(0, 0.4, 0)
			set_root.add_child(pl)
			for k in 3:
				var leaf := slab(Vector3(-0.15 + k * 0.15, 0.3 + 0.08 * (k % 2), 0), Vector3(0.22, 0.6, 0.04), Color(0.32, 0.62, 0.34), pl)
				leaf.rotation.z = -0.4 + k * 0.4
			if pos.x > 280:
				plant_node = pl
		"door":
			# the front door is on the camera side: shown as a doormat + an arrow sign (doesn't block the view)
			block(Rect2(pos.x - 4, pos.y + 18, sz.x + 8, 10), 0.02, Color(0.55, 0.38, 0.25))
			var d := text3("⇩ OUT", to3(Vector2(pos.x + sz.x / 2, pos.y + 23)) + Vector3(0, 0.03, 0), 40, Color(0.98, 0.92, 0.75))
			d.rotation_degrees.x = -90
		"server_rack":
			var f := Rect2(pos.x, pos.y + 8, sz.x, sz.y - 10)
			block(f, 2.1, Color(0.15, 0.16, 0.19))
			var fr := to3(Vector2(f.get_center().x, f.end.y))
			var leds := [Color(0.2, 1, 0.3), Color(1, 0.7, 0.1), Color(1, 0.2, 0.2)]
			for k in 8:
				slab(Vector3(fr.x, 0.3 + k * 0.22, fr.z + 0.01), Vector3(0.62, 0.14, 0.02), Color(0.3, 0.32, 0.36))
				slab(Vector3(fr.x + 0.22, 0.3 + k * 0.22, fr.z + 0.025), Vector3(0.06, 0.06, 0.02), leds[(int(pos.x) / 18 + k) % 3], null, 1.0)
		"printer":
			block(foot.grow(1), 0.85, Color(0.9, 0.9, 0.86))
			slab(c3 + Vector3(0, 0.9, 0), Vector3(0.6, 0.06, 0.3), Color(1, 1, 1))
			var t := text3("PC LOAD\nLETTER", c3 + Vector3(0, 0.55, foot.size.y * S * 0.5 + 0.08), 22, Color(0.2, 0.7, 0.3))
			t.name = "PrinterLCD"
		"water_cooler":
			block(foot, 0.9, Color(0.85, 0.86, 0.88))
			slab(c3 + Vector3(0, 1.15, 0), Vector3(0.35, 0.5, 0.35), Color(0.55, 0.78, 0.95))
		"office_sign":
			pass   # lettered in _dress_office
		"gas_sign":
			pass
		"beer_cooler":
			var f := Rect2(pos.x, pos.y + 6, sz.x, sz.y - 8)
			block(f, 2.0, Color(0.85, 0.87, 0.9))
			var fr := to3(Vector2(f.get_center().x, f.end.y))
			slab(Vector3(fr.x, 1.05, fr.z + 0.02), Vector3(f.size.x * S - 0.2, 1.6, 0.02), Color(0.6, 0.85, 0.95), null, 0.25)
			for row in 3:
				for k in 6:
					slab(Vector3(fr.x - 0.75 + k * 0.3, 0.5 + row * 0.5, fr.z - 0.1), Vector3(0.18, 0.3, 0.18), [Color(0.85, 0.65, 0.2), Color(0.3, 0.45, 0.8), Color(0.8, 0.25, 0.25)][(k + row) % 3])
			text3("COLD ONES", Vector3(fr.x, 2.15, fr.z + 0.05), 30, Color(0.2, 0.3, 0.6))
		"store_counter":
			block(foot.grow(1), 1.0, Color(0.7, 0.3, 0.28))
			block(foot.grow(2), 0.05, Color(0.92, 0.9, 0.85), 1.0)
			slab(c3 + Vector3(0.4, 1.2, 0), Vector3(0.4, 0.3, 0.3), Color(0.2, 0.2, 0.2))   # register
			slab(c3 + Vector3(-0.5, 1.15, 0.05), Vector3(0.5, 0.25, 0.2), Color(0.95, 0.75, 0.3))  # jerky
		"gas_pump":
			var f := Rect2(pos.x, pos.y + 12, sz.x, sz.y - 14)
			block(f, 1.5, Color(0.9, 0.3, 0.25))
			var fr := to3(Vector2(f.get_center().x, f.end.y))
			slab(Vector3(fr.x, 1.15, fr.z + 0.02), Vector3(0.45, 0.3, 0.02), Color(0.2, 0.25, 0.2), null, 0.3)
		"car":
			var f := Rect2(pos.x, pos.y + 2, sz.x, sz.y - 4)
			block(f, 0.7, Color(0.36, 0.55, 0.78), 0.2)
			block(Rect2(f.position.x + 3, f.position.y + 10, f.size.x - 6, f.size.y - 22), 0.5, Color(0.6, 0.82, 0.95), 0.9)
			for wy in [f.position.y + 6, f.end.y - 8]:
				for wx in [f.position.x - 1, f.end.x - 1]:
					var w := slab(to3(Vector2(wx, wy)) + Vector3(0.05, 0.25, 0), Vector3(0.12, 0.5, 0.5), INK)
					w.name = "Wheel"
		"school_front":
			var f := Rect2(pos.x, pos.y, sz.x, 30)
			block(f, 3.6, Color(0.82, 0.42, 0.34))
			var fr := to3(Vector2(f.get_center().x, f.end.y))
			for k in 4:
				slab(Vector3(fr.x - 2.4 + k * 1.6, 2.4, fr.z + 0.02), Vector3(0.9, 0.7, 0.03), Color(0.65, 0.85, 0.95))
			slab(Vector3(fr.x, 0.9, fr.z + 0.02), Vector3(1.2, 1.8, 0.03), Color(0.45, 0.3, 0.22))
			slab(Vector3(fr.x, 3.2, fr.z + 0.04), Vector3(4.6, 0.5, 0.04), Color(0.98, 0.95, 0.85))
			text3("BROOKFIELD ELEMENTARY", Vector3(fr.x, 3.2, fr.z + 0.08), 44)
			text3("Go Beavers! (Please slow down)", Vector3(fr.x, 0.4, fr.z + 0.12) + Vector3(2.6, 0, 0.2), 24, Color(0.2, 0.3, 0.6))
		"tree":
			var p := to3(Vector2(pos.x + sz.x / 2, pos.y + sz.y - 2))
			standee(p, 0.3, 1.6, Color(0.5, 0.35, 0.22))
			var crown := slab(p + Vector3(0, 2.1, 0), Vector3(1.7, 1.4, 0.06), Color(0.32, 0.6, 0.34))
			crown.rotation.z = 0.05
			slab(p + Vector3(0.1, 2.5, 0.02), Vector3(1.1, 0.9, 0.06), Color(0.4, 0.7, 0.4))
		_:
			if not flat:
				block(foot, 0.8, Color(0.7, 0.6, 0.5))

# ------------------------------------------------------------ set dressing (signs, back walls, foreground)
func _back_wall(col: Color, h := WALL_H) -> void:
	slab(Vector3(0, h / 2, zb - 0.1), Vector3(XW * 2 + 0.6, h, 0.2), col)
	slab(Vector3(0, 0.15, zb + 0.02), Vector3(XW * 2, 0.3, 0.06), col.darkened(0.2))         # skirting
	slab(Vector3(0, h - 0.12, zb + 0.02), Vector3(XW * 2, 0.24, 0.08), col.darkened(0.12))   # crown moulding

func _window(x: float, y: float, w: float, h: float, sky := Color(0.62, 0.84, 0.96)) -> void:
	var p := Vector3((x - 160) * S, y, zb + 0.03)
	slab(p, Vector3(w + 0.16, h + 0.16, 0.04), Color(1, 1, 1))
	slab(p + Vector3(0, 0, 0.02), Vector3(w, h, 0.04), sky)
	slab(p + Vector3(0, 0, 0.05), Vector3(0.06, h, 0.03), Color(1, 1, 1))
	slab(p + Vector3(0, 0, 0.05), Vector3(w, 0.06, 0.03), Color(1, 1, 1))
	slab(p + Vector3(w * 0.25, -h * 0.2, 0.045), Vector3(w * 0.3, h * 0.2, 0.02), Color(0.97, 0.98, 1.0))   # paper cloud

func _clock(x: float, y: float) -> void:
	var p := Vector3((x - 160) * S, y, zb + 0.04)
	var face := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.32; cy.bottom_radius = 0.32; cy.height = 0.05
	face.mesh = cy
	face.material_override = mat(Color(0.99, 0.97, 0.9))
	face.rotation_degrees.x = 90
	face.position = p
	set_root.add_child(face)
	for i in 2:
		var hand := Node3D.new()
		hand.position = p + Vector3(0, 0, 0.05 + 0.01 * i)
		set_root.add_child(hand)
		slab(Vector3(0, [0.1, 0.14][i], 0), Vector3(0.04, [0.2, 0.28][i], 0.01), INK, hand)
		clock_hands.append(hand)

func _foreground(items: Array) -> void:
	# low cut-outs on the stage lip (plan y 204-250): fill the empty floor without hiding anyone
	for it in items:
		var p := to3(Vector2(it[0], it[1]))
		var s: Vector3 = it[2]
		var m := slab(p + Vector3(0, s.y / 2, 0), s, it[3])
		m.name = "Foreground"
		if it.size() > 4:
			var l := text3(it[4], p + Vector3(0, s.y * 0.5, s.z / 2 + 0.02), 26, it[5] if it.size() > 5 else INK)
			l.name = "ForegroundLabel"

func _dress_house() -> void:
	_back_wall(FLOOR_COLS["wall"])
	_window(48, 2.4, 1.8, 1.2)
	_window(270, 2.5, 1.6, 1.1, Color(0.7, 0.86, 0.98))
	wall_sign(160, 3.0, 2.0, 0.5, Color(0.9, 0.32, 0.26), "LIVE LAUGH LOG", Color(1, 0.98, 0.92), 44)
	_clock(112, 2.7)
	# family photo
	slab(Vector3((215 - 160) * S, 2.4, zb + 0.03), Vector3(0.7, 0.55, 0.04), Color(0.45, 0.3, 0.2))
	slab(Vector3((215 - 160) * S, 2.4, zb + 0.06), Vector3(0.56, 0.42, 0.03), Color(0.95, 0.88, 0.7))
	for k in 4:
		slab(Vector3((215 - 160) * S - 0.18 + k * 0.12, 2.36, zb + 0.085), Vector3(0.08, 0.2 - 0.04 * int(k > 1), 0.01), [Color(0.36, 0.42, 0.52), Color(0.52, 0.74, 0.6), Color(0.95, 0.56, 0.7), Color(1, 0.8, 0.26)][k])
	text3("Mercer HQ", Vector3((270 - 160) * S, 1.65, zb + 0.06), 26, Color(0.5, 0.3, 0.3))
	_foreground([
		[30, 214, Vector3(0.9, 0.42, 0.6), Color(0.86, 0.8, 0.62), "LAUNDRY (day 4)"],
		[96, 222, Vector3(0.5, 0.22, 0.3), Color(0.9, 0.32, 0.3)],
		[110, 226, Vector3(0.3, 0.16, 0.4), Color(0.3, 0.55, 0.9)],
		[222, 216, Vector3(1.1, 0.3, 0.5), Color(0.6, 0.42, 0.3), "SHOES (a postmortem)", Color(1, 0.95, 0.85)],
		[300, 222, Vector3(0.5, 0.5, 0.5), Color(0.95, 0.8, 0.3)],
	])

func _dress_office() -> void:
	_back_wall(FLOOR_COLS["wall_office"])
	wall_sign(64, 2.95, 3.6, 0.6, Color(1, 1, 1), "TRICOUNTY IT · 0 DAYS SINCE LAST INCIDENT", INK, 34)
	wall_sign(150, 2.3, 1.4, 0.9, Color(0.98, 0.98, 0.95), "TICKET QUEUE\n▇▇▇▇▇▇▇▇ ∞", Color(0.2, 0.3, 0.6), 26)
	wall_sign(202, 2.9, 1.6, 0.5, Color(0.85, 0.2, 0.2), "THE CLOUD IS\nSOMEONE ELSE'S PC", Color(1, 1, 1), 22)
	wall_sign(276, 2.95, 1.8, 0.45, Color(0.2, 0.25, 0.3), "SERVER ROOM · AUTHORIZED DADS ONLY", Color(0.6, 1, 0.6), 22)
	_window(110, 2.5, 1.5, 1.0, Color(0.7, 0.8, 0.88))
	_clock(20, 2.6)
	var blue := OmniLight3D.new()
	blue.position = Vector3((275 - 160) * S, 2.2, -2.2)
	blue.light_color = Color(0.5, 0.8, 1)
	blue.light_energy = 0.9
	blue.omni_range = 5
	set_root.add_child(blue)
	_foreground([
		[40, 214, Vector3(1.4, 0.25, 0.4), Color(0.3, 0.33, 0.38), "CABLES (do not)", Color(0.85, 0.85, 0.85)],
		[150, 224, Vector3(0.4, 0.6, 0.4), Color(1, 0.8, 0.2), "WET FLOOR"],
		[250, 216, Vector3(0.9, 0.5, 0.6), Color(0.72, 0.58, 0.4), "TONER (empty)"],
	])

func _dress_gas() -> void:
	_back_wall(Color(0.95, 0.9, 0.78))
	zb = to3(Vector2(0, 0)).z
	wall_sign(160, 3.0, 3.0, 0.6, Color(0.95, 0.4, 0.2), "GAS-N-SIP", Color(1, 0.98, 0.9), 64)
	wall_sign(250, 2.7, 1.4, 0.5, Color(1, 0.95, 0.5), "JERKY 2 FOR $6\nREGRETS FREE", INK, 22)
	wall_sign(70, 2.9, 1.3, 0.45, Color(0.2, 0.5, 0.3), "DRY JANUARY?\nASK ABOUT PATCHES", Color(1, 1, 1), 20)
	_foreground([
		[60, 214, Vector3(0.9, 0.5, 0.5), Color(0.2, 0.3, 0.6), "OIL 2-for-1"],
		[260, 220, Vector3(0.6, 0.9, 0.3), Color(0.9, 0.9, 0.85), "NEWS: LOCAL DAD FINE"],
	])

func _dress_school() -> void:
	_backdrop(Color(0.66, 0.84, 0.96))
	_foreground([
		[40, 216, Vector3(0.12, 1.0, 0.12), Color(0.5, 0.5, 0.5)],
		[40, 216, Vector3(0.6, 0.4, 0.05), Color(1, 0.85, 0.2), "SLOW: KIDS"],
		[270, 222, Vector3(0.5, 0.4, 0.3), Color(0.9, 0.3, 0.45), "LOST & FOUND"],
	])

## Painted cardboard sky with cut-out hills and clouds (outdoor sets).
func _backdrop(sky: Color) -> void:
	slab(Vector3(0, WALL_H / 2 + 1, zb - 0.6), Vector3(XW * 2 + 2, WALL_H + 2, 0.1), sky)
	for k in 4:
		var hill := slab(Vector3(-6 + k * 4.2, 0.6, zb - 0.45), Vector3(5.5, 2.4, 0.06), Color(0.44, 0.66, 0.4).darkened(0.06 * (k % 2)))
		hill.rotation.z = 0.12 * (1 if k % 2 == 0 else -1)
	for k in 3:
		slab(Vector3(-5 + k * 5, 4.4 - 0.3 * (k % 2), zb - 0.4), Vector3(1.6, 0.5, 0.05), Color(0.99, 0.99, 1.0))
	var sunc := MeshInstance3D.new()
	var cy := CylinderMesh.new(); cy.top_radius = 0.5; cy.bottom_radius = 0.5; cy.height = 0.05
	sunc.mesh = cy; sunc.rotation_degrees.x = 90; sunc.material_override = mat(Color(1, 0.86, 0.35), 0.4)
	sunc.position = Vector3(5.5, 4.6, zb - 0.38)
	set_root.add_child(sunc)

## Side walls + front proscenium so the camera never sees past the set.
func _enclose(outdoor: bool) -> void:
	var zf := to3(Vector2(0, LIP)).z
	var depth := zf - (zb - 0.8)
	var col := Color(0.62, 0.48, 0.34) if not outdoor else Color(0.4, 0.62, 0.38)
	for sd in [-1.0, 1.0]:
		slab(Vector3(sd * (XW + 0.1), WALL_H / 2, (zf + zb - 0.8) / 2), Vector3(0.2, WALL_H + 2, depth), col)
		if outdoor:
			for k in 3:
				var tr := standee(Vector3(sd * (XW - 0.4), 0, zb + 1.5 + k * 3.0), 1.2, 3.0, Color(0.3, 0.55, 0.32))
				tr.name = "Wing"
	# corrugated cardboard edge at the stage lip
	slab(Vector3(0, -0.25, zf), Vector3(XW * 2 + 0.4, 0.5, 0.12), Color(0.7, 0.55, 0.38))

# ------------------------------------------------------------ town destinations (map places)
func _build_place(id: String) -> void:
	zb = -4.2
	match id:
		"park":
			_floor("grass", Rect2(0, 0, 320, 200))
			_backdrop(Color(0.66, 0.84, 0.96))
			block(Rect2(170, 40, 120, 60), 0.03, Color(0.4, 0.62, 0.86))       # pond
			for k in 3:
				var duck := slab(to3(Vector2(190 + k * 30, 60 + k * 9)) + Vector3(0, 0.2, 0), Vector3(0.36, 0.26, 0.05), Color(1, 0.95, 0.85))
				duck.name = "Duck"
				slab(duck.position + Vector3(0.17, 0.12, 0.03), Vector3(0.14, 0.14, 0.04), Color(0.25, 0.5, 0.3))
			block(Rect2(60, 110, 60, 12), 0.45, Color(0.55, 0.38, 0.25))
			block(Rect2(60, 106, 60, 4), 0.95, Color(0.5, 0.34, 0.22))
			text3("RESERVED", to3(Vector2(90, 108)) + Vector3(0, 0.75, 0.06), 26, Color(1, 0.95, 0.85))
			for x in [20, 140, 300]:
				_prop("tree", Vector2(x - 15, 20 + (x % 40)), Vector2(30, 32), false)
			wall_sign(60, 2.6, 2.4, 0.5, Color(0.35, 0.55, 0.3), "RIVERSIDE PARK", Color(1, 0.98, 0.9), 40)
		"pharmacy", "dental", "diner", "coffee":
			var cols: Array = {"pharmacy": [Color(0.88, 0.94, 0.92), Color(0.93, 0.93, 0.9), "PHARMACY · ROUTE 9", Color(0.2, 0.6, 0.45)],
				"dental": [Color(0.86, 0.92, 0.98), Color(0.9, 0.92, 0.94), "BROOKFIELD FAMILY DENTAL", Color(0.3, 0.5, 0.8)],
				"diner": [Color(0.98, 0.88, 0.75), Color(0.85, 0.3, 0.3), "LOU'S DINER · PIE", Color(0.75, 0.2, 0.2)],
				"coffee": [Color(0.9, 0.82, 0.7), Color(0.6, 0.45, 0.32), "BEAN THERE", Color(0.4, 0.25, 0.15)]}[id]
			_floor("floor_kitchen" if id == "diner" else "floor_wood", Rect2(0, 16, 320, 184))
			_back_wall(cols[0])
			wall_sign(160, 2.9, 3.4, 0.6, cols[3], cols[2], Color(1, 0.98, 0.92), 44)
			block(Rect2(110, 50, 110, 24), 1.0, cols[1])
			block(Rect2(108, 48, 114, 28), 0.05, Color(0.95, 0.93, 0.88), 1.0)
			match id:
				"pharmacy":
					for k in 3: block(Rect2(16 + k * 32, 20, 26, 14), 1.9, Color(0.95, 0.95, 0.95))
					wall_sign(270, 2.5, 1.5, 0.5, Color(1, 1, 1), "WE KNOW YOUR BIRTHDAY", Color(0.2, 0.5, 0.4), 22)
				"dental":
					block(Rect2(240, 70, 50, 26), 0.6, Color(0.4, 0.75, 0.75))
					block(Rect2(240, 66, 14, 30), 1.2, Color(0.4, 0.75, 0.75))
					wall_sign(60, 2.5, 1.6, 0.6, Color(1, 1, 1), "FLOSS: THE ONLY\nUPTIME THAT MATTERS", Color(0.3, 0.5, 0.8), 20)
				"diner":
					for k in 4:
						slab(to3(Vector2(122 + k * 26, 82)) + Vector3(0, 0.35, 0), Vector3(0.36, 0.7, 0.36), Color(0.85, 0.3, 0.3))
					for k in 3:
						block(Rect2(20 + k * 30, 100, 22, 14), 0.75, Color(0.85, 0.3, 0.3))
					slab(to3(Vector2(165, 58)) + Vector3(0, 1.2, 0), Vector3(0.8, 0.4, 0.5), Color(0.75, 0.9, 0.95), null, 0.2)
					text3("PIE OF THE DAY: YES", to3(Vector2(260, 16)) + Vector3(0, 2.4, 0.06), 24)
				"coffee":
					for k in 3:
						block(Rect2(30 + k * 90, 120, 26, 18), 0.72, Color(0.55, 0.4, 0.28))
						slab(to3(Vector2(43 + k * 90, 129)) + Vector3(0, 0.8, 0), Vector3(0.14, 0.16, 0.14), Color(1, 1, 1))
					slab(to3(Vector2(140, 58)) + Vector3(0, 1.3, 0), Vector3(0.5, 0.55, 0.4), Color(0.75, 0.75, 0.78))
					wall_sign(270, 2.5, 1.6, 0.7, Color(0.15, 0.15, 0.15), "DRIP $2\nSCONE $2\nQUIET: FREE", Color(1, 1, 1), 22)
			_clock(40, 2.7)
			_foreground([[60, 214, Vector3(0.7, 0.9, 0.4), Color(0.3, 0.62, 0.34)], [270, 220, Vector3(1.0, 0.45, 0.4), Color(0.85, 0.75, 0.55), "OPEN · COME IN"]])

# ------------------------------------------------------------ fridge + plant (cozy loop)
func refresh_cozy(drawings: int, plant_lv: int) -> void:
	if fridge_root:
		for c in fridge_root.get_children(): c.free()
		for i in mini(drawings, 12):
			var sp := Sprite3D.new()
			sp.texture = _drawings
			sp.region_enabled = true
			sp.region_rect = Rect2((i % 4) * 64, (i / 4) * 64, 64, 64)
			sp.pixel_size = 0.0042
			sp.position = Vector3(-0.22 + (i % 2) * 0.36 + 0.02 * (i % 3), 1.95 - (i / 2) * 0.27, 0.005 * (i % 3))
			sp.rotation.z = 0.12 * ((i * 37) % 5 - 2)
			sp.shaded = false
			fridge_root.add_child(sp)
			slab(sp.position + Vector3(0, 0.12, 0.01), Vector3(0.05, 0.05, 0.02), [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(1, 0.8, 0.2)][i % 3], fridge_root)
	if plant_node:
		var sc := 0.7 + 0.08 * mini(plant_lv, 6)
		plant_node.scale = Vector3(sc, sc, sc)
		for c in plant_node.get_children():
			if c.name == "Tomato": c.free()
		if plant_lv >= 3:
			var t := slab(Vector3(0.05, 0.55, 0.05), Vector3(0.14, 0.14, 0.06), Color(0.95, 0.3, 0.2) if plant_lv >= 6 else Color(0.55, 0.8, 0.35), plant_node)
			t.name = "Tomato"

# ------------------------------------------------------------ characters + camera
func card(n: String) -> PaperCard:
	if not cards.has(n):
		var c := PaperCard.new().setup(n)
		add_child(c)
		cards[n] = c
	return cards[n]

## Mirrors the Location's actors onto paper cards and moves the camera.
func tick(delta: float, loc: Location, near_station: String, talk_who: String, talk_flap: float, prompt_text: String, show_actors := true) -> void:
	if loc == null:
		return
	var vis: Array[String] = []
	for n in cards:
		cards[n].visible = false
	if show_actors:
		for n in loc.actors:
			var a: Actor = loc.actors[n]
			if not is_instance_valid(a) or not a.visible:
				continue
			if place != "" and n != "dan":
				continue
			vis.append(n)
	_space(vis, loc, delta)
	for n in vis:
		var a: Actor = loc.actors[n]
		var c := card(n)
		c.visible = true
		var p: Vector2 = a.position
		if place != "": p = Vector2(150, 112)
		var moving: bool = a.animation.begins_with("walk") and _last_pos.get(n, p) != p
		_last_pos[n] = p
		if a.facing == "left": c.face(-1.0)
		elif a.facing == "right": c.face(1.0)
		var f := talk_flap if n == talk_who else 0.0
		if f > 0.0: flap_frames += 1
		c.tick(delta, moving, f)
		c.position = to3(p) + Vector3(float(_vis_off.get(n, 0.0)), 0, 0)
		c.set_light(stage_tint, 0.38)
	flips_total = 0
	for n in cards: flips_total += cards[n].flips
	# camera: follow Dan from the side, slightly above; frame speakers during dialogue
	var target := to3(loc.actors["dan"].position) if loc.actors.has("dan") else Vector3.ZERO
	if place != "": target = to3(Vector2(150, 112))
	if talk_who != "" and cards.has(talk_who) and cards[talk_who].visible:
		target = target.lerp(cards[talk_who].position, 0.5)
	var want := Vector3(clampf(target.x, cam_x_range.x, cam_x_range.y), 0, target.z * 0.5) + CAM_OFF
	cam.position = cam.position.lerp(want, 1.0 - exp(-delta * 3.5))
	# proximity prompt: a paper tag over the station
	if place == "" and near_station != "" and loc.stations.has(near_station) and prompt_text != "":
		var r: Rect2 = loc.stations[near_station]["rect"]
		var p := to3(r.get_center())
		var bobv := sin(Time.get_ticks_msec() / 250.0) * 0.06
		tag.text = prompt_text
		tag.position = p + Vector3(0, 2.35 + bobv, 0.2)
		tag.visible = true
		tag_arrow.position = p + Vector3(0, 2.0 + bobv, 0.2)
		tag_arrow.visible = true
	else:
		tag.visible = false
		tag_arrow.visible = false

## Characters on the same depth lane never stand inside each other: nudge them apart sideways
## (presentation only; positions in the plan are untouched).
func _space(vis: Array[String], loc: Location, delta: float) -> void:
	var want := {}
	for n in vis: want[n] = 0.0
	for it in 3:
		for i in vis.size():
			for j in range(i + 1, vis.size()):
				var a: String = vis[i]; var b: String = vis[j]
				var pa := to3(loc.actors[a].position); var pb := to3(loc.actors[b].position)
				if absf(pa.z - pb.z) > 1.0: continue
				var wa: float = card(a).size.x; var wb: float = card(b).size.x
				var minsep := (wa + wb) * 0.42
				var dx: float = (pb.x + float(want[b])) - (pa.x + float(want[a]))
				if absf(dx) < minsep:
					var push := (minsep - absf(dx)) * 0.5 * (1.0 if dx >= 0 else -1.0)
					if dx == 0.0: push = minsep * 0.5 * (1.0 if a < b else -1.0)
					want[a] -= push; want[b] += push
	for n in vis:
		_vis_off[n] = lerpf(float(_vis_off.get(n, 0.0)), want[n], 1.0 - exp(-delta * 8.0)) if delta > 0 else want[n]

func _snap_camera() -> void:
	cam.position = CAM_OFF

## Visual x of a card (plan position + spacing offset).
func card_x(n: String) -> float:
	return cards[n].position.x if cards.has(n) else 0.0

## Time of day: morning sun, warm evening lamps, dim night.
func set_time(minutes: int) -> void:
	var h := minutes / 60.0
	var day_f := clampf(1.0 - absf(h - 13.0) / 8.0, 0.0, 1.0)
	sun.light_energy = 0.3 + 0.4 * day_f
	lamp.light_energy = 0.25 + (0.7 if h >= 18.0 or h < 7.0 else 0.0)
	env.ambient_light_energy = 0.3 + 0.15 * day_f
	if not clock_hands.is_empty():
		clock_hands[0].rotation.z = -fmod(h, 12.0) / 12.0 * TAU
		clock_hands[1].rotation.z = -fmod(float(minutes), 60.0) / 60.0 * TAU

## Rays through the four screen corners: how many escape the set (would show background / edges).
func edge_leaks(aspect: float) -> int:
	var leaks := 0
	var zf := to3(Vector2(0, LIP)).z
	var tv := tan(deg_to_rad(cam.fov * 0.5))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var d := (cam.global_transform.basis * Vector3(sx * tv * aspect, sy * tv, -1.0)).normalized()
			var o := cam.global_position
			var hit := false
			# floor
			if d.y < 0:
				var t := -o.y / d.y
				var p := o + d * t
				if p.z <= zf and p.z >= zb - 1.0 and absf(p.x) <= XW: hit = true
			# back wall / backdrop
			if not hit and d.z < 0:
				var t := (zb - 0.6 - o.z) / d.z
				var p := o + d * t
				if p.y <= WALL_H + 0.9 and p.y >= -0.2 and absf(p.x) <= XW + 0.3: hit = true
			# side walls
			if not hit and absf(d.x) > 0.0001:
				var t := (signf(d.x) * XW - o.x) / d.x
				var p := o + d * t
				if t > 0 and p.y <= WALL_H + 0.9 and p.y >= -0.2 and p.z >= zb - 1.0 and p.z <= zf: hit = true
			if not hit: leaks += 1
	return leaks

## Screen points (viewport px) of things the dialogue banner shouldn't cover: wall signs and a speaker's head.
func banner_keepouts(speaker: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for l in signs:
		if is_instance_valid(l) and l.global_position.y >= 0.3 and not str(l.name).begins_with("Foreground") and cam.is_position_in_frustum(l.global_position):
			out.append(cam.unproject_position(l.global_position))
	if cards.has(speaker) and cards[speaker].visible:
		var hp: Vector3 = cards[speaker].position + Vector3(0, cards[speaker].size.y * 0.75, 0)
		if cam.is_position_in_frustum(hp):
			out.append(cam.unproject_position(hp))
			out.append(cam.unproject_position(hp))   # weigh the speaker double
	return out
