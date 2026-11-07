extends Control
## Sign up, step 2 of 2: school credentials.

var _student_id: LineEdit
var _email: LineEdit
var _school: LineEdit
var _password: LineEdit
var _confirm: LineEdit
var _error: Label


func _ready() -> void:
	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := UITheme.panel(UITheme.CREAM, 18, 0.985)
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	box.add_child(UITheme.logo_dark(24))

	var heading := UITheme.sans("School credentials", 19, UITheme.INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	box.add_child(grid)

	_student_id = UITheme.field("Enter your student id number")
	grid.add_child(UITheme.form_row("Student ID #", _student_id))
	_email = UITheme.field("Enter your student email")
	grid.add_child(UITheme.form_row("Student email", _email))
	_school = UITheme.field("Enter your institution name")
	grid.add_child(UITheme.form_row("School name", _school))
	_password = UITheme.field("Create a password", true)
	grid.add_child(UITheme.form_row("Password", _password))
	_confirm = UITheme.field("Re-enter your password", true)
	grid.add_child(UITheme.form_row("Confirm", _confirm))

	_error = UITheme.sans("", 13, UITheme.RED)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_error)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 40)
	box.add_child(buttons)

	var back := UITheme.button("Go Back", "navy", 42)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/signup_name_screen.gd").new()))
	buttons.add_child(back)

	var submit := UITheme.button("Submit", "navy", 42)
	submit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submit.pressed.connect(_on_submit)
	buttons.add_child(submit)

	_student_id.grab_focus()


func _on_submit() -> void:
	var sid := _student_id.text.strip_edges()
	var email := _email.text.strip_edges()
	var school := _school.text.strip_edges()
	var pw := _password.text
	var confirm := _confirm.text

	if sid == "":
		_error.text = "Student ID is required."
		return
	if not email.contains("@") or not email.contains("."):
		_error.text = "That doesn't look like an email address."
		return
	if school == "":
		_error.text = "School name is required."
		return
	if pw.length() < 6:
		_error.text = "Password needs at least 6 characters."
		return
	if pw != confirm:
		_error.text = "Passwords don't match."
		return

	Nav.user["student_id"] = sid
	Nav.user["email"] = email
	Nav.user["school"] = school
	Nav.user["password"] = pw
	if str(Nav.user["username"]).strip_edges() == "":
		Nav.user["username"] = email.get_slice("@", 0)

	var loader: Control = load("res://scenes/LoadingScreen.tscn").instantiate()
	loader.setup("signup")
	Nav.show_screen(loader)
