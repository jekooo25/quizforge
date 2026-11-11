extends Control

@onready var logo: Label = %Logo
@onready var clouds: TextureRect = %Clouds
@onready var start_hint: Label = %StartHint

func _ready() -> void:
	var bob: Tween = create_tween().set_loops()
	bob.tween_property(logo, "position:y", -6.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(logo, "position:y", 0.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(start_hint, "modulate:a", 0.45, 1.6)
	pulse.tween_property(start_hint, "modulate:a", 1.0, 1.6)
	var drift: Tween = create_tween().set_loops()
	drift.tween_property(clouds, "position:x", 24.0, 16.0).set_trans(Tween.TRANS_SINE)
	drift.tween_property(clouds, "position:x", 0.0, 16.0).set_trans(Tween.TRANS_SINE)

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		Nav.show_screen(load("res://scripts/screens/login_screen.gd").new())
