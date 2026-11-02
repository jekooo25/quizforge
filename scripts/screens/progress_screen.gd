extends Control
## Progress: what we know about this student so far.

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
	board.custom_minimum_size = Vector2(660, 400)
	center.add_child(board)

	var title := UITheme.script("Progress", 34, UITheme.WOOD_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.content.add_child(title)

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
		board.content.add_child(row)

	var hint := UITheme.small(
		"Finish an upload to fill this in." if not Nav.encounter_ready else "",
		11, UITheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.content.add_child(hint)

	var back := UITheme.script_button("← back to menu", 20)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new()))
	board.content.add_child(back)
