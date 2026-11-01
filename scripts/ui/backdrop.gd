extends Control
## The school courtyard, drawn in code: sky, brick facade, lawn, pavement, trees.
## Drawn in a fixed 1280x562 design space and scaled to whatever the viewport is.

const W := 1280.0
const H := 562.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var k: float = size.x / W
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, size.y / H))

	_sky()
	_clouds()
	_treeline()
	_lawn()
	_building(Rect2(150, 78, 490, 274))
	_annex(Rect2(762, 168, 322, 184))
	_pavement()
	_goal()
	_fence()

	# foreground trees over everything
	_tree(Vector2(92, 372), 1.15)
	_tree(Vector2(712, 386), 0.72)
	_tree(Vector2(1222, 392), 0.9)
	_bench(Vector2(250, 452))
	_bench(Vector2(1010, 452))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _sky() -> void:
	var bands := 26
	for i in bands:
		var t := float(i) / float(bands - 1)
		var c := UITheme.SKY_TOP.lerp(UITheme.SKY_LOW, t)
		draw_rect(Rect2(0.0, H * 0.62 * float(i) / float(bands), W, H * 0.62 / float(bands) + 1.0), c)


func _clouds() -> void:
	for spot in [Vector2(160, 96), Vector2(980, 58), Vector2(1178, 148)]:
		var c: Color = Color(1, 1, 1, 0.92)
		draw_circle(spot + Vector2(-34, 6), 20.0, c)
		draw_circle(spot, 30.0, c)
		draw_circle(spot + Vector2(36, 8), 22.0, c)
		draw_rect(Rect2(spot.x - 46, spot.y + 6, 92, 18), c)


func _treeline() -> void:
	# Distant tree canopy: overlapping circles instead of one polygon, which
	# avoids self-intersection when the silhouette dips.
	var base := 362.0
	draw_rect(Rect2(0, base - 40.0, W, 40.0), Color(0.298, 0.561, 0.318))
	var x := -10.0
	var i := 0
	while x <= W + 20.0:
		var h := 30.0 + 16.0 * sin(float(i) * 1.7) + 8.0 * cos(float(i) * 0.9)
		draw_circle(Vector2(x, base - h * 0.55), h * 0.62, Color(0.298, 0.561, 0.318))
		x += 26.0
		i += 1


func _lawn() -> void:
	draw_rect(Rect2(0, 350, W, 96), UITheme.GRASS)
	draw_rect(Rect2(0, 424, W, 26), UITheme.GRASS_DARK)


func _pavement() -> void:
	draw_rect(Rect2(0, 440, W, H - 440), UITheme.PAVE)
	for i in range(1, 7):
		var y: float = 440.0 + float(i) * 20.0
		draw_line(Vector2(0, y), Vector2(W, y), UITheme.PAVE_LINE, 1.0)
	var x := 0.0
	while x < W:
		draw_line(Vector2(x, 440), Vector2(x + 14, H), UITheme.PAVE_LINE, 1.0)
		x += 84.0


func _building(r: Rect2) -> void:
	# body
	draw_rect(r, UITheme.BRICK)
	# cornice + base
	draw_rect(Rect2(r.position.x - 10, r.position.y - 12, r.size.x + 20, 14), UITheme.TRIM)
	draw_rect(Rect2(r.position.x - 10, r.end.y - 8, r.size.x + 20, 16), UITheme.TRIM.darkened(0.08))
	# brick texture lines
	for i in range(1, 22):
		var y := r.position.y + float(i) * 12.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.045), 1.0)

	# three floors of windows
	var floors := 3
	var cols := 6
	var win := Vector2(52, 56)
	var gap := Vector2(26, 20)
	for f in floors:
		for c in cols:
			var pos := Vector2(
				r.position.x + 26.0 + float(c) * (win.x + gap.x),
				r.position.y + 22.0 + float(f) * (win.y + gap.y + 6.0)
			)
			var frame := Rect2(pos - Vector2(4, 4), win + Vector2(8, 8))
			draw_rect(frame, UITheme.TRIM)
			draw_rect(Rect2(pos, win), UITheme.GLASS)
			draw_line(Vector2(pos.x + win.x * 0.5, pos.y), Vector2(pos.x + win.x * 0.5, pos.y + win.y), UITheme.TRIM, 2.0)
			draw_line(Vector2(pos.x, pos.y + win.y * 0.5), Vector2(pos.x + win.x, pos.y + win.y * 0.5), UITheme.TRIM, 2.0)
			# reflection
			draw_rect(Rect2(pos + Vector2(6, 8), Vector2(14, 20)), Color(1, 1, 1, 0.18))

	# entrance
	var door := Rect2(r.position.x + r.size.x * 0.5 - 56.0, r.end.y - 96.0, 112.0, 96.0)
	draw_rect(Rect2(door.position - Vector2(14, 14), Vector2(door.size.x + 28, 14)), UITheme.TRIM)
	draw_rect(door, UITheme.WOOD_DARK)
	draw_rect(Rect2(door.position + Vector2(door.size.x * 0.5 - 2, 0), Vector2(4, door.size.y)), UITheme.WOOD)
	# steps
	for i in 3:
		draw_rect(Rect2(door.position.x - 20 - i * 12, door.end.y + i * 8, door.size.x + 40 + i * 24, 8), UITheme.TRIM.darkened(0.10))


