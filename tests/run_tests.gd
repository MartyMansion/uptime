extends SceneTree
## Headless test: godot --headless --path . -s res://tests/run_tests.gd

var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		printerr("FAIL: ", msg)

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	var gs: Node = root.get_node("GameState")
	gs.new_game(42)
	check(gs.clock_text() == "6:30 AM", "day starts 6:30 AM")
	check(gs.do_action("feed_girls") != "" and gs.minutes == 420 and gs.energy == 95, "breakfast costs 1 block / 5 energy")
	gs.do_action("work_ticket")
	check(gs.minutes == 480 and gs.energy == 85 and gs.performance == 58, "ticket costs 2 blocks / 10 energy, +perf")
	var m: int = gs.minutes
	gs.do_action("text_jess")
	check(gs.minutes == m and gs.closeness == 56, "texting Jess costs no time, +closeness")
	check(gs.can_do("bedtime_story") != "", "bedtime story locked in morning")
	var e: int = gs.energy
	gs.do_action("gaming")
	check(gs.energy == e + 5, "gaming restores 5 energy")
	gs.minutes = 1170
	gs.do_action("bedtime_story")
	check(gs.week_stats["bedtimes"] == 1, "bedtime story counted")
	var main: Node = root.get_node("Main")
	main.perform("work_ticket")  # exercise UI path
	gs.do_action("sleep")
	check(gs.day == 1 and gs.clock_text() == "6:30 AM", "sleep advances to Tuesday 6:30 AM")
	for i in 6:
		gs.do_action("work_ticket")
		gs.do_action("sleep")
	check(gs.week_over, "week ends after Sunday")
	var review: String = gs.weekly_review()
	check(review.begins_with("LIFEOS"), "weekly review generated")
	print(review)
	print("TESTS DONE: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
	return true
