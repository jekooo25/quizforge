extends Control
## Main menu: three tiles over the campus photo, the mascot at the top right.
## The icons are pixel art drawn in code (scripts/ui/pixel_icons.gd).

const Cat := preload("res://scripts/ui/cat_mascot.gd")
const Icons := preload("res://scripts/ui/pixel_icons.gd")
const Quit := preload("res://scripts/ui/quit_dialog.gd")
const ShopButtonScene: PackedScene = preload("res://scenes/StarsShopMenuButton.tscn")

const INK := Color(0.15, 0.15, 0.18)

var _profile: Button
var _gear: Button
var _shop_button: Button
var _content: Control
var _quit_open := false


func _ready() -> void:
	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_apply_safe_area)
	_apply_safe_area()
	var cat: Control = Cat.new()
	_content.add_child(cat)
	cat.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	cat.offset_left = -222
	cat.offset_right = -2
	cat.offset_top = -12
	cat.offset_bottom = 208
	_add_corner_buttons()
	var greeting := UITheme.pixel(_greeting_text(), 32, Color.WHITE)
	greeting.position = Vector2(0, 120)
	greeting.add_theme_stylebox_override("normal", UITheme.padded(
		UITheme.box(Color(0.055, 0.14, 0.22, 0.94), Color.TRANSPARENT, 0, 12), 16, 10))
	greeting.add_theme_color_override("font_shadow_color", UITheme.NAVY)
	greeting.add_theme_constant_override("shadow_offset_x", 2)
	greeting.add_theme_constant_override("shadow_offset_y", 3)
	greeting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(greeting)
	_add_tiles()
	if OS.get_name() == "Android":
		get_tree().quit_on_go_back = false


func _apply_safe_area() -> void:
	if not is_instance_valid(_content):
		return
	var inset := Vector4(32, 24, 32, 24)
	if OS.get_name() == "Android":
		var safe := DisplayServer.get_display_safe_area()
		var window_size := Vector2(DisplayServer.window_get_size())
		if window_size.x > 0 and window_size.y > 0 and safe.has_area():
			var ratio := size / window_size
			inset.x += maxf(0, safe.position.x) * ratio.x
			inset.y += maxf(0, safe.position.y) * ratio.y
			inset.z += maxf(0, window_size.x - safe.end.x) * ratio.x
			inset.w += maxf(0, window_size.y - safe.end.y) * ratio.y
	_content.offset_left = inset.x
	_content.offset_top = inset.y
	_content.offset_right = -inset.z
	_content.offset_bottom = -inset.w


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_on_exit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_exit()


# ------------------------------------------------------------------ chrome

func _add_corner_buttons() -> void:
	_profile = _icon_button("profile", 80.0, Vector2.ZERO)
	_profile.tooltip_text = "Profile"
	_content.add_child(_profile)
	_profile.pressed.connect(_on_profile)
	_gear = _icon_button("gear", 80.0, Vector2(96, 0))
	_gear.tooltip_text = "Settings"
	_content.add_child(_gear)
	_gear.pressed.connect(open_settings)
	_shop_button = ShopButtonScene.instantiate() as Button
	_content.add_child(_shop_button)
	_shop_button.position = Vector2(192, 0)
	_shop_button.size = Vector2(344, 80)
	_shop_button.custom_minimum_size = Vector2(344, 80)
	_shop_button.add_theme_font_size_override("font_size", 24)
	_shop_button.text = "%d Stars | STARS SHOP" % TaskManager.stars_balance()
	_shop_button.pressed.connect(open_shop)


func _icon_button(icon_kind: String, px: float, at: Vector2) -> Button:
	var b := Button.new()
	b.flat = false
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.position = at
	b.size = Vector2(px, px)
	b.custom_minimum_size = Vector2(px, px)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := UITheme.CREAM if icon_kind == "gear" else UITheme.NAVY
		if state == "hover":
			bg = bg.lightened(0.12)
		elif state == "pressed":
			bg = bg.darkened(0.18)
		b.add_theme_stylebox_override(state, UITheme.box(bg, Color(0.45, 0.64, 0.69), 2, 12))

	var icon := _icon(icon_kind, px - 24)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_top = 12
	icon.offset_right = -12
	icon.offset_bottom = -12
	b.add_child(icon)
	return b


