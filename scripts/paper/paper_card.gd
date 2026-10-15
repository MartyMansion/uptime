class_name PaperCard
extends Node3D
## A character as a stand-up paper card: printed art on both faces (the back reads mirrored, like
## Paper Mario), three kraft core layers that show the card's thickness while it flips, a soft
## contact shadow, a walk bob/wobble, and a page-turn flip with a tilt and lift.

const HEIGHTS := {"dan": 1.62, "jess": 1.54, "lily": 1.06, "june": 0.9, "gary": 1.7}
const FLIP_TIME := 0.3
const THICK := 0.035
static var _shader: Shader
static var _shadow_shader: Shader

var who := "dan"
var art: PaperPerson
var vp: SubViewport
var pivot: Node3D            # rotates for the flip
var layers: Array[MeshInstance3D] = []
var shadow: MeshInstance3D
var size := Vector2.ONE
var facing := 1.0            # +1 right, -1 left
var rot := 0.0               # current Y rotation (0 or PI at rest)
var flips := 0
var flip_t := 1.0            # 0..1 progress of the last flip
var walk_amt := 0.0
var _blink_t := 2.0

func setup(n: String) -> PaperCard:
	who = n
	name = "Card_" + n
	if _shader == null:
		_shader = load("res://shaders/card.gdshader")
		_shadow_shader = load("res://shaders/shadow.gdshader")
	vp = SubViewport.new()
	vp.size = Vector2i(PaperPerson.CANVAS)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	art = PaperPerson.new()
	art.who = n
	vp.add_child(art)
	var h: float = HEIGHTS.get(n, 1.5)
	size = Vector2(h * PaperPerson.CANVAS.x / PaperPerson.CANVAS.y, h)
	pivot = Node3D.new()
	add_child(pivot)
	# back art, 3 core layers, front art (front last so it wins ties)
	for i in 5:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = size
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("tex", vp.get_texture())
		m.set_shader_parameter("core", 1.0 if i in [1, 2, 3] else 0.0)
		mi.material_override = m
		mi.position = Vector3(0, size.y * 0.5, lerp(-THICK * 0.5, THICK * 0.5, i / 4.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		layers.append(mi)
	shadow = MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(size.x * 0.85, 0.42 * clampf(h, 0.8, 1.7) / 1.6)
	shadow.mesh = sq
	shadow.rotation_degrees.x = -90
	shadow.position.y = 0.012
	var sm := ShaderMaterial.new()
	sm.shader = _shadow_shader
	shadow.material_override = sm
	add_child(shadow)
	return self

func texture() -> Texture2D:
	return vp.get_texture()

## Warm/cool light the card should pick up from its set (subtle).
func set_light(tint: Color, lit: float) -> void:
	for l in layers:
		l.material_override.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		l.material_override.set_shader_parameter("lit", lit)

func face(dir: float) -> void:
	if dir == 0.0 or signf(dir) == facing:
		return
	facing = signf(dir)
	flips += 1
	flip_t = 0.0

## Per frame: moving drives the walk cycle; flap is the mouth (0..0.3).
func tick(delta: float, moving: bool, flap: float) -> void:
	walk_amt = move_toward(walk_amt, 1.0 if moving else 0.0, delta * 6.0)
	art.moving = walk_amt > 0.05
	if moving:
		art.walk += delta * 11.0
	art.flap = flap
	_blink_t -= delta
	art.blink = 1.0 if _blink_t < 0.12 else 0.0
	if _blink_t <= 0.0:
		_blink_t = 2.5 + fmod(float(hash(who)) * 0.37 + art.walk, 2.0)
	flip_t = minf(1.0, flip_t + delta / FLIP_TIME)
	var target := 0.0 if facing > 0 else PI
	var from := PI - target
	var e := flip_t * flip_t * (3.0 - 2.0 * flip_t)
	rot = lerpf(from, target, e) if flip_t < 1.0 else target
	var mid := sin(flip_t * PI)                       # 0 at rest, 1 edge-on
	pivot.rotation = Vector3(-0.1 * mid, rot, 0.14 * mid * facing + sin(art.walk) * 0.035 * walk_amt)
	pivot.position.y = 0.08 * mid + absf(sin(art.walk)) * 0.045 * walk_amt
	# the core layers spread a little mid-turn so the card visibly has thickness
	for i in layers.size():
		layers[i].position.z = lerp(-THICK * 0.5, THICK * 0.5, i / 4.0) * (1.0 + 1.5 * mid)
	shadow.scale = Vector3.ONE * (1.0 - 0.25 * pivot.position.y / 0.12)

func flipping() -> bool:
	return flip_t < 1.0
