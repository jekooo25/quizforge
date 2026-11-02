extends Control
## Sign up, step 1 of 2: the student's name.

var _first: LineEdit
var _middle: LineEdit
var _last: LineEdit
var _suffix: OptionButton
var _error: Label


func _ready() -> void:
	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := UITheme.panel(UITheme.CREAM, 18, 0.985)
	card.custom_minimum_size = Vector2(600, 0)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 11)
	card.add_child(box)

	box.add_child(UITheme.logo_dark(24))

	var heading := UITheme.sans("Your Full Name", 19, UITheme.INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 9)
	box.add_child(grid)

	_first = UITheme.field("Enter your first name")
	grid.add_child(UITheme.form_row("First Name", _first))
	_middle = UITheme.field("Enter your middle initial")
	grid.add_child(UITheme.form_row("Middle Initial", _middle))
	_last = UITheme.field("Enter your last name")
	grid.add_child(UITheme.form_row("Last Name", _last))

	_suffix = UITheme.select()
	for option in ["Suffix (if there's any)", "Jr.", "Sr.", "II", "III", "IV"]:
		_suffix.add_item(option)
	grid.add_child(UITheme.form_row("Suffix", _suffix))

	_error = UITheme.sans("", 13, UITheme.RED)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_error)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 40)
	box.add_child(buttons)

	var cancel := UITheme.button("Cancel", "navy", 42)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/login_screen.gd").new()))
	buttons.add_child(cancel)

	var next := UITheme.button("Next", "navy", 42)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(_on_next)
	buttons.add_child(next)

	_first.grab_focus()


func _on_next() -> void:
	var first := _first.text.strip_edges()
	var last := _last.text.strip_edges()
	if first == "" or last == "":
		_error.text = "First and last name are both required."
		return

	Nav.user["first_name"] = first
	Nav.user["middle_initial"] = _middle.text.strip_edges()
	Nav.user["last_name"] = last
	Nav.user["suffix"] = "" if _suffix.selected <= 0 else _suffix.get_item_text(_suffix.selected)

	Nav.show_screen(load("res://scripts/screens/signup_school_screen.gd").new())
