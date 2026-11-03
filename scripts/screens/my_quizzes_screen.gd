extends Control
## My quizzes, as its own screen. It renders the shared shelf, which also appears
## as the Quizzes tab on Progress.

const Shelf := preload("res://scripts/ui/quiz_shelf.gd")

var _shelf: Control


func _ready() -> void:
	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var board := BoardCard.new()
	board.custom_minimum_size = Vector2(880, 430)
	center.add_child(board)

	var title := UITheme.script("My quizzes", 32, UITheme.WOOD_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.content.add_child(title)

	_shelf = Shelf.new()
	_shelf.delete_requested.connect(_confirm_delete)
	board.content.add_child(_shelf)

	var back := UITheme.script_button("← back to menu", 20)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new()))
	board.content.add_child(back)


func _confirm_delete(entry: Dictionary) -> void:
	var dialog := BoardDialog.ask(
		"Delete \"%s\"? This can't be undone." % str(entry.get("title", "Untitled")),
		"Delete", "Cancel")
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		QuizLibrary.remove(str(entry.get("id", "")))
		_shelf.refresh())