func _annex(r: Rect2) -> void:
	draw_rect(r, Color(0.749, 0.694, 0.612))
	draw_rect(Rect2(r.position.x - 8, r.position.y - 10, r.size.x + 16, 12), Color(0.522, 0.494, 0.451))
	for i in 3:
		var win := Rect2(r.position.x + 26.0 + float(i) * 92.0, r.position.y + 42.0, 66.0, 74.0)
		draw_rect(Rect2(win.position - Vector2(5, 5), win.size + Vector2(10, 10)), UITheme.TRIM)
		draw_rect(win, UITheme.GLASS)
		draw_line(Vector2(win.position.x, win.position.y + 26), Vector2(win.end.x, win.position.y + 26), UITheme.TRIM, 2.0)


func _goal() -> void:
	var c := Color(0.949, 0.949, 0.949)
	draw_rect(Rect2(24, 262, 6, 96), c)
	draw_rect(Rect2(132, 262, 6, 96), c)
	draw_rect(Rect2(24, 262, 114, 6), c)
	for i in 4:
		draw_line(Vector2(30 + float(i) * 30, 268), Vector2(30 + float(i) * 30, 356), Color(1, 1, 1, 0.35), 1.0)


func _fence() -> void:
	var x := 1108.0
	draw_rect(Rect2(x, 214, 6, 214), Color(0.749, 0.765, 0.773))
	for i in range(0, 18):
		var px := x + float(i) * 10.0
		draw_line(Vector2(px, 216), Vector2(px + 10, 424), Color(1, 1, 1, 0.42), 1.0)
	draw_line(Vector2(x, 216), Vector2(1280, 216), Color(0.749, 0.765, 0.773), 5.0)
	draw_line(Vector2(x, 424), Vector2(1280, 424), Color(0.749, 0.765, 0.773), 5.0)


func _tree(at: Vector2, s: float) -> void:
	draw_rect(Rect2(at.x - 7 * s, at.y - 10 * s, 14 * s, 96 * s), Color(0.451, 0.318, 0.208))
	draw_circle(at + Vector2(-30, 6) * s, 40.0 * s, UITheme.GRASS_DARK)
	draw_circle(at + Vector2(30, 6) * s, 38.0 * s, UITheme.GRASS_DARK)
	draw_circle(at + Vector2(0, -26) * s, 46.0 * s, UITheme.GRASS)
	draw_circle(at + Vector2(-18, -40) * s, 26.0 * s, UITheme.GRASS.lightened(0.06))
	draw_circle(at + Vector2(22, -30) * s, 22.0 * s, UITheme.GRASS.lightened(0.04))

	# contact shadow
	draw_set_transform(Vector2(at.x, at.y + 92 * s), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 46.0 * s, Color(0, 0, 0, 0.16))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size.x / W, size.y / H))


func _bench(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 40, at.y, 80, 8), UITheme.WOOD_LIGHT)
	draw_rect(Rect2(at.x - 40, at.y + 12, 80, 7), UITheme.WOOD_LIGHT.darkened(0.1))
	draw_rect(Rect2(at.x - 34, at.y + 8, 5, 20), UITheme.WOOD_DARK)
	draw_rect(Rect2(at.x + 29, at.y + 8, 5, 20), UITheme.WOOD_DARK)
