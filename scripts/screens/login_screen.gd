extends Control
## Login. The credential check is local-only for now — any non-empty pair passes.

const Backdrop := preload("res://scripts/ui/backdrop.gd")

var _username: LineEdit
var _password: LineEdit
var _error: Label


func _ready() -> void:
	var bg: Control = Backdrop.new()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := UITheme.panel(UITheme.CREAM, 18, 0.96)
	card.custom_minimum_size = Vector2(440, 0)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	box.add_child(UITheme.logo(26))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	_username = UITheme.field("Enter your username")
	box.add_child(_username)
	_password = UITheme.field("Enter your password", true)
	box.add_child(_password)

	_error = UITheme.sans("", 13, UITheme.RED)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_error)

	var login := UITheme.button("Login", "navy", 42)
	login.pressed.connect(_on_login)
	box.add_child(login)

	var or_label := UITheme.small("Or", 13, UITheme.MUTED)
	or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(or_label)

	var signup := UITheme.button("Sign up", "navy", 42)
	signup.pressed.connect(_on_signup)
	box.add_child(signup)

	var back := UITheme.sans("back", 12, UITheme.MUTED)
	back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			Nav.show_screen(load("res://scripts/screens/title_screen.gd").new()))
	box.add_child(back)

	_username.grab_focus()


func _on_login() -> void:
	var entered := _username.text.strip_edges()
	if entered == "":
		_error.text = "Enter a username to continue."
		return
	Nav.user["username"] = entered
	Nav.show_screen(load("res://scripts/screens/loading_screen.gd").new().setup("login"))


func _on_signup() -> void:
	Nav.show_screen(load("res://scripts/screens/signup_name_screen.gd").new())
