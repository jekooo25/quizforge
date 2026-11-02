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
	_press(_screen(), "Settings")
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("settings_screen.gd"), "settings opens")
	_press(_screen(), "Main Menu")
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("menu_screen.gd"), "settings returns to menu")

	_press(_screen(), "View progress")
	await get_tree().process_frame
	_check(_screen().get_script().resource_path.ends_with("progress_screen.gd"), "progress opens")
	_press(_screen(), "back to menu")
	await get_tree().process_frame

	print("-- upload -> consent -> generation --")
	_press(_screen(), "Upload your reviewer")
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

	print("-- generation completes --")
	await get_tree().create_timer(5.0).timeout
	_check(_screen()._finished == true, "generation finished")
	_check(_screen()._pct.text == "100%", "progress reaches 100%")
	_check(_screen()._using_sample == true, "unreachable file falls back to the sample set")

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

	print("")
	if failures == 0:
		print("ALL FLOW CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("%d FLOW CHECK(S) FAILED" % failures)
		get_tree().quit(1)
