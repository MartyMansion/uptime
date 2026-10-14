extends Location
## The Gas-N-Sip on Route 9: storefront interior on top, the lot below.

func build() -> void:
	title = "Gas-N-Sip, Route 9"
	tile("floor_kitchen", Rect2(0, 0, 320, 70))
	tile("asphalt", Rect2(0, 70, 320, 110))
	tile("road_lane", Rect2(0, 180, 320, 20))
	tile("wall", Rect2(0, 66, 120, 4), -9)
	tile("wall", Rect2(160, 66, 160, 4), -9)
	prop("beer_cooler", Vector2(20, 8))
	prop("store_counter", Vector2(200, 24))
	prop("plant", Vector2(290, 30))
	prop("gas_sign", Vector2(128, 2))
	prop("gas_pump", Vector2(100, 110))
	prop("gas_pump", Vector2(200, 110))
	prop("car", Vector2(130, 108))
	station("beer", "Beer cooler", Rect2(20, 8, 40, 32), ["buy_beer"])
	station("counter", "Counter", Rect2(200, 24, 40, 22), ["buy_pouches"])
	station("car", "Your car", Rect2(130, 108, 32, 46), ["pickup_girls"])
	spots = {"entry": Vector2(124, 150), "car": Vector2(124, 150), "door": Vector2(140, 74),
		"beer": Vector2(40, 52), "counter": Vector2(220, 58)}
