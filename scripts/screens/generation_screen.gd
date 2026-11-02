extends Control
## "Building Encounter": the five-stage generation screen.

const SPRITE := preload("res://assets/sprites/cat_on_books.png")
const Dev := preload("res://scripts/ui/dev.gd")

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
var _sample: Button
var _headline: Label
var _debug_label: Label
var _debug_lines: Array[String] = []


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
	var art := TextureRect.new()
	art.texture = SPRITE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.custom_minimum_size = Vector2(150, 150)
	avatar_row.add_child(art)

	var title := UITheme.pixel("Your Encounter is Ready", 17, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_headline = title

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

	# The old silent fallback, now something the student has to ask for.
	_sample = UITheme.button("Use sample questions (demo)", "cream", 36)
	_sample.custom_minimum_size = Vector2(280, 36)
	_sample.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sample.visible = false
	_sample.pressed.connect(_on_use_sample)
	_actions.add_child(_sample)

	var back := UITheme.script_button("← Main menu", 19)
	back.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82))
	back.add_theme_color_override("font_hover_color", UITheme.YELLOW)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new()))
	_actions.add_child(back)

	_apply_stage(0)
	if Dev.overlay_on():
		_build_debug_panel()
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

	_retry.visible = false
	_sample.visible = false
	_review.visible = true
	_dbg("finished — %s, %d questions" % [
		"sample" if _using_sample else "server/review",
		int(_payload.get("questions", []).size())])

	var tween := create_tween()
	tween.tween_property(_actions, "modulate:a", 1.0, 0.4)


# --------------------------------------------------------------- generation

## TEMPORARY diagnostics: printed to the console and drawn over the screen.
func _dbg(line: String) -> void:
	print("[quizgen] ", line)
	_debug_lines.append(line)
	while _debug_lines.size() > 7:
		_debug_lines.pop_front()
	if _debug_label != null:
		_debug_label.text = "\n".join(_debug_lines)


func _build_debug_panel() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# top-left, where it does not cover the action buttons
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 12.0
	panel.offset_right = 620.0
	panel.offset_top = 8.0
	panel.offset_bottom = 118.0
	panel.add_theme_stylebox_override("panel",
		UITheme.padded(UITheme.box(Color(0, 0, 0, 0.78),
			Color(0.45, 0.95, 0.45, 0.4), 1, 6), 8, 5))
	add_child(panel)

	_debug_label = UITheme.small("", 9, Color(0.72, 1.0, 0.72))
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_debug_label)


func _start_generation() -> void:
	if _client == null:
		_client = QuizClient.new()
		add_child(_client)
		_client.generated.connect(_on_generated)
		_client.failed.connect(_on_failed)

	var path := str(Nav.user.get("reviewer_file", "")).strip_edges()
	var exists := FileAccess.file_exists(path)
	var size := FileAccess.get_file_as_bytes(path).size() if exists else -1
	var page_range := str(Nav.user.get("page_range", "")).strip_edges()
	_dbg("file: " + path)
	_dbg("exists: %s  bytes: %d" % [exists, size])
	_dbg("server: " + QuizClient.base_url())
	_dbg("PDF pages: " + (page_range if page_range != "" else "(whole file, sampled)"))

	if path == "" or not exists:
		_fail("No reviewer file found. Pick the file again.")
		return

	_sub.text = "Building your questions…"
	_sub.add_theme_color_override("font_color", Color(0.62, 0.66, 0.72))
	_client.generate_file(path, 10, page_range, Time.get_ticks_msec())


func _on_generated(data: Dictionary) -> void:
	var questions: Array = data.get("questions", [])
	var pages: Array = data.get("pages", [])
	var source: Dictionary = data.get("source", {})
	var provider := str(source.get("provider", data.get("provider", "ai")))
	var used: Array = source.get("used_pages", [])
	var skipped: Array = source.get("skipped_front_matter", [])
	_dbg("HTTP 200 — provider: %s  pages: %d  questions: %d" % [
		provider, pages.size(), questions.size()])
	_dbg("PDF pages used: %s" % _page_span(used))
	if not skipped.is_empty():
		_dbg("skipped front matter: " + _page_span(skipped))

	if questions.is_empty():
		_fail("We couldn't make questions from that file. Try again, or pick a different file.")
		return

	_payload = data
	_server_done = true
	_using_sample = false
	_failure = ""
	_progress = maxf(_progress, HOLD_AT)
	_review.visible = true
	_sample.visible = false
	_retry.visible = false

	var wording := "written offline from the text" if provider == "offline" else "written by " + provider
	_sub.text = "Questions %s — PDF pages %s. Review them before playing." % [
		wording, _page_span(used)]
	_sub.add_theme_color_override("font_color", Color(0.74, 0.78, 0.84))


## 40, 41, 42, 50 -> "40-42, 50"
func _page_span(pages: Array) -> String:
	if pages.is_empty():
		return "none"
	var nums: Array[int] = []
	for p in pages:
		nums.append(int(p))
	nums.sort()
	var parts: Array[String] = []
	var start := nums[0]
	var prev := nums[0]
	for i in range(1, nums.size()):
		if nums[i] == prev + 1:
			prev = nums[i]
			continue
		parts.append("%d" % start if start == prev else "%d-%d" % [start, prev])
		start = nums[i]
		prev = nums[i]
	parts.append("%d" % start if start == prev else "%d-%d" % [start, prev])
	return ", ".join(parts)


func _on_failed(message: String) -> void:
	# No silent substitution: say what happened and let the student choose.
	_fail(message)


## Stops the pipeline and surfaces the reason. Nothing is saved or playable
## from here until the student retries or explicitly asks for the sample set.
func _fail(message: String) -> void:
	_failure = message
	_using_sample = false
	_payload = {}
	_server_done = false
	_finished = true
	_headline.text = "Generation failed"
	_stage_label.text = "Generation failed"
	_sub.text = message
	_sub.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_review.visible = false
	_retry.visible = true
	# the demo set is a developer aid: students only ever see Try again
	_sample.visible = Dev.overlay_on()
	_actions.modulate.a = 1.0
	_dbg("FAILED: " + message)


## Explicit, labelled demo fallback. Never automatic.
func _on_use_sample() -> void:
	_using_sample = true
	_failure = ""
	_payload = {
		"title": str(Nav.user.get("reviewer_file", "")).get_file().get_basename(),
		"pages": [],
		"questions": QuizData.sample(),
		"source": {"provider": "sample"},
	}
	_server_done = true
	_finished = false
	_review.visible = true
	_retry.visible = false
	_sample.visible = false
	_actions.modulate.a = 0.0
	_progress = maxf(_progress, HOLD_AT)
	_headline.text = "Sample questions"
	_stage_label.text = "Using sample questions"
	_sub.text = "Sample questions: these are NOT from your file."
	_sub.add_theme_color_override("font_color", Color(0.95, 0.75, 0.32))
	_dbg("PATH: SAMPLE SET (%d questions, demo only)" % QuizData.sample().size())


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
	_sample.visible = false
	_review.visible = true
	_actions.modulate.a = 0.0
	_headline.text = "Your Encounter is Ready"
	_dbg("retrying…")
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
