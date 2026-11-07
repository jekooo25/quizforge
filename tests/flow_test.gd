extends Node
## End-to-end flow test: drives the real buttons through every screen.
## godot --headless --path . --script res://tests/flow_test.gd

## Every check this run must reach. A script error inside an assertion skips it
## without counting as a failure, which would otherwise print
## "ALL FLOW CHECKS PASSED" over a crashed run.
## Keep this in step with the explicit _check calls below.  The former value
## was left over from a removed assertion, so a clean run was falsely marked
## as though a check had crashed.
const EXPECTED_CHECKS := 86

var failures: int = 0
var checks_run: int = 0


func _ready() -> void:
	_run()


func _check(condition: bool, message: String) -> void:
	checks_run += 1
	if condition:
		print("  ok   ", message)
	else:
		failures += 1
		printerr("  FAIL ", message)


## Depth-first search for a Button whose text matches.
func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text.contains(text):
		return node as Button
	for child in node.get_children():
		# Main-menu tile captions are child Labels rather than Button.text.
		if node is Button:
			var caption := _find_label(child, text)
			if caption != null:
				return node as Button
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text.contains(text):
		return node as Label
	for child in node.get_children():
		var found := _find_label(child, text)
		if found != null:
			return found
	return null


func _press(node: Node, text: String) -> bool:
	var b := _find_button(node, text)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func _mouse_click_button(button: Button) -> void:
	# Convert the control's canvas position into actual output pixels. The
	# viewport final transform is 0.625 at 800x360 with canvas_items stretch.
	var canvas_point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var point := get_viewport().get_final_transform() * canvas_point
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame
	event.pressed = false
	get_viewport().push_input(event)
	await get_tree().process_frame


func _screen() -> Node:
	return Nav._current


