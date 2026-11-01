extends Control
## Splash: the courtyard, the mascot, the logo, "tap anywhere".

const Backdrop := preload("res://scripts/ui/backdrop.gd")
const Cat := preload("res://scripts/ui/cat_mascot.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg: Control = Backdrop.new()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var cat: Control = Cat.new()
	cat.anchor_left = 0.5
	cat.anchor_right = 0.5
	cat.anchor_top = 0.0
	cat.anchor_bottom = 0.0
	cat.offset_left = -472.0
	cat.offset_right = -252.0
	cat.offset_top = 4.0
	cat.offset_bottom = 204.0
	add_child(cat)

	var title := UITheme.logo(44)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.0
	title.anchor_bottom = 0.0
	title.offset_left = -360.0
	title.offset_right = 360.0
	title.offset_top = 14.0
	title.offset_bottom = 98.0
	add_child(title)

	var hint := UITheme.pixel("Tap anywhere to start...", 15, UITheme.RED)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	hint.add_theme_constant_override("shadow_offset_x", 2)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 0.70
	hint.anchor_bottom = 0.70
	hint.offset_left = -320.0
	hint.offset_right = 320.0
	hint.offset_top = 0.0
	hint.offset_bottom = 40.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	var pulse := create_tween().set_loops()
	pulse.tween_property(hint, "modulate:a", 0.35, 0.9).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(hint, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_IN_OUT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Nav.show_screen(load("res://scripts/screens/login_screen.gd").new())
	elif event is InputEventScreenTouch and event.pressed:
		Nav.show_screen(load("res://scripts/screens/login_screen.gd").new())
