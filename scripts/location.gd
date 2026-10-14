class_name Location
extends Node2D
## Base for a playable place. World units: 320 x 200 (rendered 3x).
## Subclasses override build() and fill stations / spots / npc defaults.

const W := 320.0
const H := 200.0

var title := ""
var bounds := Rect2(8, 28, 304, 166)    # where Dan can walk (feet)
var stations := {}                        # id -> {rect, label, actions}
var spots := {}                           # name -> Vector2 (feet positions)
var actors := {}                          # name -> Actor
var highlight := ""
var _hl: Node2D

func _ready() -> void:
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	build()
	_hl = Node2D.new()
	_hl.z_index = 40
	_hl.draw.connect(_draw_highlight)
	add_child(_hl)

func build() -> void:
	pass

func set_highlight(id: String) -> void:
	if id != highlight:
		highlight = id
		_hl.queue_redraw()

func _draw_highlight() -> void:
	if highlight == "" or not stations.has(highlight):
		return
	var r: Rect2 = stations[highlight]["rect"]
	_hl.draw_rect(r.grow(1), Color(1, 0.95, 0.4, 0.9), false, 1.0)

func tile(tex: String, r: Rect2, z := -10) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/tiles/%s.png" % tex)
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, r.size)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.position = r.position
	s.z_index = z
	add_child(s)
	return s

## Props are y-sorted by their bottom edge, so actors walk in front/behind.
func prop(n: String, pos: Vector2, flat := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = n.capitalize().replace(" ", "")
	s.texture = load("res://assets/props/%s.png" % n)
	s.centered = false
	var h := s.texture.get_height()
	s.offset = Vector2(0, -h)
	s.position = pos + Vector2(0, h)
	if flat:
		s.z_index = -5
	add_child(s)
	return s

func station(id: String, label: String, r: Rect2, actions: Array) -> void:
	stations[id] = {"rect": r, "label": label, "actions": actions}

func spawn(n: String, pos: Vector2) -> Actor:
	if actors.has(n):
		actors[n].position = pos
		actors[n].visible = true
		return actors[n]
	var a := Actor.new().setup(n)
	a.position = pos
	add_child(a)
	actors[n] = a
	return a

func despawn(n: String) -> void:
	if actors.has(n):
		actors[n].queue_free()
		actors.erase(n)

func spot(n: String) -> Vector2:
	return spots.get(n, Vector2(W / 2, H / 2))

## Station whose (grown) rect contains p, nearest first.
func station_at(p: Vector2) -> String:
	var best := ""
	var bd := 1e9
	for id in stations:
		var r: Rect2 = stations[id]["rect"]
		if r.grow(10).has_point(p):
			var d := r.get_center().distance_to(p)
			if d < bd:
				bd = d
				best = id
	return best
