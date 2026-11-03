extends Control
## Review and edit what the AI produced, then save it as a playable set.
##
## Two tabs rather than a side-by-side split: the target is a small, old
## Android phone in landscape, and two columns at that size would leave the
## question text unreadably narrow.

const SOURCE_EMPTY_NOTE := "This file was read as images, so there is no text to show."

var _payload: Dictionary = {}
var _questions: Array = []
var _rows: Array = []
var _tab: String = "questions"
var _busy: bool = false

var _tab_buttons: Dictionary = {}
var _status: Label
var _content: VBoxContainer
var _scroll: ScrollContainer
var _regen: Button
var _save: Button
var _client: QuizClient


func setup(payload: Dictionary) -> Control:
	_payload = payload
	_questions = QuizData.from_server(payload)
	if _questions.is_empty():
		# This is a fallback: a failed/empty payload must not silently turn into
		# whatever quiz happened to be saved from an earlier run.
		var saved := QuizData.load_saved()
		_questions = saved.get("questions", [])
		print("[review] payload had 0 questions — REUSED saved quiz: %d questions, title '%s'" % [
			_questions.size(), str(saved.get("title", ""))])
	else:
		print("[review] payload: %d questions, %d pages" % [
			_questions.size(), payload.get("pages", []).size()])
	return self


# ------------------------------------------------------------------- building