func _icon(icon_kind: String, px: float) -> Control:
	var icon: Control = Icons.new()
	icon.kind = icon_kind
	icon.custom_minimum_size = Vector2(px, px)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


# ------------------------------------------------------------------- tiles

func _add_tiles() -> void:
	var row := HBoxContainer.new()
	row.name = "MenuCards"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.anchor_top = 0.46
	row.anchor_bottom = 0.94
	row.add_theme_constant_override("separation", 20)
	row.add_child(_tile("Play Quizzes", "floppy", "Choose a saved quiz", open_progress, true))
	row.add_child(_tile("Upload Reviewer", "upload", "Create a new quiz", open_upload))
	row.add_child(_tile("Daily Tasks", "clipboard", "Complete tasks. Earn Stars!", _on_daily_task))


func _tile(caption: String, icon_kind: String, detail: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.name = caption.replace(" ", "")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_stretch_ratio = 1.18 if primary else 1.0
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var edge := UITheme.YELLOW if primary else Color(0.40, 0.57, 0.66)
	for state in ["normal", "hover", "pressed"]:
		var bg := Color(0.055, 0.14, 0.22, 0.96)
		if state == "hover":
			bg = Color(0.10, 0.24, 0.32, 0.98)
		elif state == "pressed":
			bg = Color(0.17, 0.34, 0.35, 1.0)
		button.add_theme_stylebox_override(state, UITheme.box(bg, edge, 3 if primary else 2, 16))
	button.add_theme_stylebox_override("focus", UITheme.box(Color.TRANSPARENT, Color.WHITE, 3, 16))
	button.pressed.connect(action)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12
	column.offset_right = -12
	column.offset_top = 14
	column.offset_bottom = -14
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	var icon := _icon(icon_kind, 88)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var title := UITheme.pixel(caption, 28, UITheme.YELLOW if primary else Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var subtitle := UITheme.sans(detail, 24, Color(0.77, 0.86, 0.88))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(subtitle)
	return button


# ---------------------------------------------------------------- actions

func open_settings() -> void:
	Nav.show_screen(load("res://scripts/screens/settings_screen.gd").new())


func open_upload() -> void:
	Nav.show_screen(load("res://scenes/UploadReviewer.tscn").instantiate())


func open_progress() -> void:
	Nav.show_screen(load("res://scenes/my_quizzes.tscn").instantiate() as Control)


func open_shop() -> void:
	var scene := load("res://scenes/StarsShop.tscn") as PackedScene
	if scene != null:
		Nav.show_screen(scene.instantiate() as Control)


func _on_daily_task() -> void:
	var scene := load("res://scenes/DailyTasks.tscn") as PackedScene
	if scene != null:
		Nav.show_screen(scene.instantiate() as Control)


func _on_profile() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.05, 0.06, 0.08, 0.42)
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var card := UITheme.panel(UITheme.CREAM, 18, 0.98)
	card.custom_minimum_size = Vector2(460, 0)
	center.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var title := UITheme.pixel("Profile", 18, UITheme.NAVY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	for pair in [
		["Name", Nav.display_name()],
		["School", str(Nav.user.get("school", ""))],
		["Student ID", str(Nav.user.get("student_id", ""))],
	]:
		column.add_child(_profile_row(str(pair[0]), str(pair[1])))

	var close := UITheme.button("Close", "navy", 40)
	close.pressed.connect(func() -> void:
		scrim.queue_free()
		center.queue_free())
	column.add_child(close)


func _profile_row(key: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var k := UITheme.sans(key, 15, UITheme.MUTED)
	k.custom_minimum_size = Vector2(110, 0)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(k)

	var shown := value if value.strip_edges() != "" else "—"
	var v := UITheme.sans(shown, 15, UITheme.INK)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	return row


func _on_exit() -> void:
	if _quit_open:
		return
	_quit_open = true
	var dialog: Control = Quit.new()
	add_child(dialog)
	dialog.tree_exited.connect(func() -> void: _quit_open = false)
	dialog.confirmed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/thank_you_screen.gd").new()))


func _greeting_text() -> String:
	return "Ready for your next battle?"
