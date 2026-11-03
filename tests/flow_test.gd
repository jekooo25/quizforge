extends Node
## End-to-end flow test: drives the real buttons through every screen.
## godot --headless --path . --script res://tests/flow_test.gd

var failures: int = 0


func _ready() -> void:
	_run()


func _check(condition: bool, message: String) -> void:
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
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _press(node: Node, text: String) -> bool:
	var b := _find_button(node, text)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func _screen() -> Node:
	return Nav._current


func _run() -> void:
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

	print("-- sign up: name --")
	_press(_screen(), "Sign up")
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("signup_name_screen.gd"), "sign up opens step 1")
	_check(_press(_screen(), "Next") == false or _screen()._error.text != "", "blocked without a name")

	_screen()._first.text = "Alex"
	_screen()._middle.text = "B"
	_screen()._last.text = "Cruz"
	_press(_screen(), "Next")
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("signup_school_screen.gd"), "step 1 advances to step 2")
	_check(Nav.user["last_name"] == "Cruz", "name captured in session")

	print("-- sign up: credentials --")
	var creds := _screen()
	creds._student_id.text = "2026-1187"
	creds._email.text = "alex.cruz@school.edu"
	creds._school.text = "Rizal High School"
	creds._password.text = "hunter2"
	creds._confirm.text = "hunter2"
	_press(creds, "Submit")
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("loading_screen.gd"), "submit shows the loader")
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

	_screen().open_progress()
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("progress_screen.gd"), "progress opens")
	_press(_screen(), "back to menu")
	await get_tree().process_frame

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

	print("-- upload -> consent -> generation --")
	_screen().open_upload()
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("upload_screen.gd"), "upload opens")

	var upload := _screen()
	_check(upload._continue.disabled, "continue is blocked before a file is chosen")
	upload._on_file_selected("C:/Users/myles/OneDrive/Documents/reviewer.pdf")
	await get_tree().process_frame
	_check(upload._continue.disabled == false, "continue unlocks after a file is chosen")

	_press(upload, "Continue")
	await get_tree().process_frame
	var dialog: Node = null
	for child in upload.get_children():
		if child is BoardDialog:
			dialog = child
	_check(dialog != null, "backup consent dialog appears")
	_press(dialog, "OK")
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("generation_screen.gd"), "generation starts")

	print("-- generation fails clearly --")
	await get_tree().create_timer(1.5).timeout
	_check(_screen()._finished == true, "generation stops on failure")
	_check(_screen()._failure != "", "the failure is reported")
	_check(_screen()._using_sample == false, "no silent fallback")
	_check(_screen()._review.visible == false, "review is blocked after a failure")
	_check(_screen()._retry.visible == true, "retry is offered")
	_check(_screen()._sample.visible == false, "the demo sample button is hidden from students")
	_check(_screen()._failure.contains("Pick the file again"),
		"the failure text is aimed at a student")

	print("-- explicit sample fallback (developer path) --")
	# students cannot reach this; the developer switch is what reveals the button
	_screen()._on_use_sample()
	await get_tree().create_timer(1.2).timeout
	_check(_screen()._finished == true, "the explicit sample set finishes")
	_check(_screen()._using_sample == true, "the sample set is used on purpose")
	_check(_screen()._pct.text == "100%", "progress reaches 100%")

	print("-- review and edit --")
	_press(_screen(), "Review questions")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("review_screen.gd"), "review screen opens")
	_check(_screen()._questions.size() == QuizData.sample().size(), "questions arrive in the review screen")
	_check(_screen()._tab == "questions", "opens on the Questions tab")
	_check(_screen()._status.text.contains("valid"), "the sample set validates")

	print("-- review validation --")
	var review := _screen()
	var first_choice: LineEdit = review._rows[0]["choices"][0]
	first_choice.text = ""
	first_choice.text_changed.emit("")
	review._on_save()
	await get_tree().process_frame
	_check(_screen() == review, "an empty choice blocks save")
	_check(review._status.text.contains("empty"), "the empty choice is reported")
	first_choice.text = "Venus"
	first_choice.text_changed.emit("Venus")
	review._on_save()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("battle.gd"), "saving starts the encounter")
	_check(Nav.encounter_ready == true, "encounter marked ready after saving")

	print("-- quiz library --")
	var shelf := QuizLibrary.all()
	_check(shelf.size() == 1, "the saved quiz is filed exactly once")
	if shelf.size() == 1:
		var entry: Dictionary = shelf[0]
		_check(int(entry.get("count", 0)) > 0, "the library row knows how many questions")
		_check(not QuizLibrary.get_quiz(str(entry.get("id", ""))).is_empty(),
			"the quiz body loads back off disk")

		Nav.show_screen(load("res://scripts/screens/my_quizzes_screen.gd").new())
		await get_tree().process_frame
		_check(_screen().get_script().resource_path.ends_with("my_quizzes_screen.gd"),
			"my quizzes opens")

		_check(QuizLibrary.play(str(entry.get("id", ""))), "a library quiz hands itself to the battle")
		_check(QuizData.load_saved().get("questions", []).size() > 0,
			"playing rewrites the battle's quiz file")

		# the shelf is a tab on Progress, which is why the menu stays at three tiles
		Nav.show_screen(load("res://scripts/screens/progress_screen.gd").new())
		await get_tree().process_frame
		_check(_screen().get_script().resource_path.ends_with("progress_screen.gd"),
			"saved progress opens")
		_check(_screen()._tab == "progress", "progress opens on the profile tab")
		_screen().show_quizzes_tab()
		await get_tree().process_frame
		_check(_screen()._shelf != null and _screen()._shelf._rows.get_child_count() > 0,
			"the quizzes tab lists the saved quiz")

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

	print("")
	if failures == 0:
		print("ALL FLOW CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("%d FLOW CHECK(S) FAILED" % failures)
		get_tree().quit(1)
