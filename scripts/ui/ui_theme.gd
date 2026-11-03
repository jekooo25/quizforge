class_name UITheme
extends RefCounted
## Shared look for Quizforge: palette, fonts, and widget factories.
## Everything visual lives here so a restyle is one file, not twenty.
## Static on purpose: call it as UITheme.pixel(...) from any screen.

# --- palette (sampled from the Figma frames)
const SKY_TOP := Color(0.478, 0.753, 0.902)
const SKY_LOW := Color(0.741, 0.886, 0.949)
const GRASS := Color(0.443, 0.741, 0.353)
const GRASS_DARK := Color(0.353, 0.639, 0.278)
const PAVE := Color(0.812, 0.839, 0.816)
const PAVE_LINE := Color(0.706, 0.741, 0.714)
const BRICK := Color(0.659, 0.329, 0.247)
const BRICK_DARK := Color(0.541, 0.267, 0.200)
const TRIM := Color(0.949, 0.937, 0.898)
const GLASS := Color(0.612, 0.788, 0.878)

const WOOD := Color(0.478, 0.322, 0.188)
const WOOD_LIGHT := Color(0.639, 0.435, 0.259)
const WOOD_DARK := Color(0.322, 0.208, 0.114)
const CREAM := Color(0.969, 0.937, 0.867)
const CREAM_SOFT := Color(0.988, 0.969, 0.914)

const NAVY := Color(0.086, 0.196, 0.310)
const NAVY_HOT := Color(0.125, 0.271, 0.416)
const NAVY_COLD := Color(0.062, 0.145, 0.235)

const YELLOW := Color(1.0, 0.784, 0.196)
const YELLOW_DEEP := Color(0.878, 0.659, 0.0)
const INK := Color(0.176, 0.184, 0.212)
const MUTED := Color(0.553, 0.588, 0.643)
const PAPER := Color(1.0, 1.0, 1.0)
const RED := Color(0.820, 0.322, 0.290)

const NIGHT := Color(0.059, 0.067, 0.090)
const NIGHT_SOFT := Color(0.098, 0.106, 0.137)
const NIGHT_LINE := Color(0.184, 0.196, 0.243)

## Display text — titles, tile captions, buttons, banners — is Monocraft.
## Body text (questions, choices, fields, the editor) inherits the app theme's
## default font, Pixelify Sans, from Project Settings → gui/theme/custom.
static var font_pixel: Font = preload("res://assets/themes/font_display.tres")
static var font_small: Font = preload("res://assets/themes/font_display.tres")
static var font_script: Font = preload("res://assets/themes/font_display.tres")
static var font_body: Font = preload("res://assets/themes/font_body.tres")


## Pixel faces read best on an even pixel rhythm. Neither shipped font has an
## integer design grid (measured on their outlines), so sizes snap to a 4 px
## step with a readable floor rather than pretending a native multiple exists.
static func crisp(size: int) -> int:
	return maxi(12, int(round(size / 4.0)) * 4)


# ------------------------------------------------------------------ labels

static func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", crisp(size))
	l.add_theme_color_override("font_color", color)
	return l


static func pixel(text: String, size := 16, color := INK) -> Label:
	return _label(text, font_pixel, size, color)


static func small(text: String, size := 14, color := MUTED) -> Label:
	return _label(text, font_small, size, color)


static func script(text: String, size := 28, color := INK) -> Label:
	return _label(text, font_script, size, color)


static func sans(text: String, size := 16, color := INK) -> Label:
	return _label(text, null, size, color)


# ------------------------------------------------------------------ boxes

