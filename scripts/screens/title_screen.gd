extends Control

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		Nav.show_screen(load("res://scenes/Login.tscn").instantiate())
