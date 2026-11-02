extends Control
## My quizzes: the shelf of everything this student has made, and later the ones
## they receive by code. Playing one hands it to the battle.

var _status: Label


func _ready() -> void:
	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var board := BoardCard.new()
	board.custom_minimum_size = Vector2(900, 440)
	center.add_child(board)

	var title := UITheme.script("My quizzes", 32, UITheme.WOOD_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.content.add_child(title)

	var entries := QuizLibrary.all()
	if entries.is_empty():
		var empty := UITheme.sans(
			"Nothing here yet — upload a reviewer to forge your first quiz.",
			15, UITheme.MUTED)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		board.content.add_child(empty)

		var make := UITheme.button("Upload a reviewer", "navy", 42)
		make.custom_minimum_size = Vector2(260, 42)
		make.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		make.pressed.connect(func() -> void:
			Nav.show_screen(load("res://scripts/screens/upload_screen.gd").new()))
		board.content.add_child(make)
	else:
		board.content.add_child(_list(entries))

	_status = UITheme.sans("", 12, UITheme.RED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.content.add_child(_status)

	var back := UITheme.script_button("← back to menu", 20)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new()))
	board.content.add_child(back)


func _list(entries: Array) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)

	for entry in entries:
		rows.add_child(_row(entry))
	return scroll


func _row(entry: Dictionary) -> PanelContainer:
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_stylebox_override("panel",
		UITheme.padded(UITheme.box(Color(1, 1, 1, 0.74), Color(0.80, 0.77, 0.69), 1, 10), 16, 10))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	wrap.add_child(row)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 1)
	row.add_child(text)

	var name_label := UITheme.script(str(entry.get("title", "Untitled")), 19, UITheme.INK)
	text.add_child(name_label)

	var bits := "%d questions  ·  %s  ·  %s" % [
		int(entry.get("count", 0)),
		_source_word(str(entry.get("source", "generated"))),
		_when(str(entry.get("created_at", ""))),
	]
	var meta := UITheme.sans(bits, 12, UITheme.MUTED)
	text.add_child(meta)

	var play := UITheme.button("Play", "navy", 36)
	play.custom_minimum_size = Vector2(94, 36)
	play.pressed.connect(_on_play.bind(str(entry.get("id", ""))))
	row.add_child(play)

	var drop := UITheme.button("Delete", "cream", 36)
	drop.custom_minimum_size = Vector2(94, 36)
	drop.pressed.connect(_on_delete.bind(entry))
	row.add_child(drop)
	return wrap


func _source_word(source: String) -> String:
	match source:
		"received":
			return "shared with you"
		_:
			return "made here"


func _when(stamp: String) -> String:
	if stamp.length() >= 10:
		return stamp.substr(0, 10)
	return "—"


func _on_play(id: String) -> void:
	if id == "" or not QuizLibrary.play(id):
		_status.text = "That quiz could not be loaded."
		return
	Nav.show_screen(load("res://scenes/battle.tscn").instantiate())


func _on_delete(entry: Dictionary) -> void:
	var dialog := BoardDialog.ask(
		"Delete \"%s\"? This can't be undone." % str(entry.get("title", "Untitled")),
		"Delete", "Cancel")
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		QuizLibrary.remove(str(entry.get("id", "")))
		Nav.show_screen(load("res://scripts/screens/my_quizzes_screen.gd").new()))
