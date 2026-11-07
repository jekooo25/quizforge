extends Control
## Small reusable spinner used by the editable loading screen scene.

var _angle := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_angle += delta * 3.6
	queue_redraw()

func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5 - 4.0
	var center := size * 0.5
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.16), 6.0, true)
	draw_arc(center, radius, _angle, _angle + TAU * 0.26, 24, UITheme.YELLOW, 6.0, true)
