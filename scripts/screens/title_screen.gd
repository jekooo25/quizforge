extends Control
## Splash: the campus photo, the mascot, the logo, "tap anywhere".

const Cat := preload("res://scripts/ui/cat_mascot.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# mascot standing in front of the brick, where a cream sprite actually reads
	var cat: Control = Cat.new()
	cat.anchor_left = 0.30
	cat.anchor_right = 0.30
	cat.anchor_top = 0.30
	cat.anchor_bottom = 0.30
	cat.offset_left = -125.0
	cat.offset_right = 125.0
	cat.offset_top = 0.0
	cat.offset_bottom = 250.0
	add_child(cat)

	var title := UITheme.logo(46)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.0
	title.anchor_bottom = 0.0
	title.offset_left = -420.0
	title.offset_right = 420.0
	title.offset_top = 16.0
	title.offset_bottom = 112.0
	add_child(title)

	# the hint sits on a plaque so it stays readable over grass or pavement
	var plaque := PanelContainer.new()
	plaque.add_theme_stylebox_override("panel",
		UITheme.padded(UITheme.box(Color(0.988, 0.969, 0.914, 0.97),
			Color(0.42, 0.26, 0.03, 0.55), 2, 22), 24, 8))
	plaque.anchor_left = 0.5
	plaque.anchor_right = 0.5
	plaque.anchor_top = 1.0
	plaque.anchor_bottom = 1.0
	plaque.offset_left = -205.0
	plaque.offset_right = 205.0
	plaque.offset_top = -84.0
	plaque.offset_bottom = -34.0
	add_child(plaque)

	var hint := UITheme.pixel("Tap anywhere to start...", 14, UITheme.NAVY)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plaque.add_child(hint)

	var pulse := create_tween().set_loops()
	pulse.tween_property(plaque, "modulate:a", 0.62, 0.9).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(plaque, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_IN_OUT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Nav.show_screen(load("res://scripts/screens/login_screen.gd").new())
	elif event is InputEventScreenTouch and event.pressed:
		Nav.show_screen(load("res://scripts/screens/login_screen.gd").new())
