extends Node

var checks: int = 0
var failures: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var routes: Array[String] = [
		"res://scenes/UploadReviewer.tscn",
		"res://scenes/my_quizzes.tscn",
		"res://scenes/DailyTasks.tscn",
		"res://scripts/screens/settings_screen.gd",
		"res://scenes/StarsShop.tscn",
		"res://scenes/BattleResults.tscn",
		"res://scenes/BattlePauseMenu.tscn"
	]
	for route: String in routes:
		var screen: Control
		if route.ends_with(".tscn"):
			screen = load(route).instantiate() as Control
		else:
			screen = load(route).new() as Control
		Nav.show_screen(screen)
		await get_tree().process_frame
		Nav.show_screen(load("res://scenes/HomeScreen.tscn").instantiate())
		await get_tree().process_frame
		_check(Nav._current != null and Nav._current.scene_file_path.ends_with("HomeScreen.tscn"), "returned HomeScreen from %s" % route)
		_check(Nav._host.get_child_count() == 1, "one screen after %s" % route)
	print("HOME ROUTE CHECKS: %d/%d passed" % [checks - failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: %s" % label)
