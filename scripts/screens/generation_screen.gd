extends Control
## "Building Encounter": the five-stage generation screen.

const Cat := preload("res://scripts/ui/cat_mascot.gd")

const STAGES := [
	{"name": "Reading Files", "to": 18.0},
	{"name": "Extracting Text", "to": 38.0},
	{"name": "Writing Question", "to": 70.0},
	{"name": "Checking answer", "to": 88.0},
	{"name": "Building Encounter", "to": 100.0},
]

const SPEED := 26.0  # percent per second

var _progress: float = 0.0
var _stage: int = -1
var _finished: bool = false

var _bar: ProgressBar
var _pct: Label
var _stage_label: Label
var _chips: Array[PanelContainer] = []
var _chip_labels: Array[Label] = []
var _actions: VBoxContainer


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.NIGHT
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(780, 0)
	center.add_child(box)

	# status pill
	var pill_row := HBoxContainer.new()
	pill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(pill_row)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel",
		UITheme.padded(UITheme.box(UITheme.NIGHT_SOFT, Color(0.898, 0.702, 0.106, 0.35), 1, 20), 14, 7))
	var pill_label := UITheme.small("●   GENERATING", 11, UITheme.YELLOW)
	pill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(pill_label)
	pill_row.add_child(pill)

	# avatar
	var avatar_row := HBoxContainer.new()
	avatar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(avatar_row)
	var avatar := PanelContainer.new()
	avatar.add_theme_stylebox_override("panel",
		UITheme.box(UITheme.NIGHT_SOFT, Color(0.898, 0.702, 0.106, 0.45), 1, 44))
	avatar.custom_minimum_size = Vector2(88, 88)
	avatar_row.add_child(avatar)
	var cat: Control = Cat.new()
	cat.custom_minimum_size = Vector2(84, 84)
	cat.set("scale_factor", 0.8)
	avatar.add_child(cat)

	var title := UITheme.pixel("Your Encounter is Ready", 17, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := UITheme.small("Questions are checked and saved for offline play", 12, Color(0.62, 0.66, 0.72))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	box.add_child(gap)

	# progress row
	var head := HBoxContainer.new()
	box.add_child(head)
	_stage_label = UITheme.small("Reading Files", 11, Color(0.88, 0.89, 0.92))
	_stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_stage_label)
	_pct = UITheme.small("0%", 11, UITheme.YELLOW)
	head.add_child(_pct)

	_bar = ProgressBar.new()
	_bar.max_value = 100.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 8)
	var track := UITheme.box(Color(0.149, 0.157, 0.196), Color.TRANSPARENT, 0, 4)
	var fill := UITheme.box(UITheme.YELLOW, Color.TRANSPARENT, 0, 4)
	_bar.add_theme_stylebox_override("background", track)
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)

	# stage chips
	var chips_row := HBoxContainer.new()
	chips_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chips_row.add_theme_constant_override("separation", 8)
	box.add_child(chips_row)
	for stage_def in STAGES:
		var chip := PanelContainer.new()
		var label := UITheme.small("○   " + str(stage_def["name"]), 10, Color(0.45, 0.49, 0.55))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(label)
		_style_chip(chip, false, false)
		chips_row.add_child(chip)
		_chips.append(chip)
		_chip_labels.append(label)

	# actions revealed when generation finishes
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	_actions.modulate.a = 0.0
	box.add_child(_actions)

	var play := UITheme.button("Play Encounter", "navy", 42)
	play.custom_minimum_size = Vector2(260, 42)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_play)
	_actions.add_child(play)

	var back := UITheme.script_button("← Main menu", 19)
	back.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	back.add_theme_color_override("font_hover_color", UITheme.YELLOW)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new()))
	_actions.add_child(back)

	_apply_stage(0)


func _process(delta: float) -> void:
	if _finished:
		return
	_progress = minf(_progress + delta * SPEED, 100.0)
	_bar.value = _progress
	_pct.text = "%d%%" % int(_progress)

	var stage := 0
	for i in STAGES.size():
		if _progress < float(STAGES[i]["to"]):
			stage = i
			break
		stage = i
	_apply_stage(stage)

	if _progress >= 100.0:
		_finish()


func _apply_stage(stage: int) -> void:
	if stage == _stage:
		return
	_stage = stage
	_stage_label.text = str(STAGES[stage]["name"])
	for i in _chips.size():
		if i < stage:
			_style_chip(_chips[i], true, false)
			_chip_labels[i].text = "✓   " + str(STAGES[i]["name"])
		elif i == stage:
			_style_chip(_chips[i], false, true)
			_chip_labels[i].text = "●   " + str(STAGES[i]["name"])
		else:
			_style_chip(_chips[i], false, false)
			_chip_labels[i].text = "○   " + str(STAGES[i]["name"])


func _style_chip(chip: PanelContainer, done: bool, active: bool) -> void:
	var idx := _chips.find(chip)
	var label: Label = _chip_labels[idx] if idx >= 0 else null
	if done:
		chip.add_theme_stylebox_override("panel",
			UITheme.padded(UITheme.box(Color(0.898, 0.702, 0.106, 0.16), Color(0.898, 0.702, 0.106, 0.55), 1, 16), 12, 6))
		if label != null:
			label.add_theme_color_override("font_color", UITheme.YELLOW)
	elif active:
		chip.add_theme_stylebox_override("panel",
			UITheme.padded(UITheme.box(UITheme.YELLOW, Color.TRANSPARENT, 0, 16), 12, 6))
		if label != null:
			label.add_theme_color_override("font_color", UITheme.NIGHT)
	else:
		chip.add_theme_stylebox_override("panel",
			UITheme.padded(UITheme.box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.08), 1, 16), 12, 6))
		if label != null:
			label.add_theme_color_override("font_color", Color(0.45, 0.49, 0.55))


func _finish() -> void:
	_finished = true
	_bar.value = 100.0
	_pct.text = "100%"
	_stage_label.text = "Encounter built"
	for i in _chips.size():
		_style_chip(_chips[i], true, false)
		_chip_labels[i].text = "✓   " + str(STAGES[i]["name"])

	Nav.encounter_ready = true
	Nav.encounter_title = str(Nav.user.get("reviewer_file", "")).get_file().get_basename()
	if Nav.encounter_title == "":
		Nav.encounter_title = "Reviewer Encounter"
	Nav.save_profile()

	var tween := create_tween()
	tween.tween_property(_actions, "modulate:a", 1.0, 0.4)


func _play() -> void:
	var battle: Control = load("res://scenes/battle.tscn").instantiate()
	Nav.show_screen(battle)
