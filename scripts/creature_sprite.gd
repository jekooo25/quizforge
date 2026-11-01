class_name CreatureSprite
extends Control
## Vector-drawn battler. No art assets: a blob body, eyes, and a hit flash.

var body_color: Color = Color(0.49, 0.84, 0.63)
var horns: bool = false
var facing: int = 1

var _flash: float = 0.0
var _squash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_creature(creature: Creature) -> void:
	body_color = creature.color
	horns = creature.horns
	queue_redraw()


func _draw() -> void:
	var s := size
	var center := Vector2(s.x * 0.5, s.y * 0.62)
	var radius: float = minf(s.x, s.y) * 0.34

	# Contact shadow, so the creature sits on the ground instead of floating.
	draw_set_transform(center + Vector2(0.0, radius * 1.05), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, radius * 0.92, Color(0.0, 0.0, 0.0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var body := body_color.lerp(Color.WHITE, _flash)
	var shade := body.darkened(0.22).lerp(Color.WHITE, _flash)

	if horns:
		var horn_w := radius * 0.30
		var left := PackedVector2Array([
			center + Vector2(-radius * 0.62, -radius * 0.66),
			center + Vector2(-radius * 0.90, -radius * 1.32),
			center + Vector2(-radius * 0.28, -radius * 0.82),
		])
		var right := PackedVector2Array([
			center + Vector2(radius * 0.62, -radius * 0.66),
			center + Vector2(radius * 0.90, -radius * 1.32),
			center + Vector2(radius * 0.28, -radius * 0.82),
		])
		draw_colored_polygon(left, shade)
		draw_colored_polygon(right, shade)
		draw_line(left[0], left[1], shade.lightened(0.15), maxf(1.0, horn_w * 0.2), true)

	# Body: a slightly flattened circle, with a soft shaded lower third.
	draw_set_transform(center, 0.0, Vector2(1.0, 0.92 + _squash))
	draw_circle(Vector2.ZERO, radius, body)
	var belly := body.lerp(shade, 0.45).lerp(Color.WHITE, _flash)
	draw_set_transform(center + Vector2(0.0, radius * 0.30), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, radius * 0.80, belly)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Gloss highlight.
	draw_set_transform(center + Vector2(-radius * 0.34, -radius * 0.42), -0.5, Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, radius * 0.30, Color(1, 1, 1, 0.22 + _flash * 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Eyes.
	var eye_gap := radius * 0.40
	var eye_y := center.y - radius * 0.12
	var eye_r := radius * 0.155
	for dir in [-1.0, 1.0]:
		var eye_pos := Vector2(center.x + dir * eye_gap, eye_y)
		draw_circle(eye_pos, eye_r, Color(0.10, 0.10, 0.14))
		draw_circle(eye_pos + Vector2(dir * eye_r * 0.30, -eye_r * 0.34), eye_r * 0.34,
			Color(1, 1, 1, 0.9))

	# Mouth: a small arc, drawn as a polyline so it reads at any size.
	var mouth_r := radius * 0.30
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI * 0.18 + (PI * 0.64) * (float(i) / 8.0)
		pts.append(center + Vector2(cos(a) * mouth_r, sin(a) * mouth_r * 0.8 + radius * 0.20))
	draw_polyline(pts, Color(0.10, 0.10, 0.14, 0.85), maxf(1.5, radius * 0.055), true)


func play_attack(lunge_towards: int) -> void:
	var home := position
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position", home + Vector2(46.0 * lunge_towards, -14.0), 0.12)
	tween.tween_property(self, "position", home, 0.22)


func play_hit() -> void:
	var tween := create_tween()
	tween.tween_method(_set_flash, 1.0, 0.0, 0.34)
	tween.parallel().tween_method(_set_squash, 0.18, 0.0, 0.34)

	var shake := create_tween()
	var home := position
	for i in 3:
		shake.tween_property(self, "position", home + Vector2(10.0 - i * 4.0, -4.0), 0.04)
		shake.tween_property(self, "position", home - Vector2(10.0 - i * 4.0, -4.0), 0.04)
	shake.tween_property(self, "position", home, 0.05)


func play_faint() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.25, 0.5)
	tween.tween_property(self, "rotation", 0.35, 0.5)


func _set_flash(v: float) -> void:
	_flash = v
	queue_redraw()


func _set_squash(v: float) -> void:
	_squash = v
	queue_redraw()
