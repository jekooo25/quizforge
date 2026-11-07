extends Control
## Mobile-landscape home screen. Layout lives in HomeScreen.tscn so it can be
## edited in Godot's scene tree instead of being assembled in code.

const MIN_TOUCH := Vector2(0, 48)

@onready var safe_margin: MarginContainer = get_node("SafeMargin")
@onready var status_label: Label = get_node("SafeMargin/RootColumn/StatusLabel")
@onready var stars_shop_button: Button = get_node("SafeMargin/RootColumn/TopBar/StarsShopButton")
@onready var main_content: HBoxContainer = get_node("SafeMargin/RootColumn/MainContent")
@onready var left_column: VBoxContainer = get_node("SafeMargin/RootColumn/MainContent/LeftColumn")
@onready var center_column: VBoxContainer = get_node("SafeMargin/RootColumn/MainContent/CenterColumn")
@onready var right_column: VBoxContainer = get_node("SafeMargin/RootColumn/MainContent/RightColumn")
@onready var start_battle_button: Button = get_node("SafeMargin/RootColumn/MainContent/RightColumn/StartBattleButton")
@onready var upload_reviewer_button: Button = get_node("SafeMargin/RootColumn/MainContent/RightColumn/UploadReviewerButton")
@onready var quiz_library_button: Button = get_node("SafeMargin/RootColumn/MainContent/RightColumn/QuizLibraryButton")
@onready var daily_tasks_button: Button = get_node("SafeMargin/RootColumn/BottomNav/DailyTasksButton")
@onready var profile_button: Button = get_node("SafeMargin/RootColumn/TopBar/ProfileButton")
@onready var settings_button: Button = get_node("SafeMargin/RootColumn/TopBar/SettingsButton")


func _ready() -> void:
	var backdrop: Control = PhotoBackdrop.create()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 0)
	_configure_schoolyard_cards()
	_apply_safe_area()
	resized.connect(_apply_safe_area)
	start_battle_button.pressed.connect(_start_quiz)
	upload_reviewer_button.pressed.connect(_open_upload)
	quiz_library_button.pressed.connect(_open_library)
	daily_tasks_button.pressed.connect(_open_daily_tasks)
	profile_button.pressed.connect(_show_profile_hint)
	settings_button.pressed.connect(_open_settings)
	stars_shop_button.text = "%d Stars | Shop" % TaskManager.stars_balance()
	if OS.get_name() == "Android":
		get_tree().quit_on_go_back = false


func _process(_delta: float) -> void:
	# Keyboard layout is refreshed from focus callbacks, not polled every frame.
	# Polling virtual_keyboard_get_height on desktop/headless produces a warning
	# on every frame and can overwhelm the debugger.
	pass


func _apply_safe_area() -> void:
	if not is_instance_valid(safe_margin):
		return
	var left := 16
	var top := 12
	var right := 16
	var bottom := 12
	if OS.get_name() == "Android":
		var safe: Rect2 = DisplayServer.get_display_safe_area()
		var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
		if safe.has_area() and window_size.x > 0 and window_size.y > 0:
			var scale := size / window_size
			left += roundi(maxf(0.0, safe.position.x) * scale.x)
			top += roundi(maxf(0.0, safe.position.y) * scale.y)
			right += roundi(maxf(0.0, window_size.x - safe.end.x) * scale.x)
			bottom += roundi(maxf(0.0, window_size.y - safe.end.y) * scale.y)
	safe_margin.add_theme_constant_override("margin_left", left)
	safe_margin.add_theme_constant_override("margin_top", top)
	safe_margin.add_theme_constant_override("margin_right", right)
	safe_margin.add_theme_constant_override("margin_bottom", bottom)
	_refresh_keyboard_inset()


func _refresh_keyboard_inset() -> void:
	return