func _ready() -> void:
	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_client = QuizClient.new()
	add_child(_client)
	_client.regenerated.connect(_on_regenerated)
	_client.failed.connect(_on_client_failed)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	column.add_child(_build_top_bar())
	column.add_child(_build_tabs())

	# --- content sheet
	var sheet := PanelContainer.new()
	var sb := UITheme.padded(UITheme.box(UITheme.CREAM, UITheme.WOOD_DARK.lightened(0.15), 2, 10), 8, 8)
	sb.shadow_color = Color(0.10, 0.08, 0.04, 0.25)
	sb.shadow_size = 7
	sheet.add_theme_stylebox_override("panel", sb)
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(sheet)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	_status = UITheme.small("", 11, UITheme.MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.custom_minimum_size = Vector2(0, 14)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel",
		UITheme.padded(UITheme.box(Color(0.988, 0.969, 0.914, 0.92),
			Color(0.42, 0.26, 0.03, 0.22), 1, 9), 10, 3))
	plate.add_child(_status)
	column.add_child(plate)

	_refresh()


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)

	var back := UITheme.button("←", "cream", 38)
	back.custom_minimum_size = Vector2(48, 38)
	back.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new()))
	bar.add_child(back)

	var title := UITheme.script(_title_text(), 24, UITheme.WOOD_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(title)

	_regen = UITheme.button("Regenerate", "cream", 38)
	_regen.custom_minimum_size = Vector2(150, 38)
	_regen.pressed.connect(_on_regenerate)
	bar.add_child(_regen)

	_save = UITheme.button("Save & Play", "navy", 38)
	_save.custom_minimum_size = Vector2(150, 38)
	_save.pressed.connect(_on_save)
	bar.add_child(_save)

	return bar


func _build_tabs() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	for key in ["source", "questions"]:
		var b := Button.new()
		b.text = "Source Text" if key == "source" else "Questions"
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(150, 34)
		b.add_theme_font_size_override("font_size", UITheme.crisp(14))
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("normal",
			UITheme.padded(UITheme.box(Color(0.99, 0.97, 0.93, 0.85), Color(0.72, 0.66, 0.55), 1, 8), 14, 6))
		b.add_theme_stylebox_override("hover",
			UITheme.padded(UITheme.box(UITheme.PAPER, UITheme.YELLOW_DEEP, 1, 8), 14, 6))
		b.add_theme_stylebox_override("pressed",
			UITheme.padded(UITheme.box(UITheme.NAVY, UITheme.NAVY_COLD, 1, 8), 14, 6))
		b.add_theme_color_override("font_color", UITheme.INK)
		b.add_theme_color_override("font_pressed_color", UITheme.PAPER)
		b.add_theme_color_override("font_hover_color", UITheme.INK)
		b.pressed.connect(_select_tab.bind(key))
		row.add_child(b)
		_tab_buttons[key] = b

	return row


# -------------------------------------------------------------------- content

func _title_text() -> String:
	var t := str(_payload.get("title", "")).strip_edges()
	return t if t != "" else "Review your questions"


func _select_tab(key: String) -> void:
	_tab = key
	_refresh()


func _refresh() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_rows.clear()

	for key in _tab_buttons:
		var b: Button = _tab_buttons[key]
		b.button_pressed = (key == _tab)

	if _tab == "source":
		_build_source()
	else:
		_build_questions()

	_update_status()


func _build_source() -> void:
	var pages: Array = _payload.get("pages", [])
	var wrote_any := false

	for page in pages:
		var text := str(page.get("text", "")).strip_edges()
		if text == "":
			continue
		wrote_any = true
		if pages.size() > 1:
			var head := UITheme.small("PDF page %d" % int(page.get("page", 0)), 11, UITheme.MUTED)
			_content.add_child(head)
		var body := UITheme.sans(text, 14, UITheme.INK)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(body)

	if not wrote_any:
		var empty := UITheme.sans(SOURCE_EMPTY_NOTE, 14, UITheme.MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(empty)


func _build_questions() -> void:
	var hint := UITheme.small(
		"Tap a letter to mark the correct answer. Edit any text you like.", 11, UITheme.MUTED)
	_content.add_child(hint)

	for i in _questions.size():
		_content.add_child(_question_card(i))

	var add := UITheme.button("+ Add a question", "cream", 36)
	add.custom_minimum_size = Vector2(0, 36)
	add.pressed.connect(_on_add)
	_content.add_child(add)


func _question_card(index: int) -> Control:
	var q: Dictionary = _questions[index]

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		UITheme.padded(UITheme.box(Color(1, 1, 1, 0.93), Color(0.80, 0.77, 0.70), 1, 8), 8, 6))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	box.add_child(head)

	var badge := UITheme.small("%d" % (index + 1), 11, UITheme.MUTED)
	badge.custom_minimum_size = Vector2(16, 0)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(badge)

	var q_edit := UITheme.field("Question text")
	q_edit.text = str(q.get("q", ""))
	q_edit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	q_edit.custom_minimum_size = Vector2(0, 36)
	q_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_edit.text_changed.connect(func(_t: String) -> void:
		_questions[index]["q"] = q_edit.text
		_update_status())
	head.add_child(q_edit)

	var del := UITheme.button("✕", "cream", 36)
	del.custom_minimum_size = Vector2(42, 36)
	del.pressed.connect(_on_delete.bind(index))
	head.add_child(del)

	var group := ButtonGroup.new()
	group.allow_unpress = true
	var choices: Array = q.get("choices", [])
	var toggles: Array[Button] = []
	var edits: Array[LineEdit] = []

	for j in 4:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)

		var mark := Button.new()
		mark.toggle_mode = true
		mark.button_group = group
		mark.text = char(65 + j)
		mark.custom_minimum_size = Vector2(32, 34)
		mark.add_theme_font_size_override("font_size", UITheme.crisp(12))
		mark.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_mark(mark)
		mark.set_pressed_no_signal(int(q.get("correct", -1)) == j)
		mark.toggled.connect(func(pressed: bool) -> void:
			_questions[index]["correct"] = j if pressed else -1
			_update_status())
		row.add_child(mark)
		toggles.append(mark)

		var edit := UITheme.field("Choice %s" % char(65 + j))
		edit.text = str(choices[j]) if j < choices.size() else ""
		edit.alignment = HORIZONTAL_ALIGNMENT_LEFT
		edit.custom_minimum_size = Vector2(0, 34)
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(func(t: String) -> void:
			var list: Array = _questions[index]["choices"]
			while list.size() < 4:
				list.append("")
			list[j] = t
			_update_status())
		row.add_child(edit)
		edits.append(edit)

	_rows.append({"q": q_edit, "choices": edits, "marks": toggles, "group": group})
	return card


func _style_mark(b: Button) -> void:
	b.add_theme_stylebox_override("normal",
		UITheme.padded(UITheme.box(Color(1, 1, 1, 0.95), Color(0.78, 0.75, 0.68), 1, 7), 4, 3))
	b.add_theme_stylebox_override("hover",
		UITheme.padded(UITheme.box(UITheme.PAPER, UITheme.YELLOW_DEEP, 1, 7), 4, 3))
	b.add_theme_stylebox_override("pressed",
		UITheme.padded(UITheme.box(UITheme.YELLOW, UITheme.YELLOW_DEEP, 2, 7), 4, 3))
	b.add_theme_color_override("font_color", UITheme.MUTED)
	b.add_theme_color_override("font_hover_color", UITheme.INK)
	b.add_theme_color_override("font_pressed_color", UITheme.INK)


# --------------------------------------------------------------------- editing

func _on_delete(index: int) -> void:
	_questions.remove_at(index)
	_refresh()
	_status.text = "Question removed."


