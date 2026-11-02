extends Control
## The branded wait screen shown after login / sign up.

const SPRITE := preload("res://assets/sprites/cat_on_books.png")

const BLUE := Color(0.129, 0.216, 0.376)

var _mode: String = "login"


class Spinner extends Control:
	var _angle: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(52, 52)

	func _process(delta: float) -> void:
		_angle += delta * 3.6
		queue_redraw()

	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.5 - 4.0
		var c := size * 0.5
		draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.16), 6.0, true)
		draw_arc(c, r, _angle, _angle + TAU * 0.26, 24, UITheme.YELLOW, 6.0, true)


func setup(mode: String) -> Control:
	_mode = mode
	return self


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = BLUE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var art := TextureRect.new()
	art.texture = SPRITE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.custom_minimum_size = Vector2(200, 200)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)

	var heading := UITheme.sans("Sign up complete!" if _mode == "signup" else "Login successful!",
		30, Color.WHITE)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var sub := UITheme.sans("Please wait while we prepare your experience.",
		15, Color(1, 1, 1, 0.62))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var spinner := Spinner.new()
	spinner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(spinner)

	Nav.save_profile()
	await get_tree().create_timer(2.6).timeout
	if is_inside_tree():
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new())