func _configure_schoolyard_cards() -> void:
	_add_pixel_icon(profile_button, "profile")
	_add_pixel_icon(settings_button, "gear")
	var navy_panel: StyleBoxFlat = UITheme.box(Color(0.035, 0.085, 0.14, 0.94), UITheme.NAVY_HOT, 2, 14)
	var primary_panel: StyleBoxFlat = UITheme.box(Color(0.035, 0.085, 0.14, 0.96), UITheme.YELLOW, 3, 14)
	var cards: Array[Control] = [left_column, center_column, right_column]
	get_node("SafeMargin/RootColumn/MainContent/LeftColumn/JoinCard").visible = false
	get_node("SafeMargin/RootColumn/MainContent/LeftColumn/RecentLabel").visible = false
	get_node("SafeMargin/RootColumn/MainContent/LeftColumn/RecentScroll").visible = false
	get_node("SafeMargin/RootColumn/MainContent/CenterColumn/PortalFrame").visible = false
	for card: Control in cards:
		card.custom_minimum_size = Vector2(0, 180)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var wrapper: PanelContainer = PanelContainer.new()
		wrapper.name = "%sCard" % card.name
		wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
		wrapper.size_flags_stretch_ratio = card.size_flags_stretch_ratio
		wrapper.add_theme_stylebox_override("panel", primary_panel if card == cards[0] else navy_panel)
		var parent: Node = card.get_parent()
		var index: int = card.get_index()
		parent.remove_child(card)
		main_content.add_child(wrapper)
		main_content.move_child(wrapper, index)
		wrapper.add_child(card)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var primary: Control = left_column
	primary.add_theme_stylebox_override("panel", primary_panel)
	var play_label: Label = UITheme.pixel("Play Quizzes", 28, UITheme.YELLOW)
	var play_subtitle: Label = UITheme.sans("Choose a saved quiz", 20, UITheme.CREAM)
	left_column.add_child(play_label)
	left_column.add_child(play_subtitle)
	var upload_label: Label = UITheme.pixel("Upload Reviewer", 28, UITheme.CREAM)
	var upload_subtitle: Label = UITheme.sans("Create a new quiz", 20, UITheme.CREAM)
	center_column.add_child(upload_label)
	center_column.add_child(upload_subtitle)
	var daily_label: Label = UITheme.pixel("Daily Tasks", 28, UITheme.CREAM)
	var daily_subtitle: Label = UITheme.sans("Complete tasks. Earn Stars!", 20, UITheme.CREAM)
	right_column.add_child(daily_label)
	right_column.add_child(daily_subtitle)
	start_battle_button.text = "Play Quizzes"
	upload_reviewer_button.text = "Upload Reviewer"
	start_battle_button.reparent(left_column)
	upload_reviewer_button.reparent(center_column)
	quiz_library_button.visible = false
	if not OS.get_cmdline_user_args().has("--show-wip"):
		get_node("SafeMargin/RootColumn/BottomNav/InventoryButton").visible = false
		get_node("SafeMargin/RootColumn/BottomNav/LeaderboardsButton").visible = false
	var daily_card_button: Button = Button.new()
	daily_card_button.name = "DailyTasksCardButton"
	daily_card_button.text = "Daily Tasks"
	daily_card_button.pressed.connect(_open_daily_tasks)
	right_column.add_child(daily_card_button)
	for button: Button in [start_battle_button, upload_reviewer_button, daily_card_button]:
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", UITheme.box(UITheme.CREAM, UITheme.WOOD_LIGHT, 2, 12))
		button.add_theme_stylebox_override("hover", UITheme.box(UITheme.PAPER, UITheme.WOOD_LIGHT, 2, 12))
		button.add_theme_stylebox_override("pressed", UITheme.box(UITheme.PAPER, UITheme.WOOD_LIGHT, 2, 12))
		button.add_theme_color_override("font_color", UITheme.INK)
	for button: Button in [profile_button, settings_button, stars_shop_button]:
		button.add_theme_stylebox_override("normal", UITheme.box(UITheme.CREAM, UITheme.WOOD_LIGHT, 2, 10))
		button.add_theme_stylebox_override("hover", UITheme.box(UITheme.PAPER, UITheme.YELLOW_DEEP, 2, 10))
		button.add_theme_color_override("font_color", UITheme.INK)
	status_label.add_theme_color_override("font_color", UITheme.YELLOW)


func _add_pixel_icon(button: Button, kind: String) -> void:
	button.text = ""
	var icon: Control = preload("res://scripts/ui/pixel_icons.gd").new()
	icon.kind = kind
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10
	icon.offset_top = 10
	icon.offset_right = -10
	icon.offset_bottom = -10


func _start_quiz() -> void:
	var quizzes: Array = QuizLibrary.all()
	if quizzes.is_empty():
		status_label.text = "Save a quiz first, then start your battle here."
		return
	_open_library()


func _open_upload() -> void:
	Nav.show_screen(load("res://scenes/UploadReviewer.tscn").instantiate())


func _open_library() -> void:
	Nav.show_screen(load("res://scenes/my_quizzes.tscn").instantiate())


func _open_daily_tasks() -> void:
	Nav.show_screen(load("res://scenes/DailyTasks.tscn").instantiate())


func _open_shop() -> void:
	Nav.show_screen(load("res://scenes/StarsShop.tscn").instantiate())


func _open_settings() -> void:
	Nav.show_screen(load("res://scripts/screens/settings_screen.gd").new())


func _show_profile_hint() -> void:
	status_label.text = "Profile options are available from Settings."


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_viewport().set_input_as_handled()
		Nav.show_screen(load("res://scenes/HomeScreen.tscn").instantiate())
