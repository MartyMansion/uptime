class_name PaperPerson
extends Node2D
## One crude construction-paper cut-out character (original designs), drawn into a SubViewport
## that becomes a paper card in the diorama. Flat shapes, fat ink outline, hinged "flip-top" head.
## The wobble is baked per character (stable seed), so the outline never jitters frame to frame.

const INK := Color(0.12, 0.1, 0.1)
const SKIN := Color(1.0, 0.86, 0.72)
const CANVAS := Vector2(256, 320)
const CAST := {
	"dan":  {"shirt": Color(0.36, 0.42, 0.52), "pants": Color(0.25, 0.27, 0.36), "hair": Color(0.36, 0.25, 0.17), "w": 1.0},
	"jess": {"shirt": Color(0.52, 0.74, 0.6), "pants": Color(0.32, 0.36, 0.56), "hair": Color(0.76, 0.44, 0.2), "w": 0.94},
	"lily": {"shirt": Color(0.95, 0.56, 0.7), "pants": Color(0.56, 0.4, 0.72), "hair": Color(0.95, 0.8, 0.36), "w": 1.0},
	"june": {"shirt": Color(1.0, 0.8, 0.26), "pants": Color(0.3, 0.6, 0.82), "hair": Color(0.45, 0.3, 0.2), "w": 1.04},
	"gary": {"shirt": Color(0.92, 0.92, 0.87), "pants": Color(0.2, 0.2, 0.26), "hair": Color(0.62, 0.6, 0.58), "w": 1.08},
}
var who := "dan"
var flap := 0.0          # 0 = mouth shut, ~0.3 = open (top of head hinges back)
var walk := 0.0          # walk phase (radians); legs alternate, body bobs
var moving := false
var blink := 0.0
var _wob := {}           # baked per-vertex wobble

func _process(_d: float) -> void:
	queue_redraw()

func _w(key: int) -> Vector2:
	if not _wob.has(key):
		var r := RandomNumberGenerator.new()
		r.seed = hash(who) + key * 7919
		_wob[key] = Vector2(r.randf_range(-1.6, 1.6), r.randf_range(-1.6, 1.6))
	return _wob[key]

func paper(pts: PackedVector2Array, col: Color, key: int, wob := 1.0, ink := 3.0) -> void:
	var j := PackedVector2Array()
	for i in pts.size():
		j.append(pts[i] + _w(key * 64 + i) * wob)
	draw_colored_polygon(j, col)
	var c := j.duplicate()
	c.append(j[0])
	draw_polyline(c, INK, ink, true)

func box(x: float, y: float, w: float, h: float, col: Color, key: int, wob := 1.0) -> void:
	paper(PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]), col, key, wob)

func arc_pts(c: Vector2, r: float, a0: float, a1: float, n := 24) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n + 1:
		p.append(c + Vector2.from_angle(lerp(a0, a1, float(i) / n)) * r)
	return p

