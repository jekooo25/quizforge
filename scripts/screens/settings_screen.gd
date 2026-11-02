extends Control
## Settings: music and SFX sliders on the yellow panel from the design, plus
## the question-server address.

var _server_field: LineEdit
var _server_hint: Label


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
	rows.add_child(_server_row())

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
		if _server_field != null:
			_save_server(_server_field)
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new()))


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


## The question-server address, saved with the profile so one phone can be
## pointed at a LAN laptop or a deployed server without a rebuild.
func _server_row() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)

	var label := UITheme.sans("Server", 18, UITheme.INK)
	label.custom_minimum_size = Vector2(96, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var field := UITheme.field("http://192.168.1.20:8765")
	field.text = QuizClient.base_url()
	field.alignment = HORIZONTAL_ALIGNMENT_LEFT
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.text_submitted.connect(func(_t: String) -> void: _save_server(field))
	field.focus_exited.connect(func() -> void: _save_server(field))
	row.add_child(field)
	_server_field = field

	box.add_child(row)

	_server_hint = UITheme.sans(
		"Your laptop's LAN address for a demo, or the deployed HTTPS address.",
		12, UITheme.MUTED)
	_server_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_server_hint)
	return box


func _save_server(field: LineEdit) -> void:
	var url := field.text.strip_edges().trim_suffix("/")
	# typing "192.168.1.20:8765" should just work
	if url != "" and not url.contains("://"):
		url = "http://" + url
	field.text = url

	Nav.user["server_url"] = url
	Nav.save_profile()

	var effective := QuizClient.base_url()
	if effective == "":
		_server_hint.text = "No server set yet — generation will ask for one."
		_server_hint.add_theme_color_override("font_color", UITheme.RED)
	else:
		_server_hint.text = "Saved. Questions go to " + effective
		_server_hint.add_theme_color_override("font_color", UITheme.MUTED)
