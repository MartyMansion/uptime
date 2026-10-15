extends Location
## Main Street, Brookfield: Dan in the car between places (after work). Neutral: no shop here.
## The town map opens from the car; the Gas-N-Sip is just one optional pin on it.

func build() -> void:
	title = "Main Street, Brookfield"
	tile("grass", Rect2(0, 0, 320, 70))
	tile("sidewalk", Rect2(0, 70, 320, 30))
	tile("asphalt", Rect2(0, 100, 320, 80))
	tile("road_lane", Rect2(0, 180, 320, 20))
	prop("tree", Vector2(30, 24))
	prop("tree", Vector2(150, 18))
	prop("tree", Vector2(262, 28))
	prop("car", Vector2(140, 108))
	station("car", "Your car (town map)", Rect2(140, 108, 32, 46), ["pickup_girls"])
	spots = {"entry": Vector2(130, 168), "car": Vector2(130, 168), "curb": Vector2(150, 96)}
