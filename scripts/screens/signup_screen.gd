extends Control

@onready var display_name: LineEdit = %DisplayName
@onready var email: LineEdit = %Email
@onready var password: LineEdit = %Password
@onready var show_password: Button = %ShowPassword
@onready var error_label: Label = %Error

func _ready() -> void:
	%Create.pressed.connect(_create_account)
	%Back.pressed.connect(func() -> void: Nav.show_screen(load("res://scenes/Login.tscn").instantiate()))
	show_password.pressed.connect(_toggle_password)

func _toggle_password() -> void:
	password.secret = not password.secret
	show_password.text = "Show" if password.secret else "Hide"

func _create_account() -> void:
	if display_name.text.strip_edges().is_empty() or not email.text.contains("@") or password.text.is_empty():
		error_label.text = "Enter your name, a valid email, and a password."
		return
	if not %Age.button_pressed:
		error_label.text = "Please confirm that you are 13 or older."
		return
	if not %Terms.button_pressed:
		error_label.text = "Please agree to the Terms and Privacy Policy."
		return
	AuthService.sign_up(email.text.strip_edges(), password.text, display_name.text.strip_edges())
	error_label.text = "Account created. You can now log in."
