extends Control

@onready var email: LineEdit = %Email
@onready var password: LineEdit = %Password
@onready var error_label: Label = %Error
@onready var login_button: Button = %Login
@onready var show_password: Button = %ShowPassword

func _ready() -> void:
	login_button.pressed.connect(_login)
	show_password.pressed.connect(_toggle_password)
	%Forgot.pressed.connect(func() -> void: Nav.show_screen(load("res://scenes/ForgotPassword.tscn").instantiate()))
	%SignUp.pressed.connect(func() -> void: Nav.show_screen(load("res://scenes/SignUp.tscn").instantiate()))
	%Guest.pressed.connect(func() -> void: Nav.show_screen(load("res://scenes/SharedQuizJoin.tscn").instantiate()))
	%Google.pressed.connect(func() -> void: error_label.text = "Google sign-in is a presentation mock for now.")

func _toggle_password() -> void:
	password.secret = not password.secret
	show_password.text = "Show" if password.secret else "Hide"

func _login() -> void:
	error_label.text = ""
	var address: String = email.text.strip_edges()
	if not address.contains("@"):
		error_label.text = "Enter a valid email address."
		return
	if password.text.is_empty():
		error_label.text = "Enter your password."
		return
	login_button.disabled = true
	login_button.text = "Logging in..."
	AuthService.sign_in(address, password.text)
	await get_tree().create_timer(0.3).timeout
	login_button.disabled = false
	login_button.text = "Log in"
	Nav.user["username"] = address
	Nav.user["role"] = "student"
	var loader: Control = load("res://scenes/LoadingScreen.tscn").instantiate()
	loader.setup("login")
	Nav.show_screen(loader)
