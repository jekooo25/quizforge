extends Control
## The branded wait screen shown after login / sign up.

const Cat := preload("res://scripts/ui/cat_mascot.gd")

const BLUE := Color(0.208, 0.463, 0.706)

var _mode: String = "login"


class Books extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var base := size.y
		var specs := [
			{"c": Color(0.878, 0.290, 0.267), "y": 0.0, "w": 0.86},
			{"c": Color(0.976, 0.776, 0.259), "y": 26.0, "w": 0.74},
			{"c": Color(0.545, 0.365, 0.749), "y": 52.0, "w": 0.94},
			{"c": Color(0.949, 0.937, 0.898), "y": 78.0, "w": 0.80},
		]
		for s in specs:
			var bw: float = w * float(s["w"])
			var r := Rect2((w - bw) * 0.5, base - 104.0 + float(s["y"]), bw, 24.0)
			draw_rect(r, s["c"])
			draw_rect(Rect2(r.position.x, r.position.y, 7.0, r.size.y), Color(0, 0, 0, 0.16))
			draw_rect(Rect2(r.position.x + r.size.x - 7.0, r.position.y, 7.0, r.size.y), Color(1, 1, 1, 0.18))


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

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(210, 190)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(stack)

	var books := Books.new()
	stack.add_child(books)
	books.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var cat: Control = Cat.new()
	cat.anchor_left = 0.0
	cat.anchor_right = 1.0
	cat.anchor_top = 0.0
	cat.anchor_bottom = 0.0
	cat.offset_left = 24.0
	cat.offset_right = -24.0
	cat.offset_top = 0.0
	cat.offset_bottom = 132.0
	stack.add_child(cat)

	var heading := UITheme.pixel("Sign up complete!" if _mode == "signup" else "Login successful!", 17, Color.WHITE)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var sub := UITheme.small("Please wait while we prepare your experience.", 14, Color(1, 1, 1, 0.62))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var spinner := Spinner.new()
	spinner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(spinner)

	Nav.save_profile()
	await get_tree().create_timer(2.6).timeout
	if is_inside_tree():
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new())
