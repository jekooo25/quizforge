extends Control
## Splash: the OMSU crest, the portal name, the QuizForge credit, and a way in.
##
## Laid out to the start-screen frame: flat navy, crest on the left, name and
## credit in the right-hand column, mascot top right, pill button at the bottom
## of the same column. Everything is measured against the 1280 x 562 design
## frame, so it scales with the project's canvas_items stretch.

const Cat := preload("res://scripts/ui/cat_mascot.gd")
const CREST := preload("res://assets/sprites/omsu_logo.png")
const QUIZFORGE_LOGO := preload("res://assets/sprites/quizforge_logo.png")

const BG := Color(0.122, 0.239, 0.420)          # #1F3D6B
const TITLE_YELLOW := Color(0.945, 0.737, 0.043) # #F1BC0B
const BUTTON_YELLOW := Color(1.0, 0.773, 0.020)  # #FFC505
const WARM_WHITE := Color(0.961, 0.949, 0.914)   # #F5F2E9
const BUTTON_EDGE := Color(0.016, 0.027, 0.051)

const CREST_RECT := Rect2(66.0, 54.0, 450.0, 450.0)
const CAT_RECT := Rect2(1085.0, 60.0, 140.0, 140.0)
const COLUMN := Rect2(520.0, 106.0, 650.0, 0.0)
const BUTTON_RECT := Rect2(545.0, 443.0, 610.0, 103.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# --- crest, left
	var crest := TextureRect.new()
	crest.texture = CREST
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.offset_left = CREST_RECT.position.x
	crest.offset_top = CREST_RECT.position.y
	crest.offset_right = CREST_RECT.end.x
	crest.offset_bottom = CREST_RECT.end.y
	add_child(crest)

	# --- mascot, top right
	var cat: Control = Cat.new()
	cat.offset_left = CAT_RECT.position.x
	cat.offset_top = CAT_RECT.position.y
	cat.offset_right = CAT_RECT.end.x
	cat.offset_bottom = CAT_RECT.end.y
	add_child(cat)

	# --- name and credit, right column
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 44)
	column.offset_left = COLUMN.position.x
	column.offset_right = COLUMN.end.x
	column.offset_top = COLUMN.position.y
	column.offset_bottom = COLUMN.position.y + 160.0
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var title := _text("OMSU Review Portal", UITheme.font_pixel, 48, TITLE_YELLOW)
	column.add_child(title)

	var powered_row := HBoxContainer.new()
	powered_row.alignment = BoxContainer.ALIGNMENT_CENTER
	powered_row.add_theme_constant_override("separation", 18)
	column.add_child(powered_row)
	var credit := _text("powered by", UITheme.font_body, 30, WARM_WHITE)
	powered_row.add_child(credit)
	var logo := TextureRect.new()
	logo.texture = QUIZFORGE_LOGO
	logo.custom_minimum_size = Vector2(275, 52)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	powered_row.add_child(logo)

	# --- the way in
	var plaque := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BG.r, BG.g, BG.b, 0.0)
	style.border_color = BUTTON_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(30)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	plaque.add_theme_stylebox_override("panel", style)
	plaque.offset_left = BUTTON_RECT.position.x
	plaque.offset_top = BUTTON_RECT.position.y
	plaque.offset_right = BUTTON_RECT.end.x
	plaque.offset_bottom = BUTTON_RECT.end.y
	add_child(plaque)

	var hint := _text("Tap anywhere to start...", UITheme.font_pixel, 38, BUTTON_YELLOW)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plaque.add_child(hint)


func _text(body: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = body
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Nav.show_screen(load("res://scripts/screens/login_screen.gd").new())
	elif event is InputEventScreenTouch and event.pressed:
		Nav.show_screen(load("res://scripts/screens/login_screen.gd").new())
