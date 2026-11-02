extends Control
## Pixel-art icons for the menu, rasterised on a 20x20 grid so every edge stays
## blocky. Drawn in code like the rest of the art, so there are no bitmaps to
## lose and the shapes scale to any tile size.

const INK := Color(0.15, 0.15, 0.18)
const WHITE := Color(1, 1, 1)
const CREAM := Color(0.99, 0.96, 0.89)
const YELLOW := Color(1.0, 0.80, 0.24)
const PINK := Color(0.96, 0.56, 0.63)
const PINK_DEEP := Color(0.86, 0.32, 0.40)
const RED := Color(0.70, 0.17, 0.21)
const TEAL := Color(0.18, 0.60, 0.61)
const TEAL_DEEP := Color(0.10, 0.41, 0.44)
const GREEN := Color(0.36, 0.78, 0.44)
const BLUE := Color(0.37, 0.63, 0.88)
const GRAPHITE := Color(0.24, 0.24, 0.27)

const GRID := 20.0

var kind := "profile"


func _draw() -> void:
	var u := size.x / GRID
	match kind:
		"profile":
			_draw_profile(u)
		"gear":
			_draw_gear(u)
		"clipboard":
			_draw_clipboard(u)
		"upload":
			_draw_upload(u)
		"floppy":
			_draw_floppy(u)
		"library":
			_draw_library(u)


# ------------------------------------------------------------------ helpers

func _px(u: float, x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(x * u, y * u, w * u, h * u), col)


## Fills whole grid cells inside the circle, so the rim stays stepped.
func _disc(u: float, cx: float, cy: float, r: float, col: Color) -> void:
	_ring(u, cx, cy, 0.0, r, col)


func _ring(u: float, cx: float, cy: float, r_in: float, r_out: float, col: Color) -> void:
	for gy in range(int(GRID)):
		for gx in range(int(GRID)):
			var dx := float(gx) + 0.5 - cx
			var dy := float(gy) + 0.5 - cy
			var d := sqrt(dx * dx + dy * dy)
			if d <= r_out and d >= r_in:
				draw_rect(Rect2(gx * u, gy * u, u, u), col)


# ------------------------------------------------------------------- icons

func _draw_profile(u: float) -> void:
	_disc(u, 10.0, 10.0, 10.0, YELLOW)
	_disc(u, 10.0, 7.3, 3.3, WHITE)
	_disc(u, 10.0, 17.6, 5.6, WHITE)


func _draw_gear(u: float) -> void:
	# four cardinal teeth, four corner blocks, then the ring on top
	_px(u, 8.5, 0.6, 3.0, 4.2, GRAPHITE)
	_px(u, 8.5, 15.2, 3.0, 4.2, GRAPHITE)
	_px(u, 0.6, 8.5, 4.2, 3.0, GRAPHITE)
	_px(u, 15.2, 8.5, 4.2, 3.0, GRAPHITE)
	_px(u, 3.8, 3.8, 3.6, 3.6, GRAPHITE)
	_px(u, 12.6, 3.8, 3.6, 3.6, GRAPHITE)
	_px(u, 3.8, 12.6, 3.6, 3.6, GRAPHITE)
	_px(u, 12.6, 12.6, 3.6, 3.6, GRAPHITE)
	_ring(u, 10.0, 10.0, 3.1, 7.3, GRAPHITE)


func _draw_clipboard(u: float) -> void:
	# board with a dark outline
	_px(u, 2.8, 2.2, 11.0, 16.4, INK)
	_px(u, 3.7, 3.1, 9.2, 14.6, CREAM)

	# clip at the top
	_px(u, 6.8, 0.8, 6.2, 2.6, INK)
	_px(u, 7.7, 1.4, 4.4, 1.2, Color(0.84, 0.84, 0.84))

	# three checklist rows
	for i in 3:
		var y := 5.6 + float(i) * 3.7
		_px(u, 4.6, y, 2.3, 2.3, INK)
		_px(u, 5.1, y + 0.5, 1.3, 1.3, WHITE)
		_px(u, 7.7, y + 0.5, 4.4, 1.1, INK)

	# target, with the arrow already stuck in it
	for i in 4:
		_px(u, 17.4 - float(i) * 0.8, 8.8 + float(i) * 0.8, 1.3, 1.3, INK)

	_disc(u, 13.2, 14.2, 4.4, PINK)
	_disc(u, 13.2, 14.2, 3.2, CREAM)
	_disc(u, 13.2, 14.2, 2.1, PINK_DEEP)
	_disc(u, 13.2, 14.2, 1.0, CREAM)
	_disc(u, 13.2, 14.2, 0.4, RED)

	# the head, resting on the outer ring
	_px(u, 15.6, 10.8, 1.8, 1.8, INK)


func _draw_upload(u: float) -> void:
	# the second page peeking out behind
	_px(u, 5.6, 3.8, 9.4, 13.4, INK)
	_px(u, 6.4, 4.6, 7.8, 11.8, BLUE)

	# the page in front
	_px(u, 2.6, 1.8, 9.8, 13.8, INK)
	_px(u, 3.4, 2.6, 8.2, 12.2, YELLOW)
	_px(u, 10.4, 2.6, 1.4, 1.4, INK)

	for i in 3:
		_px(u, 4.6, 5.2 + float(i) * 2.2, 5.4, 1.0, INK)

	# upload badge
	_disc(u, 15.2, 13.0, 3.8, PINK)
	_px(u, 14.4, 11.5, 1.6, 3.4, WHITE)
	_px(u, 13.5, 11.6, 3.4, 1.2, WHITE)
	_px(u, 14.1, 10.8, 2.2, 1.2, WHITE)


func _draw_library(u: float) -> void:
	# a pile of quiz sheets, each offset a little so the stack reads
	_px(u, 2.2, 5.6, 13.0, 12.2, INK)
	_px(u, 3.0, 6.4, 11.4, 10.6, Color(0.84, 0.89, 0.97))

	_px(u, 4.2, 3.4, 13.0, 12.2, INK)
	_px(u, 5.0, 4.2, 11.4, 10.6, Color(0.95, 0.92, 0.84))

	_px(u, 6.2, 1.2, 12.4, 12.0, INK)
	_px(u, 7.0, 2.0, 10.8, 10.4, CREAM)

	for i in 3:
		_px(u, 8.4, 4.0 + float(i) * 2.4, 6.6, 0.9, INK)


func _draw_floppy(u: float) -> void:
	_px(u, 2.4, 2.4, 15.2, 15.2, INK)
	_px(u, 3.2, 3.2, 13.6, 13.6, TEAL)

	# shutter
	_px(u, 4.4, 3.2, 4.8, 4.8, TEAL_DEEP)
	_px(u, 6.4, 3.8, 1.0, 3.8, CREAM)

	# label
	_px(u, 10.4, 3.2, 6.4, 4.6, GREEN)
	_px(u, 12.4, 3.2, 0.9, 4.6, WHITE)

	# ruled lines
	for i in 3:
		_px(u, 4.4, 10.2 + float(i) * 1.9, 6.8, 0.9, CREAM)

	# save arrow
	_px(u, 13.3, 11.2, 1.4, 2.9, INK)
	_px(u, 12.3, 13.6, 3.4, 1.0, INK)
	_px(u, 12.9, 14.4, 2.2, 1.0, INK)
