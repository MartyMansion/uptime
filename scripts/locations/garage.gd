extends Location
## The Mercer garage: delivered boxes, a workbench, and (eventually) the server farm.

func build() -> void:
	title = "The garage (Mercer Data Center, est. this week)"
	tile("wall", Rect2(0, 0, 320, 16))
	tile("floor_office", Rect2(0, 16, 320, 184))
	prop("office_desk", Vector2(20, 30))
	station("boxes", "Delivered boxes", Rect2(40, 116, 60, 34), ["build_farm"])
	station("rack", "The farm (rack)", Rect2(150, 30, 90, 40), ["farm_check"])
	station("door", "Door to the house", Rect2(286, 150, 26, 40), ["go_inside"])
	spots = {"entry": Vector2(286, 176), "boxes": Vector2(70, 160), "rack": Vector2(196, 84)}
