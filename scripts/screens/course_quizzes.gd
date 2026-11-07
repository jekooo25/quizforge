extends Control

var course_id: String = ""
var course_title: String = "Course"

func _ready() -> void:
	%Back.pressed.connect(_back)
	_refresh()

func _back() -> void:
	Nav.show_screen(load("res://scenes/HomeScreen.tscn").instantiate())

func _refresh() -> void:
	var reply: Dictionary = await SharingService.api("/courses/%s/quizzes" % course_id)
	if not is_inside_tree(): return
	for child: Node in %Items.get_children():
		%Items.remove_child(child)
		child.queue_free()
	if not reply.get("ok", false):
		%Hint.text = str(reply.get("error", "Could not load course quizzes."))
		%Empty.visible = true
		return
	var quizzes: Array = reply.get("quizzes", [])
	%Empty.visible = quizzes.is_empty()
	%Title.text = course_title
	for quiz_value: Variant in quizzes:
		var quiz: Dictionary = quiz_value as Dictionary
		var button: Button = Button.new()
		button.text = "%s  ·  %d questions" % [str(quiz.get("title", "Untitled quiz")), int(quiz.get("count", 0))]
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_open_quiz.bind(quiz))
		%Items.add_child(button)

func _open_quiz(quiz: Dictionary) -> void:
	var id: String = QuizLibrary.add(str(quiz.get("title", "Course quiz")), quiz.get("questions", []) as Array, "received", "course-%s" % str(quiz.get("id", "")))
	var picker: Control = load("res://scenes/QuizDetails.tscn").instantiate()
	picker.library_id = id
	Nav.show_screen(picker)
