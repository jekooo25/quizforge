extends Control
## Main menu: three tiles over the campus photo, the mascot at the top right.
## The icons are pixel art drawn in code (scripts/ui/pixel_icons.gd).

const Cat := preload("res://scripts/ui/cat_mascot.gd")
const Icons := preload("res://scripts/ui/pixel_icons.gd")

const INK := Color(0.15, 0.15, 0.18)

var _profile: Button
var _gear: Button


func _ready() -> void:
	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# head over the roofline, as in the design
	var cat: Control = Cat.new()
	cat.anchor_left = 1.0
	cat.anchor_right = 1.0
	cat.anchor_top = 0.0
	cat.anchor_bottom = 0.0
	cat.offset_left = -312.0
	cat.offset_right = -48.0
	cat.offset_top = -26.0
	cat.offset_bottom = 248.0
	add_child(cat)

	_add_corner_buttons()
	_add_tiles()
	_add_exit()


# ------------------------------------------------------------------ chrome

func _add_corner_buttons() -> void:
	_profile = _icon_button("profile", 76.0, Vector2(20, 16))
	add_child(_profile)
	_profile.pressed.connect(_on_profile)

	_gear = _icon_button("gear", 54.0, Vector2(31, 104))
	add_child(_gear)
	_gear.pressed.connect(open_settings)


func _icon_button(icon_kind: String, px: float, at: Vector2) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.position = at
	b.size = Vector2(px, px)
	b.custom_minimum_size = Vector2(px, px)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())

	var icon := _icon(icon_kind, px)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(icon)
	return b


func _icon(icon_kind: String, px: float) -> Control:
	var icon: Control = Icons.new()
	icon.kind = icon_kind
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


# ------------------------------------------------------------------- tiles

func _add_tiles() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 146)
	margin.add_theme_constant_override("margin_right", 146)
	margin.add_theme_constant_override("margin_top", 148)
	margin.add_theme_constant_override("margin_bottom", 32)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	margin.add_child(row)

	row.add_child(_tile("Daily and\nWeekly Task", "clipboard", _on_daily_task))
	row.add_child(_tile("Upload\nreviewer", "upload", open_upload))
	row.add_child(_tile("View saved\nprogress", "floppy", open_progress))


func _tile(text: String, icon_kind: String, action: Callable) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", _tile_style(0.50))
	b.add_theme_stylebox_override("hover", _tile_style(0.64))
	b.add_theme_stylebox_override("pressed", _tile_style(0.40))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(action)

	# children float over the button and must not eat its clicks
	var icon := _icon(icon_kind, 148.0)
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.anchor_top = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -74.0
	icon.offset_right = 74.0
	icon.offset_top = -108.0
	icon.offset_bottom = 40.0
	b.add_child(icon)

	# the caption sits in the lower third, as in the design
	var label := UITheme.pixel(text, 16, Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_constant_override("line_spacing", 10)
	label.anchor_left = 0.04
	label.anchor_right = 0.96
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_top = -96.0
	label.offset_bottom = -20.0
	b.add_child(label)
	return b


func _tile_style(alpha: float) -> StyleBoxFlat:
	var sb := UITheme.box(Color(1, 1, 1, alpha), Color(1, 1, 1, 0.0), 0, 22)
	sb.shadow_color = Color(0.10, 0.08, 0.04, 0.18)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


func _add_exit() -> void:
	var b := Button.new()
	b.text = "exit"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", UITheme.font_pixel)
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	b.add_theme_color_override("font_outline_color", Color(0.10, 0.09, 0.08, 0.85))
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_stylebox_override("normal", _exit_style(0.40))
	b.add_theme_stylebox_override("hover", _exit_style(0.58))
	b.add_theme_stylebox_override("pressed", _exit_style(0.72))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.anchor_left = 0.0
	b.anchor_right = 0.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = 24.0
	b.offset_right = 104.0
	b.offset_top = -52.0
	b.offset_bottom = -20.0
	add_child(b)
	b.pressed.connect(_on_exit)


func _exit_style(alpha: float) -> StyleBoxFlat:
	return UITheme.padded(
		UITheme.box(Color(0.10, 0.09, 0.08, alpha), Color(0, 0, 0, 0), 0, 12), 16, 7)


# ---------------------------------------------------------------- actions

func open_settings() -> void:
	Nav.show_screen(load("res://scripts/screens/settings_screen.gd").new())


func open_upload() -> void:
	Nav.show_screen(load("res://scripts/screens/upload_screen.gd").new())


func open_progress() -> void:
	Nav.show_screen(load("res://scripts/screens/progress_screen.gd").new())


func _on_daily_task() -> void:
	var dialog := BoardDialog.ask("Daily and Weekly Task is coming soon.", "OK", "Close")
	add_child(dialog)


func _on_profile() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.05, 0.06, 0.08, 0.42)
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := UITheme.panel(UITheme.CREAM, 18, 0.98)
	card.custom_minimum_size = Vector2(460, 0)
	center.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var title := UITheme.pixel("Profile", 18, UITheme.NAVY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	for pair in [
		["Name", Nav.display_name()],
		["School", str(Nav.user.get("school", ""))],
		["Student ID", str(Nav.user.get("student_id", ""))],
	]:
		column.add_child(_profile_row(str(pair[0]), str(pair[1])))

	var close := UITheme.button("Close", "navy", 40)
	close.pressed.connect(func() -> void:
		scrim.queue_free()
		center.queue_free())
	column.add_child(close)


func _profile_row(key: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var k := UITheme.sans(key, 15, UITheme.MUTED)
	k.custom_minimum_size = Vector2(110, 0)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(k)

	var shown := value if value.strip_edges() != "" else "—"
	var v := UITheme.sans(shown, 15, UITheme.INK)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	return row


func _on_exit() -> void:
	var dialog := BoardDialog.ask("Are you sure you want to exit the game?", "Yes", "No")
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		get_tree().quit())
