class_name Actor
extends AnimatedSprite2D
## A character sprite with 4-direction walk (3 frames) and idle (2 frames).
## Sheet layout (assets/sprites/characters/<name>.png): rows down/left/right/up,
## columns stand, step-L, step-R, breath. Position = feet.

const DIRS := ["down", "left", "right", "up"]
static var _cache := {}
var actor_name := ""
var facing := "down"
var _tween: Tween

func setup(n: String) -> Actor:
	actor_name = n
	name = n.capitalize()
	if not _cache.has(n):
		var tex: Texture2D = load("res://assets/sprites/characters/%s.png" % n)
		var sf := SpriteFrames.new()
		sf.remove_animation("default")
		for r in 4:
			var d: String = DIRS[r]
			sf.add_animation("walk_" + d)
			sf.set_animation_speed("walk_" + d, 8)
			for f in [1, 0, 2, 0]:
				sf.add_frame("walk_" + d, _frame(tex, f, r))
			sf.add_animation("idle_" + d)
			sf.set_animation_speed("idle_" + d, 1.5)
			sf.add_frame("idle_" + d, _frame(tex, 0, r))
			sf.add_frame("idle_" + d, _frame(tex, 3, r))
		_cache[n] = sf
	sprite_frames = _cache[n]
	offset = Vector2(0, -12)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	play("idle_down")
	frame = randi() % 2
	return self

static func _frame(tex: Texture2D, col: int, row: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(col * 16, row * 24, 16, 24)
	return at

static func dir_of(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"

func face(d: String) -> void:
	facing = d
	play("idle_" + d)

func walk(v: Vector2) -> void:
	if v == Vector2.ZERO:
		if animation.begins_with("walk"):
			play("idle_" + facing)
		return
	facing = dir_of(v)
	if animation != "walk_" + facing:
		play("walk_" + facing)

## Walk to a point at `speed` world px/sec. Returns the tween.
func walk_to(target: Vector2, speed := 70.0) -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	walk(target - position)
	var t := maxf(position.distance_to(target) / speed, 0.05)
	_tween = create_tween()
	_tween.tween_property(self, "position", target, t)
	_tween.tween_callback(func(): walk(Vector2.ZERO))
	return _tween

func stop_walking() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	walk(Vector2.ZERO)