static func box(bg: Color, border := Color.TRANSPARENT, border_w := 0, radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


static func padded(sb: StyleBoxFlat, x: float, y: float) -> StyleBoxFlat:
	sb.content_margin_left = x
	sb.content_margin_right = x
	sb.content_margin_top = y
	sb.content_margin_bottom = y
	return sb


# ------------------------------------------------------------------ widgets

static func button(text: String, variant := "navy", height := 44.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, height)
	b.add_theme_font_override("font", font_pixel)
	b.add_theme_font_size_override("font_size", crisp(16))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal: StyleBoxFlat
	var hover: StyleBoxFlat
	var pressed: StyleBoxFlat
	if variant == "navy":
		normal = padded(box(NAVY, NAVY_COLD, 1, 10), 22, 8)
		hover = padded(box(NAVY_HOT, NAVY, 1, 10), 22, 8)
		pressed = padded(box(NAVY_COLD, NAVY_COLD, 1, 10), 22, 8)
		b.add_theme_color_override("font_color", PAPER)
		b.add_theme_color_override("font_hover_color", PAPER)
		b.add_theme_color_override("font_pressed_color", YELLOW)
	else:
		normal = padded(box(CREAM, WOOD_LIGHT, 2, 10), 22, 8)
		hover = padded(box(PAPER, YELLOW_DEEP, 2, 10), 22, 8)
		pressed = padded(box(CREAM_SOFT, WOOD, 2, 10), 22, 8)
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", WOOD_DARK)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func field(placeholder: String, secret := false) -> LineEdit:
	var e := LineEdit.new()
	e.secret = secret
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0.0, 34.0)
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.add_theme_font_override("font", font_body)
	e.add_theme_font_size_override("font_size", crisp(15))
	e.add_theme_color_override("font_color", INK)
	e.add_theme_color_override("caret_color", INK)
	e.add_theme_color_override("font_placeholder_color", Color(0.62, 0.62, 0.62))
	e.add_theme_stylebox_override("normal", padded(box(PAPER, Color(0.796, 0.776, 0.722), 1, 7), 10, 6))
	e.add_theme_stylebox_override("focus", padded(box(PAPER, YELLOW_DEEP, 2, 7), 10, 6))
	return e


## A dropdown that matches the text fields instead of Godot's grey default.
static func select() -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(0.0, 34.0)
	o.add_theme_font_override("font", font_body)
	o.add_theme_font_size_override("font_size", crisp(14))
	o.add_theme_color_override("font_color", INK)
	o.add_theme_color_override("font_hover_color", INK)
	o.add_theme_color_override("font_pressed_color", INK)
	o.add_theme_color_override("font_focus_color", INK)
	o.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	o.add_theme_stylebox_override("normal", padded(box(PAPER, Color(0.796, 0.776, 0.722), 1, 7), 10, 6))
	o.add_theme_stylebox_override("hover", padded(box(PAPER, YELLOW_DEEP, 1, 7), 10, 6))
	o.add_theme_stylebox_override("pressed", padded(box(CREAM_SOFT, YELLOW_DEEP, 2, 7), 10, 6))
	o.add_theme_stylebox_override("focus", padded(box(PAPER, YELLOW_DEEP, 2, 7), 10, 6))
	return o


## A form row: right-aligned label, then the input.
static func form_row(label_text: String, control: Control, label_width := 150.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := sans(label_text, 15, INK)
	l.custom_minimum_size = Vector2(label_width, 0.0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


static func panel(color: Color, radius := 16, alpha := 0.94) -> PanelContainer:
	var p := PanelContainer.new()
	var c := color
	c.a = alpha
	var sb := padded(box(c, Color(0, 0, 0, 0), 0, radius), 26, 20)
	# a soft shadow so the card separates from a busy photo behind it
	sb.shadow_color = Color(0.10, 0.08, 0.04, 0.28)
	sb.shadow_size = 9
	sb.shadow_offset = Vector2(0, 4)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func logo(size := 40, tint := YELLOW, outline := Color(0.42, 0.26, 0.03, 0.6)) -> Label:
	var l := pixel("Quizforge", size, tint)
	if outline.a > 0.0:
		l.add_theme_color_override("font_outline_color", outline)
		l.add_theme_constant_override("outline_size", maxi(2, int(size / 14.0)))
	l.add_theme_color_override("font_shadow_color", Color(0.30, 0.18, 0.0, 0.30))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0.0, float(size) * 2.0)
	return l


## The logo as it appears on cream panels: dark, so it doesn't wash out.
static func logo_dark(size := 26) -> Label:
	return logo(size, WOOD_DARK, Color.TRANSPARENT)


static func pill(text: String, bg: Color, fg: Color, size := 11) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", padded(box(bg, Color(0, 0, 0, 0), 0, 20), 16, 7))
	var l := small(text, size, fg)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return p


static func knob_texture(diameter := 22, fill := YELLOW, rim := YELLOW_DEEP) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (diameter - 1) * 0.5
	for y in diameter:
		for x in diameter:
			var d := Vector2(x - c, y - c).length()
			if d <= c:
				img.set_pixel(x, y, rim)
			if d <= c - 1.5:
				img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)


## Text-only button used for menu items and back links.
static func script_button(text: String, size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_script)
	b.add_theme_font_size_override("font_size", crisp(size))
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", YELLOW_DEEP)
	b.add_theme_color_override("font_pressed_color", WOOD)
	b.add_theme_color_override("font_focus_color", INK)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 8
		empty.content_margin_right = 8
		empty.content_margin_top = 2
		empty.content_margin_bottom = 2
		b.add_theme_stylebox_override(state, empty)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b
