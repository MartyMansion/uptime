extends Location
## The Mercer house: bedroom, kitchen, girls' room on top; living room below.

func build() -> void:
	title = "Home — the Mercer house"
	tile("wall", Rect2(0, 0, 320, 16))
	tile("floor_wood", Rect2(0, 16, 100, 84))          # bedroom
	tile("floor_kitchen", Rect2(100, 16, 120, 84))     # kitchen
	tile("floor_carpet_pink", Rect2(220, 16, 100, 84)) # girls' room
	tile("floor_wood", Rect2(0, 100, 320, 100))        # living room
	# interior walls with doorways
	for r in [Rect2(98, 16, 4, 40), Rect2(218, 16, 4, 40), Rect2(0, 98, 40, 4), Rect2(70, 98, 60, 4), Rect2(160, 98, 90, 4), Rect2(280, 98, 40, 4)]:
		tile("wall", r, -9)
	prop("bed_double", Vector2(12, 22))
	prop("plant", Vector2(76, 22))
	prop("kitchen_counter", Vector2(108, 18))
	prop("fridge", Vector2(196, 18))
	prop("table", Vector2(140, 58))
	prop("bed_kid", Vector2(232, 22))
	prop("bed_kid", Vector2(286, 22))
	prop("toys", Vector2(256, 72), true)
	prop("bookshelf", Vector2(258, 18))
	prop("rug", Vector2(170, 132), true)
	prop("tv_stand", Vector2(178, 112))
	prop("couch", Vector2(170, 166))
	prop("pc_desk", Vector2(16, 116))
	prop("door", Vector2(140, 170))
	prop("plant", Vector2(292, 176))
	station("bed", "Bed", Rect2(12, 22, 32, 40), ["sleep"])
	station("kitchen", "Kitchen", Rect2(108, 18, 104, 30), ["feed_girls", "cereal", "pancakes", "family_dinner", "drink"])
	station("girls", "Girls' room", Rect2(232, 22, 74, 60), ["play_girls", "homework", "bedtime_story"])
	station("desk", "PC desk", Rect2(16, 116, 32, 20), ["work_ticket", "gaming", "side_hustle"])
	station("door", "Front door", Rect2(140, 170, 20, 30), ["leave_for_work", "walk_park", "walk_block", "concert"])
	station("plant", "Porch tomato", Rect2(290, 170, 20, 26), ["water_plant"])
	station("couch", "Couch", Rect2(172, 160, 52, 26), ["tea_jess", "chores"])
	spots = {"entry": Vector2(150, 186), "door": Vector2(150, 192), "bed": Vector2(56, 60),
		"kitchen": Vector2(132, 56), "kitchen_b": Vector2(178, 88), "table_l": Vector2(132, 84), "table_r": Vector2(176, 78),
		"girls": Vector2(262, 86), "lily_bed": Vector2(242, 62), "june_bed": Vector2(296, 62), "girls_dan": Vector2(270, 66),
		"couch": Vector2(206, 184), "couch_l": Vector2(186, 184), "couch_r": Vector2(226, 184), "living": Vector2(150, 150), "living_j": Vector2(176, 150), "desk": Vector2(32, 150)}
