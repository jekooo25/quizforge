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

## The server does the real work: a phone can't parse a PDF and shouldn't hold
## an API key. Progress parks at 92% until it answers, so the bar never lies
## about finishing.
const HOLD_AT := 92.0

var _client: QuizClient
var _payload: Dictionary = {}
var _server_done := false
var _using_sample := false
var _failure := ""

var _progress: float = 0.0
var _stage: int = -1
var _finished: bool = false

var _bar: ProgressBar
var _pct: Label
var _stage_label: Label
var _sub: Label
var _chips: Array[PanelContainer] = []
var _chip_labels: Array[Label] = []
var _actions: VBoxContainer
var _review: Button
var _retry: Button


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
	avatar.custom_minimum_size = Vector2(112, 112)
	avatar_row.add_child(avatar)
	var cat: Control = Cat.new()
	cat.custom_minimum_size = Vector2(108, 108)
	avatar.add_child(cat)

	var title := UITheme.pixel("Your Encounter is Ready", 17, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := UITheme.small("Questions are checked and saved for offline play", 12, Color(0.62, 0.66, 0.72))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(760, 0)
	box.add_child(sub)
	_sub = sub

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

	_review = UITheme.button("Review questions", "navy", 42)
	_review.custom_minimum_size = Vector2(280, 42)
	_review.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_review.pressed.connect(_review_questions)
	_actions.add_child(_review)

	_retry = UITheme.button("Try again", "cream", 36)
	_retry.custom_minimum_size = Vector2(200, 36)
	_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_retry.visible = false
	_retry.pressed.connect(_retry_generation)
	_actions.add_child(_retry)

	var back := UITheme.script_button("← Main menu", 19)
	back.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	back.add_theme_color_override("font_hover_color", UITheme.YELLOW)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new()))
	_actions.add_child(back)

	_apply_stage(0)
	_start_generation()


func _process(delta: float) -> void:
	if _finished:
		return
	# Park at the hold point until the server answers, then finish up.
	var ceiling := 100.0 if _server_done else HOLD_AT
	_progress = minf(_progress + delta * SPEED, ceiling)
	_bar.value = _progress
	_pct.text = "%d%%" % int(_progress)

	var stage := 0
	for i in STAGES.size():
		if _progress < float(STAGES[i]["to"]):
			stage = i
			break
		stage = i
	_apply_stage(stage)

	if _server_done and _progress >= 100.0:
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
	_stage_label.text = "Ready to review"
	for i in _chips.size():
		_style_chip(_chips[i], true, false)
		_chip_labels[i].text = "✓   " + str(STAGES[i]["name"])

	# Not marked ready yet: the encounter only becomes playable once the
	# student has reviewed and saved the set.
	Nav.encounter_title = _title_text()
	Nav.save_profile()

	_retry.visible = _failure != ""

	var tween := create_tween()
	tween.tween_property(_actions, "modulate:a", 1.0, 0.4)


# --------------------------------------------------------------- generation

func _start_generation() -> void:
	if _client == null:
		_client = QuizClient.new()
		add_child(_client)
		_client.generated.connect(_on_generated)
		_client.failed.connect(_on_failed)

	var path := str(Nav.user.get("reviewer_file", "")).strip_edges()
	if path == "" or not FileAccess.file_exists(path):
		_use_sample("No reviewer file was found, so a sample set is shown.")
		return

	_sub.text = "Sending your reviewer to the question server…"
	_sub.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72))
	_client.generate_file(path, 10)


func _on_generated(data: Dictionary) -> void:
	_payload = data
	_server_done = true
	_using_sample = false
	_failure = ""
	_progress = maxf(_progress, HOLD_AT)

	var provider := str(data.get("source", {}).get("provider", data.get("provider", "ai")))
	var wording := "written offline from the text" if provider == "offline" else "written by " + provider
	_sub.text = "Questions %s — review them before playing." % wording
	_sub.add_theme_color_override("font_color", Color(0.74, 0.78, 0.84))


func _on_failed(message: String) -> void:
	# Degrade rather than dead-end: a demo that dies because wifi dropped is
	# worse than a clearly-labelled sample set the student can edit.
	_failure = message
	_use_sample("%s Showing a sample set so you can keep going." % message)


func _use_sample(note: String) -> void:
	_using_sample = true
	_payload = {
		"title": str(Nav.user.get("reviewer_file", "")).get_file().get_basename(),
		"pages": [],
		"questions": QuizData.sample(),
		"source": {"provider": "sample"},
	}
	_server_done = true
	_progress = maxf(_progress, HOLD_AT)
	if _sub != null:
		_sub.text = note
		_sub.add_theme_color_override("font_color", Color(0.95, 0.75, 0.32))


func _retry_generation() -> void:
	_finished = false
	_server_done = false
	_failure = ""
	_using_sample = false
	_payload = {}
	_progress = 0.0
	_stage = -1
	_bar.value = 0.0
	_pct.text = "0%"
	_retry.visible = false
	_actions.modulate.a = 0.0
	_start_generation()


func _title_text() -> String:
	var t := str(_payload.get("title", "")).strip_edges()
	if t == "":
		t = str(Nav.user.get("reviewer_file", "")).get_file().get_basename()
	if t == "":
		t = "Reviewer Encounter"
	return t


func _review_questions() -> void:
	var screen: Control = load("res://scripts/screens/review_screen.gd").new()
	Nav.show_screen(screen.setup(_payload))
