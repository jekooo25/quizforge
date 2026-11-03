extends Control
## Reviewer upload. On desktop this opens Godot's file dialog; the design's
## Android picker is the same step on a phone.

const Cat := preload("res://scripts/ui/cat_mascot.gd")

var _chosen_path := ""
var _file_label: Label
var _continue: Button
var _dialog: FileDialog
var _range: LineEdit
var _range_hint: Label


func _ready() -> void:
	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var cat: Control = Cat.new()
	cat.anchor_left = 0.5
	cat.anchor_right = 0.5
	cat.anchor_top = 0.0
	cat.anchor_bottom = 0.0
	cat.offset_left = -80.0
	cat.offset_right = 80.0
	cat.offset_top = -36.0
	cat.offset_bottom = 148.0
	add_child(cat)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var board := BoardCard.new()
	board.custom_minimum_size = Vector2(760, 400)
	center.add_child(board)

	var title := UITheme.script("Upload your reviewer", 32, UITheme.WOOD_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.content.add_child(title)

	var blurb := UITheme.sans(
		"Pick the reviewer you want to turn into an encounter.\nImages, documents and text files all work.",
		15, UITheme.INK)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.content.add_child(blurb)

	var drop := PanelContainer.new()
	drop.add_theme_stylebox_override("panel",
		UITheme.padded(UITheme.box(Color(1, 1, 1, 0.75), Color(0.78, 0.75, 0.67), 1, 10), 18, 16))
	drop.custom_minimum_size = Vector2(0, 64)
	board.content.add_child(drop)

	_file_label = UITheme.sans("No file selected", 14, UITheme.MUTED)
	_file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_file_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_file_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drop.add_child(_file_label)

	# Optional: read only part of a long PDF, e.g. the chapter being studied.
	var range_row := HBoxContainer.new()
	range_row.alignment = BoxContainer.ALIGNMENT_CENTER
	range_row.add_theme_constant_override("separation", 8)
	board.content.add_child(range_row)

	var range_label := UITheme.sans("PDF pages", 13, UITheme.MUTED)
	range_row.add_child(range_label)

	_range = UITheme.field("40-65 (optional)")
	_range.custom_minimum_size = Vector2(180, 32)
	_range.add_theme_font_size_override("font_size", UITheme.crisp(13))
	# Without this the field stretches to whatever height the row ends up with.
	_range.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_range.text = str(Nav.user.get("page_range", ""))
	_range.text_changed.connect(_on_range_changed)
	range_row.add_child(_range)

	# On its own line: inside the row a wrapping label gets one character of
	# width, wraps per-letter, and stretches the row down the board.
	_range_hint = UITheme.sans("Leave empty to sample the whole file", 11, UITheme.MUTED)
	_range_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.content.add_child(_range_hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	board.content.add_child(row)

	var pick := UITheme.button("Choose file", "cream", 42)
	pick.pressed.connect(_open_picker)
	row.add_child(pick)

	_continue = UITheme.button("Continue", "navy", 42)
	_continue.disabled = true
	_continue.pressed.connect(_on_continue)
	row.add_child(_continue)

	var back := UITheme.script_button("← back", 20)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new()))
	board.content.add_child(back)

	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.title = "Select items"
	_dialog.filters = PackedStringArray([
		"*.png,*.jpg,*.jpeg,*.webp ; Images",
		"*.txt,*.md,*.csv,*.json ; Documents",
		"*.pdf ; PDF",
		"* ; All files",
	])
	_dialog.size = Vector2i(760, 460)
	add_child(_dialog)
	_dialog.file_selected.connect(_on_file_selected)


func _open_picker() -> void:
	_dialog.popup_centered()


func _on_file_selected(path: String) -> void:
	_chosen_path = path
	_file_label.text = path.get_file()
	_file_label.add_theme_color_override("font_color", UITheme.INK)
	_continue.disabled = false


func _on_range_changed(_text: String) -> void:
	_range_hint.text = "Leave empty to sample the whole file"
	_range_hint.add_theme_color_override("font_color", UITheme.MUTED)


## (0, 0) means empty; (-1, -1) means the student typed something unreadable.
func _range_pair() -> Vector2i:
	var text := _range.text.strip_edges()
	if text == "":
		return Vector2i.ZERO
	var re := RegEx.new()
	var err := re.compile("(?i)^(?:pdf\\s+)?(?:pages?|pp?\\.?)?\\s*(\\d+)\\s*(?:(?:-|\\.\\.|to)\\s*(\\d+))?$")
	if err != OK:
		return Vector2i(-1, -1)
	var m := re.search(text)
	if m == null:
		return Vector2i(-1, -1)
	var low := int(m.get_string(1))
	var high := int(m.get_string(2)) if m.get_string(2) != "" else low
	if low < 1:
		return Vector2i(-1, -1)
	if high < low:
		var swap := low
		low = high
		high = swap
	return Vector2i(low, high)


func _on_continue() -> void:
	var pair := _range_pair()
	if pair.x == -1:
		_range_hint.text = "Use a range like 40-65, or leave it empty."
		_range_hint.add_theme_color_override("font_color", UITheme.RED)
		return
	Nav.user["page_range"] = "" if pair == Vector2i.ZERO else "%d-%d" % [pair.x, pair.y]

	var dialog := BoardDialog.ask("Allow permission to save data as backup?", "OK", "Cancel")
	add_child(dialog)
	dialog.confirmed.connect(_start_generation.bind(true))
	dialog.cancelled.connect(_start_generation.bind(false))


func _start_generation(save_backup: bool) -> void:
	Nav.user["reviewer_file"] = _chosen_path
	if save_backup:
		Nav.save_profile()
	Nav.show_screen(load("res://scripts/screens/generation_screen.gd").new())
