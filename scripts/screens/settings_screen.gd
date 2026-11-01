extends Control
## Settings: music and SFX sliders on the yellow panel from the design.

const Backdrop := preload("res://scripts/ui/backdrop.gd")


func _ready() -> void:
	var bg: Control = Backdrop.new()
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
