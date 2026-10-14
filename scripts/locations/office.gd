extends Location
## TriCounty Managed Services: cubicles, server room, Gary's office.

func build() -> void:
	title = "TriCounty Managed Services"
	tile("wall_office", Rect2(0, 0, 320, 16))
	tile("floor_office", Rect2(0, 16, 320, 184))
	tile("floor_kitchen", Rect2(230, 16, 90, 70))     # server room
	tile("wall_office", Rect2(228, 16, 4, 50), -9)
	tile("wall_office", Rect2(228, 86, 92, 4), -9)
	prop("office_sign", Vector2(16, 0))
	for i in 4:
		prop("server_rack", Vector2(240 + i * 18, 22))
	prop("office_desk", Vector2(40, 70))
	prop("office_desk", Vector2(90, 70))
	prop("office_desk", Vector2(40, 120))
	prop("office_desk", Vector2(140, 120))
	prop("printer", Vector2(150, 30))
	prop("water_cooler", Vector2(190, 26))
	prop("office_desk", Vector2(250, 130))   # Gary's
	prop("plant", Vector2(290, 128))
	prop("door", Vector2(150, 170))
	station("desk", "Your desk", Rect2(40, 70, 32, 20), ["work_ticket"])
	station("exit", "Exit (head home)", Rect2(150, 170, 20, 30), ["head_home"])
	spots = {"entry": Vector2(160, 186), "door": Vector2(160, 192), "desk": Vector2(56, 100),
		"gary_desk": Vector2(266, 166), "gary_talk": Vector2(84, 104), "cooler": Vector2(198, 62)}
