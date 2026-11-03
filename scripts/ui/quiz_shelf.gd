extends VBoxContainer
## The shelf of saved quizzes. Used both by the My Quizzes screen and by the
## Quizzes tab on Progress, so the two can never drift apart.
##
## Deleting asks the host screen to confirm, because a dialog added inside this
## shelf would be clipped to the shelf's rectangle.

signal delete_requested(entry: Dictionary)

const Icons := preload("res://scripts/ui/pixel_icons.gd")

var _rows: VBoxContainer
var _status: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 230)
	add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 10)
	scroll.add_child(_rows)

	_status = UITheme.sans("", 12, UITheme.RED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)

	refresh()


func refresh() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	var entries := QuizLibrary.all()
	if entries.is_empty():
		_rows.add_child(_empty_state())
		return
	for entry in entries:
		_rows.add_child(_row(entry))


func _empty_state() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)

	var icon: Control = Icons.new()
	icon.kind = "library"
	icon.custom_minimum_size = Vector2(96, 96)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var label := UITheme.sans(
		"No quizzes yet — upload a reviewer to forge your first one.", 14, UITheme.MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	return box


func _row(entry: Dictionary) -> PanelContainer:
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_stylebox_override("panel",
		UITheme.padded(UITheme.box(Color(1, 1, 1, 0.76), Color(0.80, 0.77, 0.69), 1, 10), 14, 8))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	wrap.add_child(row)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 1)
	row.add_child(text)

	text.add_child(UITheme.script(str(entry.get("title", "Untitled")), 18, UITheme.INK))

	var bits := "%d questions  ·  %s  ·  %s" % [
		int(entry.get("count", 0)),
		_source_word(str(entry.get("source", "generated"))),
		_when(str(entry.get("created_at", ""))),
	]
	text.add_child(UITheme.sans(bits, 12, UITheme.MUTED))

	var play := UITheme.button("Play", "navy", 34)
	play.custom_minimum_size = Vector2(88, 34)
	play.pressed.connect(_on_play.bind(str(entry.get("id", ""))))
	row.add_child(play)

	var drop := UITheme.button("Delete", "cream", 34)
	drop.custom_minimum_size = Vector2(88, 34)
	drop.pressed.connect(func() -> void: delete_requested.emit(entry))
	row.add_child(drop)
	return wrap


func _source_word(source: String) -> String:
	return "shared with you" if source == "received" else "made here"


func _when(stamp: String) -> String:
	return stamp.substr(0, 10) if stamp.length() >= 10 else "—"


func _on_play(id: String) -> void:
	if id == "" or not QuizLibrary.play(id):
		_status.text = "That quiz could not be loaded."
		return
	Nav.show_screen(load("res://scenes/battle.tscn").instantiate())
