extends Control
## Login. The credential check is local-only for now — any non-empty username
## passes. The role tabs are real: they record which side of the app you are
## signing into, even though the menus do not branch on it yet.

## Student is the only live role. Teacher is shown but locked until teacher
## accounts exist; Admin is deliberately not offered here at all — an admin
## surface needs real authentication, not a tab anyone can tap.
const ROLES := [
	["student", "Student", false],
	["teacher", "Teacher · soon", true],
]

var _username: LineEdit
var _password: LineEdit
var _error: Label
var _tabs: Dictionary = {}
var _role := "student"


func _ready() -> void:
	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# a light card, not the cream one: the design lets the photo through
	var card := UITheme.panel(Color(0.93, 0.93, 0.93), 22, 0.92)
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)

	box.add_child(_role_row())

	var title := UITheme.pixel("Quizforge", 44, UITheme.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_username = _big_field("Username")
	box.add_child(_username)

	_password = _big_field("Password", true)
	box.add_child(_password)

	_error = UITheme.sans("", 13, UITheme.RED)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_error)

	var login := UITheme.button("Login", "navy", 46)
	login.custom_minimum_size = Vector2(240, 46)
	login.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	login.pressed.connect(_on_login)
	box.add_child(login)

	var signup := UITheme.button("Sign up", "navy", 46)
	signup.custom_minimum_size = Vector2(240, 46)
	signup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	signup.pressed.connect(_on_signup)
	box.add_child(signup)

	_refresh_tabs()
	_username.grab_focus()


# -------------------------------------------------------------------- roles

func _role_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)

	for entry in ROLES:
		var id := str(entry[0])
		var locked := bool(entry[2])
		var tab := Button.new()
		tab.text = str(entry[1])
		tab.disabled = locked
		tab.focus_mode = Control.FOCUS_NONE
		if not locked:
			tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.add_theme_font_size_override("font_size", UITheme.crisp(18))
		tab.pressed.connect(func() -> void: _pick_role(id))
		_tabs[id] = tab
		row.add_child(tab)

	return row


func _pick_role(id: String) -> void:
	_role = id
	Nav.user["role"] = id
	_refresh_tabs()


## Selected tab is the yellow pill; the others are white with yellow lettering.
func _refresh_tabs() -> void:
	for id in _tabs:
		var tab: Button = _tabs[id]
		if tab.disabled:
			# a locked role: visible, so the plan is legible, but plainly inert
			tab.add_theme_stylebox_override("disabled", _tab_style(Color(1, 1, 1, 0.55)))
			tab.add_theme_color_override("font_disabled_color", Color(0.72, 0.62, 0.42, 0.95))
			continue

		var chosen: bool = id == _role
		var bg := UITheme.YELLOW if chosen else Color(1, 1, 1, 0.95)
		var fg := Color(1, 1, 1, 0.98) if chosen else UITheme.YELLOW_DEEP
		tab.add_theme_stylebox_override("normal", _tab_style(bg))
		tab.add_theme_stylebox_override("hover", _tab_style(bg.lightened(0.05)))
		tab.add_theme_stylebox_override("pressed", _tab_style(bg.darkened(0.06)))
		tab.add_theme_color_override("font_color", fg)
		tab.add_theme_color_override("font_hover_color", fg)
		tab.add_theme_color_override("font_pressed_color", fg)


func _tab_style(bg: Color) -> StyleBoxFlat:
	return UITheme.padded(UITheme.box(bg, Color(0, 0, 0, 0), 0, 12), 22, 9)


# ------------------------------------------------------------------- fields

func _big_field(placeholder: String, secret := false) -> LineEdit:
	var f := UITheme.field(placeholder, secret)
	f.custom_minimum_size = Vector2(0, 50)
	f.alignment = HORIZONTAL_ALIGNMENT_LEFT
	f.add_theme_font_size_override("font_size", UITheme.crisp(16))
	f.add_theme_stylebox_override("normal",
		UITheme.padded(UITheme.box(Color.WHITE, Color(0, 0, 0), 2, 12), 16, 10))
	f.add_theme_stylebox_override("focus",
		UITheme.padded(UITheme.box(Color.WHITE, UITheme.YELLOW_DEEP, 2, 12), 16, 10))
	return f


# ------------------------------------------------------------------ actions

func _on_login() -> void:
	var entered := _username.text.strip_edges()
	if entered == "":
		_error.text = "Enter a username to continue."
		return
	Nav.user["username"] = entered
	Nav.user["role"] = _role
	Nav.show_screen(load("res://scripts/screens/loading_screen.gd").new().setup("login"))


func _on_signup() -> void:
	Nav.user["role"] = _role
	Nav.show_screen(load("res://scripts/screens/signup_name_screen.gd").new())