func _run() -> void:
	if Nav == null or SaveManager == null:
		printerr("  FAIL an autoload did not load (Nav / SaveManager)")
		printerr("FLOW CHECKS FAILED")
		get_tree().quit(1)
		return

	# Start from a clean slate so a previous run's quiz doesn't leak in.
	if FileAccess.file_exists(QuizData.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QuizData.SAVE_PATH))
	if DirAccess.dir_exists_absolute(QuizLibrary.DIR):
		for file in DirAccess.get_files_at(QuizLibrary.DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(
				"%s/%s" % [QuizLibrary.DIR, file]))
	await get_tree().process_frame
	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main_scene)
	await get_tree().process_frame
	await get_tree().process_frame

	print("-- boot --")
	_check(Nav._current != null, "a screen is showing")
	_check(_screen().get_script().resource_path.ends_with("title_screen.gd"), "starts on the title screen")

	print("-- title -> login --")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.position = Vector2(600, 300)
	_screen()._gui_input(click)
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("login_screen.gd"), "tap opens login")

	print("-- login validation --")
	_check(_press(_screen(), "Login") == true, "login button is pressable")
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("login_screen.gd"), "empty username keeps you on login")
	_check(_screen()._error.text != "", "empty username shows an error")

	print("-- password recovery --")
	_press(_screen(), "Forgot password?")
	await get_tree().process_frame
	_check(_screen().scene_file_path.ends_with("ForgotPassword.tscn"), "forgot password opens its editable screen")
	_check(_press(_screen(), "Request password reset") == false or _screen().status.text != "", "reset request requires account details")
	_screen().username.text = "Alex Cruz"
	_screen().email.text = "alex.cruz@school.edu"
	_press(_screen(), "Request password reset")
	_check(_screen().status.text.begins_with("Request recorded"), "password reset request is acknowledged")
	_press(_screen(), "Back to login")
	await get_tree().process_frame

	print("-- login credentials --")
	var login := _screen()
	login._username.text = "Alex Cruz"
	login._password.text = "password123"
	_press(login, "Login")
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("loading_screen.gd"), "login shows the loader")
	_check(FileAccess.file_exists(Nav.SAVE_PATH), "profile written to disk")

	print("-- loader -> menu --")
	await get_tree().create_timer(3.2).timeout
	_check(_screen().get_script().resource_path.ends_with("menu_screen.gd"), "loader lands on the main menu")

	print("-- menu navigation --")
	_screen().open_settings()
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("settings_screen.gd"), "settings opens")

	var settings := _screen()
	_check(settings._version_label != null and settings._version_label.text.begins_with("v"),
		"settings shows a version label to tap")
	_check(settings._dev_field == null, "the developer menu starts hidden")

	# seven taps is the only way in, so a student tapping around finds nothing
	for i in 6:
		settings._on_version_press()
	await get_tree().process_frame
	_check(settings._dev_field == null, "six taps is not enough")
	settings._on_version_press()
	await get_tree().process_frame
	_check(settings._dev_field != null, "seven taps open the developer menu")

	settings._dev_field.text = "192.168.1.60:8765"
	settings._dev_save(settings._dev_field)
	_check(Nav.user["server_url"] == "http://192.168.1.60:8765", "the developer menu saves an address")
	_check(settings._dev_field.text == "http://192.168.1.60:8765", "a bare address gains http://")
	_check(settings._dev_using.text.contains("192.168.1.60"),
		"the menu shows which address is in use")

	Nav.user["server_url"] = ""
	Nav.load_profile()
	_check(Nav.user["server_url"] == "http://192.168.1.60:8765", "the address is read back from disk")
	_check(QuizClient.base_url() == "http://192.168.1.60:8765", "the client uses the saved address")

	settings._dev_reset()
	_check(Nav.user["server_url"] == "", "reset to default clears the address")
	_check(settings._dev_using.text.contains(ServerConfig.DEFAULT_URL),
		"after reset the menu shows the build default in use")
	_check(QuizClient.base_url() == ServerConfig.DEFAULT_URL, "the client falls back to the build default")
	var saved_profile = JSON.parse_string(FileAccess.get_file_as_string(Nav.SAVE_PATH))
	_check(typeof(saved_profile) == TYPE_DICTIONARY and not saved_profile["user"].has("password"),
		"the password is not written to disk")

	_press(_screen(), "Main Menu")
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("menu_screen.gd"), "settings returns to menu")
	var daily_tile := _find_button(_screen(), "Daily Tasks")
	_check(daily_tile != null, "Daily Tasks menu tile is a Button")
	if daily_tile != null:
		await _mouse_click_button(daily_tile)
	_check(str(_screen().get_script().resource_path).ends_with("DailyTasks.gd"),
		"a real tile mouse click opens the DailyTasks scene through the tile container")
	_check(_press(_screen(), "X"), "Daily Tasks close button is clickable")
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("menu_screen.gd"),
		"closing Daily Tasks returns to the main menu")
	var original_window_size := get_window().size
	_check(_find_button(_screen(), "STARS SHOP") != null,
		"the menu contains the scene-based STARS SHOP Button")
	for resolution in [Vector2i(1280, 562), Vector2i(800, 360)]:
		get_window().size = resolution
		await get_tree().process_frame
		var shop_button := _find_button(_screen(), "STARS SHOP")
		if shop_button != null:
			await _mouse_click_button(shop_button)
		_check(_screen().get_script().resource_path.ends_with("StarsShop.gd"),
			"a mouse click at %dx%d opens the real Stars Shop" % [resolution.x, resolution.y])
		var shop_back := _find_button(_screen(), "X")
		if shop_back != null:
			await _mouse_click_button(shop_back)
		_check(_screen().get_script().resource_path.ends_with("menu_screen.gd"),
			"the Shop Back button returns to the menu at %dx%d" % [resolution.x, resolution.y])
		_check(Nav._host.get_child_count() == 1,
			"returning from Shop leaves one active screen at %dx%d" % [resolution.x, resolution.y])
	get_window().size = original_window_size
	await get_tree().process_frame

	_screen().open_progress()
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("my_quizzes_screen.gd"),
		"my quizzes opens")
	_check(_press(_screen(), "Main Menu"), "My Quizzes returns to the main menu")
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("menu_screen.gd"),
		"the main menu is showing again")

	print("-- exit confirmation --")
	_screen()._on_exit()
	await get_tree().process_frame
	var quit_dialog: Control = null
	for child in _screen().get_children():
		if child is Control and child.get_script() != null \
				and str(child.get_script().resource_path).ends_with("quit_dialog.gd"):
			quit_dialog = child
	_check(quit_dialog != null, "exit asks for confirmation")
	if quit_dialog != null:
		_check(_press(quit_dialog, "No") == true, "No is offered")
		await get_tree().process_frame
		_check(not is_instance_valid(quit_dialog), "No closes the dialog without quitting")
		_check(_screen().get_script().resource_path.ends_with("menu_screen.gd"),
			"you are still on the menu")

	print("-- scene-based upload and failure handling --")
	_screen().open_upload()
	await get_tree().process_frame
	_check(_screen().scene_file_path.ends_with("UploadReviewer.tscn"), "editable upload scene opens")
	var upload := _screen()
	_check(upload.get_node("%Generate").disabled,"generation is blocked without a file")
	upload._on_file_selected("user://missing-reviewer.pdf")
	_check(upload.get_node("%Generate").disabled,"missing files are rejected before upload")
	_check(upload.get_node("%FileDialog").use_native_dialog,"upload uses a native file picker when supported")
	Nav.user.reviewer_file="user://missing-reviewer.pdf"
	Nav.show_screen(load("res://scenes/GenerateQuiz.tscn").instantiate())
	await get_tree().process_frame
	_check(_screen().scene_file_path.ends_with("GenerateQuiz.tscn"),"editable generation scene opens")
	_check(_screen()._finished,"missing file stops generation")
	_check(_screen()._failure!="","failure has a clear reason")
	_check(not _screen()._using_sample,"no silent sample fallback")
	_check(_screen().get_node("%Preview").disabled,"failed generation cannot open preview")
	_check(_screen().get_node("%Retry").visible,"retry is available")
	_check(_screen().get_node("%Choose").visible,"choosing another file is available")
	_check(_screen()._failure.contains("Choose it again"),"failure suggests a useful next step")
	print("-- preview fixture, validation and explicit save --")
	var count_before := QuizLibrary.count()
	var preview: Control=load("res://scenes/GeneratedQuizPreview.tscn").instantiate()
	preview.imported_quiz={"title":"Reviewed science quiz","questions":QuizData.sample()}
	Nav.show_screen(preview)
	await get_tree().process_frame
	_check(_screen().scene_file_path.ends_with("GeneratedQuizPreview.tscn"),"preview is an editable scene")
	_check(preview.questions.size()==QuizData.sample().size(),"questions arrive intact")
	_check(QuizLibrary.count()==count_before,"preview does not auto-save")
	_check(preview.validate().is_empty(),"valid questions pass review validation")
	_check(not preview.get_node("%Submit").visible,"generated preview cannot publish")
	_check(preview.get_node("%Save").text=="Save quiz","saving is explicit")
	var first_choice: LineEdit=preview.get_node("%ChoiceA")
	var original_choice:=first_choice.text
	first_choice.text=""
	await preview.save_draft()
	_check(_screen()==preview,"empty answer blocks save")
	_check(preview.get_node("%Status").text.contains("empty"),"invalid answer is explained")
	first_choice.text=original_choice
	await preview.save_draft()
	await get_tree().process_frame
	_check(_screen().scene_file_path.ends_with("QuizDetails.tscn"),"saving opens details without starting gameplay")
	_check(QuizLibrary.count()==count_before+1,"explicit save creates one quiz")

	print("-- quiz library --")
	var shelf := QuizLibrary.all()
	_check(shelf.size() == 1, "the saved quiz is filed exactly once")
	if shelf.size() == 1:
		var entry: Dictionary = shelf[0]
		_check(int(entry.get("count", 0)) > 0, "the library row knows how many questions")
		_check(not QuizLibrary.get_quiz(str(entry.get("id", ""))).is_empty(),
			"the quiz body loads back off disk")

		Nav.show_screen(load("res://scenes/my_quizzes.tscn").instantiate())
		await get_tree().process_frame
		_check(_screen().get_script().resource_path.ends_with("my_quizzes_screen.gd"),
			"my quizzes opens")

		_check(QuizLibrary.play(str(entry.get("id", ""))), "a library quiz hands itself to the battle")
		_check(QuizData.load_saved().get("questions", []).size() > 0,
			"playing rewrites the battle's quiz file")

		for resolution in [Vector2i(1280, 562), Vector2i(800, 360)]:
			get_window().size = resolution
			Nav.show_screen(load("res://scenes/my_quizzes.tscn").instantiate())
			await get_tree().process_frame
			await get_tree().process_frame
			var card := _screen().get_node("%QuizList").get_child(0)
			await _mouse_click_button(card.get_node("%PlayButton"))
			await get_tree().process_frame
			var mode_picker: Control = _screen()
			var picker_open: bool = mode_picker.scene_file_path.ends_with("QuizDetails.tscn")
			_check(picker_open, "saved quiz opens quiz details at %s" % resolution)
			if picker_open:
				mode_picker.get_node("%Scroll").ensure_control_visible(mode_picker.get_node("%BattleButton"))
				await get_tree().process_frame
				await _mouse_click_button(mode_picker.get_node("%Start"))
				await get_tree().process_frame
			var is_battle: bool = _screen().get_script().resource_path.ends_with("battle.gd")
			_check(is_battle, "saved quiz Play mouse click opens battle at %s" % resolution)
			_check(Nav._host.get_child_count() == 1 and is_battle,
				"Play replaces the library without leaving an input-blocking screen")
			if is_battle:
				var encounter = _screen()
				await _mouse_click_button(encounter.answer_buttons[encounter._correct_index])
				await get_tree().create_timer(0.75).timeout
				_check(encounter._state == "auto_advancing" and encounter._answered_correctly == 1,
					"battle receives mouse input after saved quiz Play")
			else:
				_check(false, "battle receives mouse input after saved quiz Play")

		# one screen, three tabs: the library is the default, progress is still here
		Nav.show_screen(load("res://scenes/my_quizzes.tscn").instantiate())
		await get_tree().process_frame
		_check(_screen().get_script().resource_path.ends_with("my_quizzes_screen.gd"),
			"my quizzes opens")
		_check(_screen()._tab == "quizzes", "my quizzes is the default tab")
		_check(_screen().get_node("%QuizList").get_child_count() > 0,
			"my quizzes lists the saved quiz")
		_screen().show_tab("progress")
		await get_tree().process_frame
		_check(_screen()._tab == "progress", "progress is still reachable as a tab")

	print("-- legacy profile --")
	# a v1 profile that still carries a typed address must lose it on load
	var legacy := FileAccess.open(Nav.SAVE_PATH, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({
		"user": {"username": "old", "server_url": "http://10.0.0.9:9999"},
	}))
	legacy.close()
	Nav.user["server_url"] = "http://10.0.0.9:9999"
	Nav.load_profile()
	_check(Nav.user["server_url"] == "", "an address typed under v1 is discarded on load")

	# leave no test address behind for the next manual run
	Nav.user["server_url"] = ""
	Nav.save_profile()

	if checks_run != EXPECTED_CHECKS:
		failures += 1
		printerr("  FAIL ran %d checks, expected %d — the flow test changed without updating its count" % [
			checks_run, EXPECTED_CHECKS])

	print("")
	if failures == 0:
		print("ALL FLOW CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("%d FLOW CHECK(S) FAILED" % failures)
		get_tree().quit(1)

