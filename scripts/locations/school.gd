extends Location
## Brookfield Elementary curb. Cutscene-only (drop-off and pickup).

func build() -> void:
	title = "Brookfield Elementary"
	tile("grass", Rect2(0, 0, 320, 80))
	tile("sidewalk", Rect2(0, 80, 320, 40))
	tile("asphalt", Rect2(0, 120, 320, 60))
	tile("road_lane", Rect2(0, 180, 320, 20))
	prop("school_front", Vector2(96, 16))
	prop("tree", Vector2(20, 30))
	prop("tree", Vector2(260, 34))
	prop("car", Vector2(140, 124))
	spots = {"entry": Vector2(130, 168), "car": Vector2(130, 168), "car_l": Vector2(124, 128), "car_r": Vector2(176, 140),
		"school_door": Vector2(160, 84), "curb": Vector2(150, 110), "curb_l": Vector2(132, 106), "curb_r": Vector2(176, 106)}
