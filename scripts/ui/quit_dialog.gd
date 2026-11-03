extends Control
## The exit confirmation from the design: a pale card, one centred question,
## and two plain text actions. Deliberately unlike the wooden BoardDialog.

signal confirmed
signal cancelled

const CARD := Color(0.945, 0.906, 0.906)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scrim := ColorRect.new()
	scrim.color = Color(0.08, 0.08, 0.10, 0.32)
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := UITheme.panel(CARD, 20, 1.0)
	card.custom_minimum_size = Vector2(470, 250)
	center.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)

	var question := UITheme.sans("Are you sure you want to exit game", 28, UITheme.INK)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size = Vector2(390, 120)
	question.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(question)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(row)

	row.add_child(_action("Yes", true))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	row.add_child(_action("No", false))


func _action(text: String, is_yes: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", UITheme.font_body)
	b.add_theme_font_size_override("font_size", UITheme.crisp(26))
	b.add_theme_color_override("font_color", UITheme.INK)
	b.add_theme_color_override("font_hover_color", UITheme.WOOD_DARK)
	b.add_theme_color_override("font_pressed_color", UITheme.WOOD)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 10
		empty.content_margin_right = 10
		empty.content_margin_top = 4
		empty.content_margin_bottom = 4
		b.add_theme_stylebox_override(state, empty)
	b.pressed.connect(func() -> void:
		if is_yes:
			confirmed.emit()
		else:
			cancelled.emit()
		queue_free())
	return b
