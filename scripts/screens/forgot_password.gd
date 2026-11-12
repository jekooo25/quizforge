extends Control
## Editable password-recovery screen. Accounts are local in this prototype,
## so it records the request instead of pretending an email was sent.

@onready var username: LineEdit = $Center/Card/Margin/Content/Username
@onready var email: LineEdit = $Center/Card/Margin/Content/Email
@onready var status: Label = $Center/Card/Margin/Content/Status
@onready var request_reset: Button = $Center/Card/Margin/Content/RequestReset
@onready var back: Button = $Center/Card/Margin/Content/Back


func _ready() -> void:
	request_reset.pressed.connect(_on_request_reset)
	back.pressed.connect(_back_to_login)
	username.grab_focus()


func _on_request_reset() -> void:
	if username.text.strip_edges() == "" or email.text.strip_edges() == "":
		status.text = "Enter both your username and school email."
		return
	status.add_theme_color_override("font_color", Color(0.15, 0.65, 0.4, 1))
	status.text = "Request recorded. Ask your teacher to reset this local demo account."
	request_reset.disabled = true


func _back_to_login() -> void:
	Nav.show_screen(load("res://scenes/Login.tscn").instantiate())