func _on_add() -> void:
	_questions.append({"q": "", "choices": ["", "", "", ""], "correct": -1})
	_refresh()
	_scroll.set_deferred("scroll_vertical", 100000)
	_status.text = "New question added — fill it in and mark the answer."


func _update_status() -> void:
	if _busy:
		return
	var problems := QuizData.validate(_questions)
	if problems.is_empty():
		var used: Array = _payload.get("source", {}).get("used_pages", [])
		var span := "" if used.is_empty() else "  PDF pages %s." % _page_span(used)
		_status.text = "%d question%s, all valid.%s" % [
			_questions.size(), "" if _questions.size() == 1 else "s", span]
		_status.add_theme_color_override("font_color", Color(0.30, 0.52, 0.32))
	else:
		_status.text = "%s  (%d more)" % [problems[0], problems.size() - 1] if problems.size() > 1 else problems[0]
		_status.add_theme_color_override("font_color", UITheme.RED)


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


# ------------------------------------------------------------------ regenerating

func _source_is_empty() -> bool:
	for page in _payload.get("pages", []):
		if str(page.get("text", "")).strip_edges() != "":
			return false
	return true


func _on_regenerate() -> void:
	if _busy:
		return
	if _source_is_empty():
		_status.add_theme_color_override("font_color", UITheme.RED)
		_status.text = "There is no extracted text to regenerate from."
		return

	_busy = true
	_set_busy(true)
	_status.add_theme_color_override("font_color", UITheme.MUTED)
	_status.text = "Writing new questions…"
	var avoid: Array = _payload.get("source", {}).get("used_pages", [])
	_client.regenerate(_payload.get("pages", []), maxi(5, _questions.size()), avoid)


func _set_busy(busy: bool) -> void:
	_busy = busy
	_regen.disabled = busy
	_save.disabled = busy
	_regen.text = "Writing…" if busy else "Regenerate"


func _on_regenerated(data: Dictionary) -> void:
	_set_busy(false)
	var fresh := QuizData.from_server(data)
	if fresh.is_empty():
		_status.add_theme_color_override("font_color", UITheme.RED)
		_status.text = "The server returned no questions."
		return

	_questions = fresh
	if str(_payload.get("title", "")).strip_edges() == "":
		_payload["title"] = str(data.get("title", ""))
	if data.has("used_pages"):
		if typeof(_payload.get("source")) != TYPE_DICTIONARY:
			_payload["source"] = {}
		_payload["source"]["used_pages"] = data.get("used_pages", [])
	_tab = "questions"
	_refresh()

	var span := ""
	var used: Array = _payload.get("source", {}).get("used_pages", [])
	if not used.is_empty():
		span = " from PDF pages %s" % _page_span(used)
	_status.add_theme_color_override("font_color", Color(0.30, 0.52, 0.32))
	_status.text = "New set written%s: %d questions (%s)." % [
		span, fresh.size(), str(data.get("provider", "ai"))]


func _on_client_failed(message: String) -> void:
	_set_busy(false)
	_status.add_theme_color_override("font_color", UITheme.RED)
	_status.text = message


# ----------------------------------------------------------------------- saving

func _on_save() -> void:
	var problems := QuizData.validate(_questions)
	if not problems.is_empty():
		_status.add_theme_color_override("font_color", UITheme.RED)
		_status.text = "%s  Fix that, then save." % problems[0]
		_flash()
		return

	var title := _title_text()
	if not QuizData.save(title, _questions):
		_status.add_theme_color_override("font_color", UITheme.RED)
		_status.text = "Could not save the quiz."
		return

	print("[review] saved %d questions, title '%s' to %s" % [
		_questions.size(), title, ProjectSettings.globalize_path(QuizData.SAVE_PATH)])

	# Filed on the shelf as well, so My quizzes can list and replay it. The
	# upload is the identity: saving the same reviewer again updates that shelf
	# entry instead of stacking a duplicate beside it.
	var reviewer := str(Nav.user.get("reviewer_file", "")).strip_edges()
	var kept_id := QuizLibrary.add(title, _questions, "generated", reviewer)
	print("[review] filed in library as '%s'" % kept_id)

	Nav.encounter_ready = true
	Nav.encounter_title = title
	Nav.save_profile()
	Nav.show_screen(load("res://scenes/battle.tscn").instantiate())


func _flash() -> void:
	var tween := create_tween()
	tween.tween_property(_content, "modulate", Color(1.0, 0.75, 0.72), 0.12)
	tween.tween_property(_content, "modulate", Color.WHITE, 0.25)
