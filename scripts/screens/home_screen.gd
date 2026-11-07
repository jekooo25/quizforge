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
@onready var start_battle_button: Button = get_node("SafeMargin/RootColumn/MainContent/CenterColumn/StartBattleButton")
@onready var upload_reviewer_button: Button = get_node("SafeMargin/RootColumn/MainContent/RightColumn/UploadReviewerButton")
@onready var quiz_library_button: Button = get_node("SafeMargin/RootColumn/MainContent/RightColumn/QuizLibraryButton")
@onready var daily_tasks_button: Button = get_node("SafeMargin/RootColumn/BottomNav/DailyTasksButton")
@onready var recent_list: VBoxContainer = get_node("SafeMargin/RootColumn/MainContent/LeftColumn/JoinCard/Padding/JoinColumn/RecentScroll/RecentList")
@onready var recent_label: Label = get_node("SafeMargin/RootColumn/MainContent/LeftColumn/JoinCard/Padding/JoinColumn/RecentLabel")
@onready var code_input: LineEdit = get_node("SafeMargin/RootColumn/MainContent/LeftColumn/JoinCard/Padding/JoinColumn/CodeInput")
@onready var join_button: Button = get_node("SafeMargin/RootColumn/MainContent/LeftColumn/JoinCard/Padding/JoinColumn/JoinButton")
@onready var profile_button: Button = get_node("SafeMargin/RootColumn/TopBar/ProfileButton")
@onready var settings_button: Button = get_node("SafeMargin/RootColumn/TopBar/SettingsButton")
@onready var course_list: VBoxContainer = get_node("SafeMargin/RootColumn/MainContent/LeftColumn/CoursePanel/CourseColumn/CourseList")


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
	stars_shop_button.pressed.connect(_open_shop)
	join_button.pressed.connect(_join_code)
	code_input.text_changed.connect(_on_code_changed)
	_refresh_recent_quizzes()
	_refresh_courses()
	stars_shop_button.text = "%d Stars | Shop" % TaskManager.stars_balance()
	stars_shop_button.add_theme_color_override("font_color", UITheme.INK)
	stars_shop_button.add_theme_font_size_override("font_size", 22)
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
			var safe_scale: Vector2 = size / window_size
			left += roundi(maxf(0.0, safe.position.x) * safe_scale.x)
			top += roundi(maxf(0.0, safe.position.y) * safe_scale.y)
			right += roundi(maxf(0.0, window_size.x - safe.end.x) * safe_scale.x)
			bottom += roundi(maxf(0.0, window_size.y - safe.end.y) * safe_scale.y)
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
	var cream_panel: StyleBoxFlat = UITheme.box(Color(0.96, 0.90, 0.78, 1.0), UITheme.WOOD_LIGHT, 2, 12)
	var navy_button: StyleBoxFlat = UITheme.box(UITheme.NAVY, UITheme.NAVY_HOT, 2, 10)
	var join_card: PanelContainer = get_node("SafeMargin/RootColumn/MainContent/LeftColumn/JoinCard")
	var course_panel: PanelContainer = get_node("SafeMargin/RootColumn/MainContent/LeftColumn/CoursePanel")
	var portal_frame: Control = get_node("SafeMargin/RootColumn/MainContent/CenterColumn/PortalFrame")
	join_card.visible = true
	portal_frame.visible = true
	join_card.add_theme_stylebox_override("panel", cream_panel)
	course_panel.add_theme_stylebox_override("panel", cream_panel)
	var course_heading: Label = get_node("SafeMargin/RootColumn/MainContent/LeftColumn/CoursePanel/CourseColumn/CourseHeading")
	course_heading.add_theme_color_override("font_color", UITheme.INK)
	course_heading.add_theme_font_size_override("font_size", 22)
	portal_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recent_label.visible = true
	recent_list.get_parent().visible = true
	var portal_label: Label = get_node("SafeMargin/RootColumn/MainContent/CenterColumn/PortalFrame/Stage/PortalLabel")
	portal_label.text = "Ready for your next battle?"
	portal_label.add_theme_color_override("font_color", UITheme.INK)
	portal_label.add_theme_font_size_override("font_size", 28)
	portal_label.add_theme_color_override("font_outline_color", UITheme.CREAM)
	portal_label.add_theme_constant_override("outline_size", 4)
	portal_label.add_theme_color_override("font_shadow_color", UITheme.NAVY)
	portal_label.add_theme_constant_override("shadow_offset_x", 2)
	portal_label.add_theme_constant_override("shadow_offset_y", 2)
	var pedestal: TextureRect = get_node("SafeMargin/RootColumn/MainContent/CenterColumn/PortalFrame/Stage/Pedestal")
	pedestal.visible = true
	start_battle_button.text = "Start battle"
	upload_reviewer_button.text = "Upload reviewer"
	quiz_library_button.text = "My quiz library"
	_add_button_icon(upload_reviewer_button, "upload")
	_add_button_icon(quiz_library_button, "library")
	_add_button_icon(daily_tasks_button, "clipboard")
	start_battle_button.reparent(center_column)
	upload_reviewer_button.reparent(right_column)
	quiz_library_button.visible = true
	for button: Button in [start_battle_button, upload_reviewer_button, quiz_library_button]:
		button.custom_minimum_size = Vector2(0, 64 if button == start_battle_button else 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", UITheme.box(UITheme.YELLOW, UITheme.WOOD, 2, 10) if button == start_battle_button else navy_button)
		button.add_theme_stylebox_override("hover", navy_button)
		button.add_theme_stylebox_override("pressed", navy_button)
		button.add_theme_color_override("font_color", UITheme.CREAM)
	start_battle_button.add_theme_color_override("font_color", UITheme.INK)
	code_input.visible = true
	join_button.visible = true
	join_button.disabled = true
	join_button.text = "↗ Join"
	_add_button_icon(join_button, "upload")
	join_button.disabled = false
	join_button.add_theme_stylebox_override("normal", navy_button)
	join_button.add_theme_stylebox_override("hover", navy_button)
	join_button.add_theme_color_override("font_color", UITheme.CREAM)
	code_input.add_theme_color_override("font_color", UITheme.INK)
	code_input.add_theme_color_override("font_placeholder_color", UITheme.WOOD)
	recent_label.add_theme_color_override("font_color", UITheme.INK)
	recent_label.add_theme_font_size_override("font_size", 24)
	var join_label: Label = get_node("SafeMargin/RootColumn/MainContent/LeftColumn/JoinCard/Padding/JoinColumn/EnterCodeLabel")
	join_label.text = "Join with code"
	join_label.add_theme_color_override("font_color", UITheme.INK)
	join_label.add_theme_font_size_override("font_size", 24)
	if not OS.get_cmdline_user_args().has("--show-wip"):
		get_node("SafeMargin/RootColumn/BottomNav/InventoryButton").visible = false
		get_node("SafeMargin/RootColumn/BottomNav/LeaderboardsButton").visible = false
	for button: Button in [profile_button, settings_button, stars_shop_button]:
		button.add_theme_stylebox_override("normal", UITheme.box(UITheme.CREAM, UITheme.WOOD_LIGHT, 2, 10))
		button.add_theme_stylebox_override("hover", UITheme.box(UITheme.PAPER, UITheme.YELLOW_DEEP, 2, 10))
		button.add_theme_color_override("font_color", UITheme.INK)
	status_label.add_theme_color_override("font_color", UITheme.INK)


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


func _add_button_icon(button: Button, kind: String) -> void:
	var original_text: String = button.text
	button.text = ""
	button.clip_text = false
	for child: Node in button.get_children():
		child.queue_free()
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "IconLabelRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_top = 6.0
	row.offset_right = -12.0
	row.offset_bottom = -6.0
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(row)
	var icon: Control = preload("res://scripts/ui/pixel_icons.gd").new()
	icon.kind = kind
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(30, 30)
	row.add_child(icon)
	var label: Label = UITheme.sans(original_text, 22, UITheme.CREAM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)


func _start_quiz() -> void:
	var quizzes: Array = QuizLibrary.all()
	if quizzes.is_empty():
		status_label.text = "Upload a reviewer first"
		return
	var picker: Control = load("res://scenes/QuizDetails.tscn").instantiate()
	picker.library_id = str(quizzes[0].get("id", ""))
	Nav.show_screen(picker)


func _refresh_recent_quizzes() -> void:
	for child: Node in recent_list.get_children():
		recent_list.remove_child(child)
		child.queue_free()
	var quizzes: Array = QuizLibrary.all()
	if quizzes.is_empty():
		var empty: Label = UITheme.sans("No saved quizzes yet. Upload a reviewer to make one.", 20, UITheme.INK)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		recent_list.add_child(empty)
		return
	var count: int = mini(3, quizzes.size())
	for index: int in count:
		var quiz: Dictionary = quizzes[index]
		var row: Button = Button.new()
		row.text = str(quiz.get("title", "Untitled quiz"))
		row.custom_minimum_size = Vector2(0, 48)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_stylebox_override("normal", UITheme.box(UITheme.CREAM, UITheme.WOOD_LIGHT, 1, 8))
		row.add_theme_color_override("font_color", UITheme.INK)
		var quiz_id: String = str(quiz.get("id", ""))
		row.pressed.connect(_open_recent.bind(quiz_id))
		recent_list.add_child(row)


func _refresh_courses() -> void:
	for child: Node in course_list.get_children():
		course_list.remove_child(child)
		child.queue_free()
	var reply: Dictionary = await SharingService.api("/courses")
	if not reply.get("ok", false):
		var unavailable: Label = UITheme.sans("Courses unavailable right now", 18, UITheme.INK)
		course_list.add_child(unavailable)
		return
	var courses: Array = reply.get("courses", [])
	if courses.is_empty():
		var empty: Label = UITheme.sans("No enrolled courses yet", 18, UITheme.INK)
		course_list.add_child(empty)
		return
	for course_value: Variant in courses:
		var course: Dictionary = course_value as Dictionary
		var row: Button = Button.new()
		row.text = "%s · %s" % [str(course.get("code", "")), str(course.get("title", "Course"))]
		row.custom_minimum_size = Vector2(0, 48)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_color_override("font_color", UITheme.INK)
		row.add_theme_stylebox_override("normal", UITheme.box(UITheme.CREAM, UITheme.WOOD_LIGHT, 1, 8))
		row.add_theme_stylebox_override("hover", UITheme.box(UITheme.PAPER, UITheme.YELLOW_DEEP, 2, 8))
		row.add_theme_stylebox_override("pressed", UITheme.box(UITheme.PAPER, UITheme.WOOD, 2, 8))
		row.pressed.connect(_open_course.bind(str(course.get("id", "")), str(course.get("title", "Course"))))
		course_list.add_child(row)


func _open_course(course_id: String, title: String) -> void:
	var screen: Control = load("res://scenes/CourseQuizzes.tscn").instantiate()
	screen.course_id = course_id
	screen.course_title = title
	Nav.show_screen(screen)


func _open_recent(quiz_id: String) -> void:
	var picker: Control = load("res://scenes/QuizDetails.tscn").instantiate()
	picker.library_id = quiz_id
	Nav.show_screen(picker)


func _on_code_changed(value: String) -> void:
	code_input.text = value.to_upper().strip_edges()
	code_input.caret_column = code_input.text.length()
	join_button.disabled = code_input.text.length() < 4


func _join_code() -> void:
	join_button.disabled = true
	status_label.text = "Connecting..."
	var health: Dictionary = await SharingService.api("/health")
	if not health.get("ok", false):
		status_label.text = "Can't reach the server. Check your connection and try again."
		join_button.disabled = false
		return
	var reply: Dictionary = await SharingService.join_quiz(code_input.text)
	if not reply.get("ok", false):
		status_label.text = "Can't reach the server. Check your connection and try again." if str(reply.get("error", "")).to_lower().contains("reach") else str(reply.get("error", "Could not join that quiz."))
		join_button.disabled = false
		return
	code_input.clear()
	status_label.text = "Quiz joined. It is now in My Quiz Library."
	join_button.disabled = true


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
	var profile: AcceptDialog = AcceptDialog.new()
	profile.title = "Profile"
	profile.dialog_text = "Username: %s\nSchool: %s" % [Nav.display_name(), str(Nav.user.get("school", "Not set"))]
	add_child(profile)
	profile.popup_centered()
	profile.confirmed.connect(profile.queue_free)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_viewport().set_input_as_handled()
		Nav.show_screen(load("res://scenes/HomeScreen.tscn").instantiate())
