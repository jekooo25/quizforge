extends Control
## The mascot, drawn in code. No sprite sheet: ears, glasses, blush, paws.

@export var scale_factor: float = 1.0
@export var mood: String = "happy"  # happy | thinking


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var k: float = minf(size.x, size.y) / 200.0 * scale_factor
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5), 0.0, Vector2(k, k))

	var body := Color(1.0, 1.0, 1.0)
	var rim := Color(0.816, 0.792, 0.855)
	var shade := Color(0.909, 0.898, 0.925)
	var pink := Color(0.976, 0.741, 0.792)
	var ink := Color(0.145, 0.145, 0.169)

	# tail
	draw_circle(Vector2(58, 28), 15.0, rim)

	# ears, with a rim so the silhouette holds against sky and brick
	var ear_l := PackedVector2Array([Vector2(-52, -26), Vector2(-30, -92), Vector2(-2, -40)])
	var ear_r := PackedVector2Array([Vector2(52, -26), Vector2(30, -92), Vector2(2, -40)])
	draw_colored_polygon(ear_l, rim)
	draw_colored_polygon(ear_r, rim)
	draw_colored_polygon(PackedVector2Array([Vector2(-46, -32), Vector2(-30, -80), Vector2(-10, -44)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(46, -32), Vector2(30, -80), Vector2(10, -44)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(-40, -40), Vector2(-30, -70), Vector2(-17, -48)]), pink)
	draw_colored_polygon(PackedVector2Array([Vector2(40, -40), Vector2(30, -70), Vector2(17, -48)]), pink)

	# body + head as one soft silhouette, rimmed
	draw_circle(Vector2(0, 40), 49.0, rim)
	draw_circle(Vector2(0, -6), 55.0, rim)
	draw_circle(Vector2(-40, 30), 23.0, rim)
	draw_circle(Vector2(40, 30), 23.0, rim)
	draw_circle(Vector2(0, 40), 45.0, body)
	draw_circle(Vector2(0, -6), 51.0, body)
	draw_circle(Vector2(-40, 30), 19.0, body)
	draw_circle(Vector2(40, 30), 19.0, body)

	# glasses
	var lens := 20.0
	draw_arc(Vector2(-23, -8), lens, 0.0, TAU, 32, ink, 3.4, true)
	draw_arc(Vector2(23, -8), lens, 0.0, TAU, 32, ink, 3.4, true)
	draw_line(Vector2(-3, -8), Vector2(3, -8), ink, 3.0, true)
	draw_line(Vector2(-43, -10), Vector2(-52, -14), ink, 2.6, true)
	draw_line(Vector2(43, -10), Vector2(52, -14), ink, 2.6, true)

	# eyes
	var blink := 1.0 if mood == "happy" else 0.75
	draw_circle(Vector2(-23, -8), 6.0 * blink, ink)
	draw_circle(Vector2(23, -8), 6.0 * blink, ink)
	draw_circle(Vector2(-21, -10), 2.0, Color.WHITE)
	draw_circle(Vector2(25, -10), 2.0, Color.WHITE)

	# blush
	draw_circle(Vector2(-37, 8), 7.0, Color(pink.r, pink.g, pink.b, 0.75))
	draw_circle(Vector2(37, 8), 7.0, Color(pink.r, pink.g, pink.b, 0.75))

	# mouth
	if mood == "happy":
		draw_arc(Vector2(0, 12), 9.0, 0.35, PI - 0.35, 16, ink, 2.6, true)
	else:
		draw_line(Vector2(-8, 14), Vector2(8, 14), ink, 2.6, true)

	# paws
	draw_circle(Vector2(-26, 62), 13.0, rim)
	draw_circle(Vector2(26, 62), 13.0, rim)
	draw_circle(Vector2(-26, 62), 10.0, body)
	draw_circle(Vector2(26, 62), 10.0, shade)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
