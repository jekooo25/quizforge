extends Control

var course_id: String = ""
var course_title: String = "Course"
var quizzes: Array = []

func _ready() -> void:
	%Back.pressed.connect(_back)
	%Search.text_changed.connect(func(_value: String) -> void: _render())
	%SearchButton.pressed.connect(_render)
	%UploadReviewer.pressed.connect(_upload_reviewer)
	_refresh()

func _back() -> void:
	Nav.call_deferred("show_screen", load("res://scenes/HomeScreen.tscn").instantiate())

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_back()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()

func _refresh() -> void:
	var reply: Dictionary = await SharingService.api("/courses/%s/quizzes" % course_id)
	if not is_inside_tree(): return
	for child: Node in %Items.get_children():
		%Items.remove_child(child)
		child.queue_free()
	if not reply.get("ok", false):
		%Hint.text = str(reply.get("error", "Could not load course quizzes."))
		%Empty.visible = true
		%UploadReviewer.visible = true
		return
	quizzes = reply.get("quizzes", [])
	%Empty.visible = quizzes.is_empty()
	%UploadReviewer.visible = quizzes.is_empty()
	%Title.text = course_title
	_render()

func _render() -> void:
	for child: Node in %Items.get_children():
		%Items.remove_child(child)
		child.queue_free()
	var query: String = %Search.text.strip_edges().to_lower()
	var shown: int = 0
	for quiz_value: Variant in quizzes:
		var quiz: Dictionary = quiz_value as Dictionary
		if query != "" and not str(quiz.get("title", "")).to_lower().contains(query): continue
		var button: Button = Button.new()
		button.text = "%s  ·  %d questions\n%s  ·  %s" % [str(quiz.get("title", "Untitled quiz")), int(quiz.get("count", 0)), str(quiz.get("created_by", "Student")), str(quiz.get("section", "Section 101 · Mon/Wed 8:00–9:30 AM"))]
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_open_quiz.bind(quiz))
		%Items.add_child(button)
		shown += 1
	%Empty.visible = shown == 0
	%UploadReviewer.visible = quizzes.is_empty()

func _upload_reviewer() -> void:
	Nav.user["course_id"] = course_id
	Nav.call_deferred("show_screen", load("res://scenes/UploadReviewer.tscn").instantiate())

func _open_quiz(quiz: Dictionary) -> void:
	var id: String = QuizLibrary.add(str(quiz.get("title", "Course quiz")), quiz.get("questions", []) as Array, "received", "course-%s" % str(quiz.get("id", "")))
	var picker: Control = load("res://scenes/QuizDetails.tscn").instantiate()
	picker.library_id = id
	Nav.show_screen(picker)