func _draw() -> void:
	var c: Dictionary = CAST.get(who, CAST["dan"])
	var s := 0.88
	var x := CANVAS.x / 2.0
	var base := CANVAS.y - 6.0
	var bob := absf(sin(walk)) * 5.0 if moving else 0.0
	var lean := sin(walk) * 0.04 if moving else 0.0
	draw_set_transform(Vector2(x, base), lean, Vector2.ONE)
	x = 0.0; base = 0.0
	var wd: float = c["w"]
	# feet: alternate lift while walking
	var lf := maxf(0.0, sin(walk)) * 9.0 if moving else 0.0
	var rf := maxf(0.0, -sin(walk)) * 9.0 if moving else 0.0
	box(x - 46 * s * wd, base - 28 * s - lf, 40 * s, 26 * s, INK, 1, 0.5)
	box(x + 6 * s * wd, base - 28 * s - rf, 40 * s, 26 * s, INK, 2, 0.5)
	base -= bob
	var body_top := base - 150 * s
	box(x - 48 * s * wd, base - 80 * s, 96 * s * wd, 56 * s, c["pants"], 3)
	if who == "lily":
		paper(PackedVector2Array([Vector2(x - 58 * s, base - 92 * s), Vector2(x + 58 * s, base - 92 * s), Vector2(x + 76 * s, base - 48 * s), Vector2(x - 76 * s, base - 48 * s)]), c["shirt"].darkened(0.1), 4)
	paper(PackedVector2Array([Vector2(x - 54 * s * wd, body_top), Vector2(x + 54 * s * wd, body_top), Vector2(x + 68 * s * wd, base - 74 * s), Vector2(x - 68 * s * wd, base - 74 * s)]), c["shirt"], 5)
	# mitten hands swing opposite to the feet
	var sw := sin(walk) * 6.0 if moving else 0.0
	paper(arc_pts(Vector2(x - 72 * s * wd, base - 96 * s + sw), 15 * s, 0, TAU, 14), SKIN, 6, 0.6)
	paper(arc_pts(Vector2(x + 72 * s * wd, base - 96 * s - sw), 15 * s, 0, TAU, 14), SKIN, 7, 0.6)
	match who:
		"dan":
			draw_line(Vector2(x - 24 * s, body_top + 2), Vector2(x, body_top + 66 * s), Color(0.2, 0.4, 0.9), 4)
			draw_line(Vector2(x + 24 * s, body_top + 2), Vector2(x, body_top + 66 * s), Color(0.2, 0.4, 0.9), 4)
			box(x - 14 * s, body_top + 64 * s, 28 * s, 32 * s, Color.WHITE, 8, 0.5)
			draw_line(Vector2(x - 8 * s, body_top + 76 * s), Vector2(x + 8 * s, body_top + 76 * s), INK, 2)
			box(x - 30 * s, body_top - 8 * s, 60 * s, 20 * s, c["shirt"].darkened(0.25), 9, 0.6)
		"gary":
			paper(PackedVector2Array([Vector2(x - 9 * s, body_top + 2), Vector2(x + 9 * s, body_top + 2), Vector2(x + 13 * s, body_top + 80 * s), Vector2(x, body_top + 96 * s), Vector2(x - 13 * s, body_top + 80 * s)]), Color(0.85, 0.16, 0.2), 10, 0.5)
			box(x + 26 * s, body_top + 20 * s, 18 * s, 12 * s, Color(0.3, 0.5, 0.9), 11, 0.3)   # pocket pen
		"jess":
			box(x - 46 * s, body_top + 36 * s, 92 * s, 70 * s, Color(0.99, 0.98, 0.94), 12)
			paper(arc_pts(Vector2(x, body_top + 60 * s), 10 * s, 0, TAU, 10), Color(0.95, 0.4, 0.4), 13, 0.3)
		"june":
			box(x - 20 * s, body_top + 40 * s, 40 * s, 30 * s, Color(1, 1, 1), 14, 0.6)
			draw_string(ThemeDB.fallback_font, Vector2(x - 14 * s, body_top + 64 * s), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s), Color(0.9, 0.3, 0.3))
	_head(c, x, body_top, s)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _head(c: Dictionary, x: float, body_top: float, s: float) -> void:
	var hr := 96.0 * s
	var hc := Vector2(x, body_top - hr * 0.78)
	paper(arc_pts(hc, hr, 0, PI), SKIN, 20, 1.0)            # jaw half (fixed)
	var hinge := hc + Vector2(-hr * 0.95, 0)
	var xf := Transform2D(-flap, Vector2.ZERO)
	var rot := func(arr: PackedVector2Array) -> PackedVector2Array:
		var o := PackedVector2Array()
		for p in arr: o.append(hinge + xf * (p - hinge))
		return o
	if flap > 0.01:
		# small, friendly mouth: the wedge between jaw and lifted head-top, plus a tongue (no horror maw)
		var tip: Vector2 = hinge + xf * (hc + Vector2(hr * 0.98, 0) - hinge)
		draw_colored_polygon(PackedVector2Array([hinge + Vector2(hr * 0.25, 0), hc + Vector2(hr * 0.98, 0), tip]), Color(0.36, 0.17, 0.17))
		draw_colored_polygon(PackedVector2Array([hc + Vector2(hr * 0.35, 0), hc + Vector2(hr * 0.85, 0), hc + Vector2(hr * 0.62, -(tip.y - hc.y) * -0.35)]), Color(0.92, 0.48, 0.48))
	var top := arc_pts(hc, hr, PI, TAU, 28)
	paper(rot.call(top), SKIN, 22, 1.0)
	match who:
		"gary":
			# a proud, doomed comb-over: three long strands swept from the left part, plus side fringe
			var fr := PackedVector2Array([hc + Vector2(-hr * 1.02, -hr * 0.05), hc + Vector2(-hr * 0.9, -hr * 0.55), hc + Vector2(-hr * 0.72, -hr * 0.42), hc + Vector2(-hr * 0.8, -hr * 0.02)])
			paper(rot.call(fr), c["hair"], 23, 0.4, 2.5)
			var fr2 := PackedVector2Array([hc + Vector2(hr * 1.02, -hr * 0.05), hc + Vector2(hr * 0.9, -hr * 0.5), hc + Vector2(hr * 0.76, -hr * 0.36), hc + Vector2(hr * 0.84, -hr * 0.02)])
			paper(rot.call(fr2), c["hair"], 24, 0.4, 2.5)
			for k in 3:
				var pts := PackedVector2Array()
				for i in 9:
					var t := i / 8.0
					var a := PI + 0.35 + t * 2.4
					pts.append(hc + Vector2.from_angle(a) * hr * (0.95 - 0.12 * k + 0.05 * sin(t * PI)))
				draw_polyline(rot.call(pts), c["hair"].darkened(0.15), 5.0 - k, true)
		_:
			var hair := arc_pts(hc, hr + 6, PI, TAU, 28)
			var fringe := 0.56 if who != "june" else 0.5
			hair.append(hc + Vector2(hr * 0.82, -hr * fringe))
			hair.append(hc + Vector2(hr * 0.3, -hr * (fringe + 0.12)))
			hair.append(hc + Vector2(-hr * 0.3, -hr * (fringe + 0.06)))
			hair.append(hc + Vector2(-hr * 0.82, -hr * fringe))
			paper(rot.call(hair), c["hair"], 25, 1.2)
			if who == "jess":
				paper(rot.call(arc_pts(hc + Vector2(hr * 0.85, -hr * 0.55), hr * 0.28, 0, TAU, 12)), c["hair"], 26, 0.6)   # bun
			if who == "lily":
				for sd in [-1.0, 1.0]:
					paper(rot.call(PackedVector2Array([hc + Vector2(sd * hr * 0.98, -hr * 0.2), hc + Vector2(sd * hr * 1.22, hr * 0.15), hc + Vector2(sd * hr * 1.0, hr * 0.32), hc + Vector2(sd * hr * 0.9, -hr * 0.05)])), c["hair"], 27 + int(sd), 0.4)
			if who == "june":
				paper(rot.call(PackedVector2Array([hc + Vector2(hr * 0.55, -hr * 0.92), hc + Vector2(hr * 1.05, -hr * 1.15), hc + Vector2(hr * 0.98, -hr * 0.6)])), Color(1, 0.3, 0.42), 29, 0.4)
				paper(rot.call(PackedVector2Array([hc + Vector2(hr * 0.55, -hr * 0.92), hc + Vector2(hr * 0.2, -hr * 1.2), hc + Vector2(hr * 0.2, -hr * 0.72)])), Color(1, 0.3, 0.42), 30, 0.4)
	# beady eyes (blink = flat line)
	for ex in [-0.32, 0.32]:
		var e: Vector2 = hinge + xf * (hc + Vector2(ex * hr, -hr * 0.4) - hinge)
		if blink > 0.5:
			draw_line(e - Vector2(6 * s, 0), e + Vector2(6 * s, 0), INK, 3)
		else:
			draw_circle(e, 7.5 * s, INK)
			draw_circle(e + Vector2(-1.5, -1.5) * s, 1.6 * s, Color(1, 1, 1, 0.8))
		if who == "dan":
			var b: Vector2 = hinge + xf * (hc + Vector2(ex * hr, -hr * 0.27) - hinge)
			draw_arc(b, 10 * s, 0.35, PI - 0.35, 8, Color(0.52, 0.36, 0.42), 2.5, true)
	if who == "gary":
		var g: Vector2 = hinge + xf * (hc + Vector2(0, -hr * 0.4) - hinge)
		draw_arc(g + Vector2(-0.32 * hr, 0), 13 * s, 0, TAU, 14, INK, 2.5, true)   # glasses
		draw_arc(g + Vector2(0.32 * hr, 0), 13 * s, 0, TAU, 14, INK, 2.5, true)
	if flap <= 0.01:
		draw_line(hc + Vector2(-hr * 0.5, hr * 0.02), hc + Vector2(hr * 0.62, 0), INK, 3, true)
