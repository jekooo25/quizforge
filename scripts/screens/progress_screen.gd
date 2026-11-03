extends Control
## Progress: what we know about this student, and the shelf of saved quizzes.
## Two tabs, because a student thinks of both as "my stuff".

const Shelf := preload("res://scripts/ui/quiz_shelf.gd")

var _tabs: Dictionary = {}
var _tab := "progress"
var _body: VBoxContainer
var _shelf: Control


func _or_dash(value: String) -> String:
	var v := value.strip_edges()
	return v if v != "" else "—"


func _ready() -> void:
	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var board := BoardCard.new()
	board.custom_minimum_size = Vector2(780, 462)
	center.add_child(board)

	var title := UITheme.script("Saved progress", 32, UITheme.WOOD_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.content.add_child(title)

	board.content.add_child(_tab_row())

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	board.content.add_child(_body)

	var back := UITheme.script_button("← back to menu", 20)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new()))
	board.content.add_child(back)

	_select_tab("progress")


# --------------------------------------------------------------------- tabs

func _tab_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	for pair in [["progress", "Progress"], ["quizzes", "Quizzes"]]:
		var key := str(pair[0])
		var tab := Button.new()
		tab.text = str(pair[1])
		tab.focus_mode = Control.FOCUS_NONE
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.add_theme_font_override("font", UITheme.font_script)
		tab.add_theme_font_size_override("font_size", 21)
		tab.pressed.connect(func() -> void: _select_tab(key))
		_tabs[key] = tab
		row.add_child(tab)
	return row


func _select_tab(key: String) -> void:
	_tab = key
	for id in _tabs:
		var tab: Button = _tabs[id]
		var chosen: bool = id == key
		tab.add_theme_color_override("font_color", UITheme.WOOD_DARK if chosen else UITheme.MUTED)
		tab.add_theme_color_override("font_hover_color", UITheme.WOOD_DARK)
		tab.add_theme_stylebox_override("normal", _tab_style(chosen))
		tab.add_theme_stylebox_override("hover", _tab_style(chosen))
		tab.add_theme_stylebox_override("pressed", _tab_style(true))

	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

	if key == "quizzes":
		_show_quizzes()
	else:
		_show_progress()


func _tab_style(chosen: bool) -> StyleBoxFlat:
	var bg := Color(1, 1, 1, 0.86) if chosen else Color(1, 1, 1, 0.30)
	var edge := UITheme.WOOD_DARK if chosen else Color(0, 0, 0, 0)
	return UITheme.padded(UITheme.box(bg, edge, 2 if chosen else 0, 10), 16, 4)


# ------------------------------------------------------------------ content

func _show_progress() -> void:
	# an empty field should read as empty, not as a blank row
	var who := Nav.display_name() if str(Nav.user.get("first_name", "")).strip_edges() != "" else "—"
	var lines := [
		{"k": "Student", "v": who},
		{"k": "School", "v": _or_dash(str(Nav.user.get("school", "")))},
		{"k": "Student ID", "v": _or_dash(str(Nav.user.get("student_id", "")))},
		{"k": "Reviewer", "v": _or_dash(str(Nav.user.get("reviewer_file", "")).get_file())},
		{"k": "Encounters", "v": Nav.encounter_title if Nav.encounter_ready else "0"},
	]
	for line in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var k := UITheme.sans(str(line["k"]), 16, UITheme.MUTED)
		k.custom_minimum_size = Vector2(180, 0)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(k)
		var v := UITheme.sans(str(line["v"]), 16, UITheme.INK)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(v)
		_body.add_child(row)

	var hint := UITheme.small(
		"Finish an upload to fill this in." if not Nav.encounter_ready else "",
		11, UITheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(hint)


func _show_quizzes() -> void:
	_shelf = Shelf.new()
	_shelf.delete_requested.connect(_confirm_delete)
	_body.add_child(_shelf)


## Used by the capture harness and the flow test to land directly on the tab.
func show_quizzes_tab() -> void:
	_select_tab("quizzes")


func _confirm_delete(entry: Dictionary) -> void:
	var dialog := BoardDialog.ask(
		"Delete \"%s\"? This can't be undone." % str(entry.get("title", "Untitled")),
		"Delete", "Cancel")
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		QuizLibrary.remove(str(entry.get("id", "")))
		if _shelf != null:
			_shelf.refresh())
