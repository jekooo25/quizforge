extends Control
## Settings: music and SFX, and a version label.
##
## There is deliberately no server field here. Students must never configure an
## address; the build ships with one (scripts/quiz/server_config.gd). For LAN
## testing there is a hidden developer menu behind seven taps on the version.

const TAPS_FOR_DEV := 7

var _taps := 0
var _version_label: Button
var _dev_field: LineEdit
var _dev_using: Label


func _ready() -> void:
	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override("panel", UITheme.padded(UITheme.box(UITheme.YELLOW, UITheme.YELLOW_DEEP, 2, 8), 0, 0))
	shell.custom_minimum_size = Vector2(640, 0)
	center.add_child(shell)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	shell.add_child(column)

	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UITheme.padded(UITheme.box(UITheme.YELLOW, Color.TRANSPARENT, 0, 8), 16, 10))
	column.add_child(bar)
	var bar_label := UITheme.pixel("Settings", 20, UITheme.INK)
	bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(bar_label)

	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel", UITheme.padded(UITheme.box(UITheme.CREAM, Color.TRANSPARENT, 0, 6), 34, 24))
	column.add_child(body)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	body.add_child(rows)

	rows.add_child(_slider_row("Music", 70))
	rows.add_child(_slider_row("SFX", 70))

	var back := UITheme.button("←  Main Menu", "cream", 40)
	back.custom_minimum_size = Vector2(200, 40)
	back.anchor_left = 0.0
	back.anchor_top = 1.0
	back.anchor_right = 0.0
	back.anchor_bottom = 1.0
	back.offset_left = 30.0
	back.offset_top = -76.0
	back.offset_right = 230.0
	back.offset_bottom = -26.0
	add_child(back)
	back.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new()))

	_add_version_label()


func _slider_row(label_text: String, initial: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)

	var l := UITheme.sans(label_text, 18, UITheme.INK)
	l.custom_minimum_size = Vector2(96, 0)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(0, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = initial
	var track := UITheme.box(Color(1, 1, 1, 0.9), Color(0.839, 0.812, 0.722), 1, 7)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", UITheme.box(Color(1.0, 0.855, 0.502), Color(0.949, 0.749, 0.243), 1, 7))
	slider.add_theme_stylebox_override("grabber_area_highlight", UITheme.box(Color(1.0, 0.878, 0.573), Color(0.949, 0.749, 0.243), 1, 7))
	var knob := UITheme.knob_texture(22)
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	row.add_child(slider)

	var value := UITheme.sans("%d" % int(initial), 15, UITheme.MUTED)
	value.custom_minimum_size = Vector2(40, 0)
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)

	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d" % int(v)
		Nav.user["volume_" + label_text.to_lower()] = int(v)
		if label_text == "Music":
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v / 100.0, 0.0001))))

	return row


# ------------------------------------------------------------------- version

func _add_version_label() -> void:
	# a pill, not bare text: on the courtyard photo bare grey type disappears
	_version_label = Button.new()
	_version_label.text = "v" + version()
	_version_label.focus_mode = Control.FOCUS_NONE
	_version_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_version_label.add_theme_font_override("font", UITheme.font_pixel)
	_version_label.add_theme_font_size_override("font_size", 10)
	_version_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_version_label.add_theme_color_override("font_outline_color", Color(0.10, 0.09, 0.08, 0.85))
	_version_label.add_theme_constant_override("outline_size", 3)
	_version_label.add_theme_stylebox_override("normal", _pill_style(0.42))
	_version_label.add_theme_stylebox_override("hover", _pill_style(0.60))
	_version_label.add_theme_stylebox_override("pressed", _pill_style(0.76))
	_version_label.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_version_label.anchor_left = 1.0
	_version_label.anchor_right = 1.0
	_version_label.anchor_top = 1.0
	_version_label.anchor_bottom = 1.0
	_version_label.offset_left = -108.0
	_version_label.offset_right = -26.0
	_version_label.offset_top = -48.0
	_version_label.offset_bottom = -18.0
	_version_label.pressed.connect(_on_version_press)
	add_child(_version_label)


func _pill_style(alpha: float) -> StyleBoxFlat:
	return UITheme.padded(
		UITheme.box(Color(0.10, 0.09, 0.08, alpha), Color(0, 0, 0, 0), 0, 10), 12, 5)


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func _on_version_press() -> void:
	_taps += 1
	if _taps >= TAPS_FOR_DEV:
		_taps = 0
		open_developer_menu()


# ------------------------------------------------------------- dev menu

## Hidden on purpose. Nothing here should ever be reachable by a student.
func open_developer_menu() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.05, 0.06, 0.08, 0.55)
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := UITheme.panel(UITheme.NIGHT_SOFT, 16, 0.98)
	card.custom_minimum_size = Vector2(580, 0)
	center.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)

	var title := UITheme.pixel("Developer", 16, UITheme.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var note := UITheme.sans(
		"Only for testing against a server on this machine or your LAN. "
		+ "Students never need this.",
		13, Color(0.72, 0.76, 0.82))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)

	_dev_field = UITheme.field("Server address")
	_dev_field.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dev_field.text = str(Nav.user.get("server_url", ""))
	column.add_child(_dev_field)

	_dev_using = UITheme.sans("In use: " + QuizClient.base_url(), 12, Color(0.66, 0.70, 0.76))
	column.add_child(_dev_using)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)

	var save := UITheme.button("Save", "navy", 38)
	save.custom_minimum_size = Vector2(130, 38)
	save.pressed.connect(func() -> void: _dev_save(_dev_field))
	row.add_child(save)

	var reset := UITheme.button("Reset to default", "cream", 38)
	reset.custom_minimum_size = Vector2(190, 38)
	reset.pressed.connect(_dev_reset)
	row.add_child(reset)

	var close := UITheme.button("Close", "cream", 38)
	close.custom_minimum_size = Vector2(120, 38)
	close.pressed.connect(func() -> void:
		scrim.queue_free()
		center.queue_free()
		_dev_field = null
		_dev_using = null)
	row.add_child(close)


func _dev_save(field: LineEdit) -> void:
	var url := field.text.strip_edges().trim_suffix("/")
	# typing "192.168.1.20:8765" should just work
	if url != "" and not url.contains("://"):
		url = "http://" + url
	field.text = url

	Nav.user["server_url"] = url
	Nav.save_profile()
	if _dev_using != null:
		_dev_using.text = "In use: " + QuizClient.base_url()


func _dev_reset() -> void:
	Nav.user["server_url"] = ""
	Nav.save_profile()
	if _dev_field != null:
		_dev_field.text = ""
	if _dev_using != null:
		_dev_using.text = "In use: " + QuizClient.base_url()
