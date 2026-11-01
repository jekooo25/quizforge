class_name BoardCard
extends Control
## The wooden bulletin board from the design. Put children in `content`.

var content: VBoxContainer


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", 38)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(content)


func _draw() -> void:
	var r := Rect2(Vector2(3, 5), size)

	# drop shadow
	var shadow := UITheme.box(Color(0, 0, 0, 0.22), Color.TRANSPARENT, 0, 14)
	shadow.content_margin_left = 0
	draw_style_box(shadow, Rect2(Vector2(6, 10), size))

	# wood frame
	var frame := UITheme.box(UITheme.WOOD, UITheme.WOOD_DARK, 3, 12)
	draw_style_box(frame, r)

	# inner bevel
	var bevel := UITheme.box(UITheme.WOOD_LIGHT, Color.TRANSPARENT, 0, 8)
	draw_style_box(bevel, Rect2(r.position + Vector2(8, 8), r.size - Vector2(16, 16)))

	# cream sheet
	var paper := UITheme.box(UITheme.CREAM, UITheme.WOOD_DARK.lightened(0.12), 2, 4)
	draw_style_box(paper, Rect2(r.position + Vector2(18, 18), r.size - Vector2(36, 34)))

	# paper top shading, so the sheet reads as recessed
	draw_rect(Rect2(r.position + Vector2(20, 20), Vector2(r.size.x - 40, 10)), Color(0, 0, 0, 0.05))

	# eraser resting on the frame
	var ex := r.end.x - 78.0
	var ey := r.end.y - 30.0
	var eraser_back := UITheme.box(Color(0.855, 0.369, 0.318), Color(0.322, 0.208, 0.114), 2, 3)
	draw_style_box(eraser_back, Rect2(ex, ey, 46, 18))
	draw_rect(Rect2(ex + 2, ey + 12, 42, 4), Color(0.949, 0.937, 0.898))
