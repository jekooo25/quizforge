extends Control
## Quizmon — a quiz battle slice.
##
## Demo loop: answer each saved question once, review the answer, then choose
## Next. Correct answers damage the enemy; wrong or timed-out answers damage
## the player. Knockout or question exhaustion ends the battle.

## Long enough to read a full question and its four choices at demo pace.
const ROUND_TIME := 45.0
const TARGET_CORRECT_RATIO := 0.70
const DEMO_PLAYER_HP := 3
const DEMO_ENEMY_DAMAGE := 1
const DEMO_PLAYER_DAMAGE := 1

const Dev := preload("res://scripts/ui/dev.gd")

const BG := Color(0.078, 0.075, 0.106)
const PANEL := Color(0.133, 0.122, 0.180)
const EDGE := Color(0.208, 0.188, 0.290)
const ACCENT := Color(0.490, 0.839, 0.627)
const DANGER := Color(0.910, 0.412, 0.373)
const GOLD := Color(0.973, 0.784, 0.353)
const TEXT := Color(0.937, 0.918, 0.969)
const MUTED := Color(0.604, 0.576, 0.690)

const QUESTIONS := [
	{"q": "Which planet is known as the Red Planet?", "choices": ["Venus", "Mars", "Jupiter", "Mercury"], "correct": 1},
	{"q": "What is the only mammal capable of true flight?", "choices": ["Flying squirrel", "Bat", "Sugar glider", "Colugo"], "correct": 1},
	{"q": "How many degrees are in a right angle?", "choices": ["45", "90", "180", "360"], "correct": 1},
	{"q": "Which gas do plants mainly absorb for photosynthesis?", "choices": ["Oxygen", "Nitrogen", "Carbon dioxide", "Hydrogen"], "correct": 2},
	{"q": "Who painted the Mona Lisa?", "choices": ["Michelangelo", "Raphael", "Donatello", "Leonardo da Vinci"], "correct": 3},
	{"q": "What is 12 x 8?", "choices": ["86", "96", "104", "112"], "correct": 1},
	{"q": "Which ocean is the largest by area?", "choices": ["Atlantic", "Indian", "Pacific", "Arctic"], "correct": 2},
	{"q": "What does 'H2O' represent?", "choices": ["Salt", "Water", "Hydrogen peroxide", "Oxygen"], "correct": 1},
	{"q": "Which is the smallest prime number?", "choices": ["0", "1", "2", "3"], "correct": 2},
	{"q": "In which country did the Renaissance begin?", "choices": ["France", "Greece", "Italy", "Spain"], "correct": 2},
]

var player: Creature
var enemy: Creature
var _questions: Array = []
var _source: String = ""
var streak: int = 0
var _state: String = "idle"
var _time_left: float = 0.0
var _correct_index: int = 0
var _round_number: int = 0
var _answered_correctly: int = 0
var _current_question: Dictionary = {}

var enemy_sprite: CreatureSprite
var player_sprite: CreatureSprite
var enemy_hp_bar: ProgressBar
var enemy_hp_text: Label
var player_hp_bar: ProgressBar
var player_hp_text: Label
var timer_bar: ProgressBar
var streak_label: Label
var question_label: Label
var feedback_label: Label
var explanation_label: Label
var explanation_scroll: ScrollContainer
var next_button: Button
var answer_buttons: Array[Button] = []
var battlefield: Control
var overlay: Control


const UNAVAILABLE := "We couldn't open this quiz. Please choose it again from your saved quizzes or make a new one."

## Set when the battle cannot start because there is no playable quiz. Tests and
## the debug label read these instead of digging through the node tree.
var unavailable := false
var unavailable_message := ""


func _ready() -> void:
	var saved := QuizData.load_saved()
	var status := str(saved.get("status", SaveManager.STATUS_OK))
	var questions: Variant = saved.get("questions", [])
	if typeof(questions) == TYPE_ARRAY:
		_questions.assign(questions)

	if status == SaveManager.STATUS_CORRUPT or _questions.is_empty():
		# A quiz that cannot be opened is not a reason to invent one. This used
		# to fall through to the built-in sample, so a student whose file was
		# damaged answered questions they never chose. Only a debug run may
		# substitute the demo set now.
		if not Dev.sample_allowed():
			_show_unavailable(status)
			return
		_questions = QUESTIONS.duplicate()
		_source = "BUILT-IN QUESTIONS (debug flag; no playable quiz)"
	else:
		_source = "saved quiz, %d questions, title '%s', saved %s" % [
			_questions.size(),
			str(saved.get("title", "")),
			Time.get_datetime_string_from_unix_time(
				FileAccess.get_modified_time(QuizData.SAVE_PATH))]

	print("[battle] quiz source: ", _source)
	print("[battle] file: ", ProjectSettings.globalize_path(QuizData.SAVE_PATH))
	print("[battle] first question: ", str(_questions[0].get("q", "")) if not _questions.is_empty() else "(none)")
	_build_ui()
	if Dev.overlay_on():
		_add_debug_label()
	_start_battle()


## The saved quiz is missing or damaged. Say so plainly and offer the way out.
## No battle is started, so there is nothing to win and no score to show.
func _show_unavailable(status: String) -> void:
	unavailable = true
	unavailable_message = UNAVAILABLE
	_source = "unavailable (%s)" % status
	print("[battle] quiz unavailable: ", status)
	print("[battle] file: ", ProjectSettings.globalize_path(QuizData.SAVE_PATH))

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := _make_panel(0.0)
	card.custom_minimum_size = Vector2(560.0, 0.0)
	center.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	card.add_child(column)

	var title := _display_label("No quiz to play", 26, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var message := _label(UNAVAILABLE, 17, MUTED)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(message)

	var back := UITheme.button("Back to menu", "navy", 46)
	back.custom_minimum_size = Vector2(240.0, 46.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new()))
	column.add_child(back)


## TEMPORARY: says which set the battle is actually playing.
func _add_debug_label() -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 10.0
	label.offset_right = 760.0
	label.offset_top = -46.0
	label.offset_bottom = -4.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", UITheme.crisp(10))
	label.add_theme_color_override("font_color", Color(0.62, 1.0, 0.62))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	var first := str(_questions[0].get("q", "")) if not _questions.is_empty() else "(none)"
	label.text = "[battle] " + _source + "\nfirst: " + first
	add_child(label)


# ---------------------------------------------------------------- UI building

func _panel_style(bg: Color, edge: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UITheme.crisp(font_size))
	l.add_theme_color_override("font_color", color)
	return l


## Banners and names are display text: Monocraft, like the rest of the chrome.
func _display_label(text: String, font_size: int, color: Color) -> Label:
	var l := _label(text, font_size, color)
	l.add_theme_font_override("font", UITheme.font_pixel)
	return l


func _make_panel(min_height: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, EDGE, 16))
	panel.custom_minimum_size = Vector2(0.0, min_height)
	return panel


func _style_hp_bar(bar: ProgressBar, fill_color: Color) -> void:
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.06, 0.06, 0.09)
	back.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 14.0)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	# --- enemy status card, right aligned
	var enemy_row := HBoxContainer.new()
	column.add_child(enemy_row)
	var enemy_spacer := Control.new()
	enemy_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_row.add_child(enemy_spacer)
	var enemy_card := _make_panel(60.0)
	enemy_card.custom_minimum_size = Vector2(390.0, 60.0)
	enemy_row.add_child(enemy_card)
	var enemy_box := VBoxContainer.new()
	enemy_box.add_theme_constant_override("separation", 6)
	enemy_card.add_child(enemy_box)
	var enemy_head := HBoxContainer.new()
	enemy_box.add_child(enemy_head)
	var enemy_name := _display_label("Mudlet (demo)", 24, TEXT)
	enemy_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_head.add_child(enemy_name)
	enemy_hp_text = _label("60 / 60", 15, MUTED)
	enemy_head.add_child(enemy_hp_text)
	enemy_hp_bar = ProgressBar.new()
	_style_hp_bar(enemy_hp_bar, ACCENT)
	enemy_box.add_child(enemy_hp_bar)

	# --- battlefield
	battlefield = Control.new()
	battlefield.custom_minimum_size = Vector2(0.0, 120.0)
	battlefield.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battlefield.clip_contents = false
	column.add_child(battlefield)

	enemy_sprite = CreatureSprite.new()
	enemy_sprite.custom_minimum_size = Vector2(120.0, 120.0)
	enemy_sprite.anchor_left = 1.0
	enemy_sprite.anchor_right = 1.0
	enemy_sprite.anchor_top = 0.5
	enemy_sprite.anchor_bottom = 0.5
	enemy_sprite.offset_left = -170.0
	enemy_sprite.offset_right = -50.0
	enemy_sprite.offset_top = -60.0
	enemy_sprite.offset_bottom = 60.0
	battlefield.add_child(enemy_sprite)

	player_sprite = CreatureSprite.new()
	player_sprite.custom_minimum_size = Vector2(120.0, 120.0)
	player_sprite.anchor_left = 0.0
	player_sprite.anchor_right = 0.0
	player_sprite.anchor_top = 0.5
	player_sprite.anchor_bottom = 0.5
	player_sprite.offset_left = 50.0
	player_sprite.offset_right = 170.0
	player_sprite.offset_top = -60.0
	player_sprite.offset_bottom = 60.0
	battlefield.add_child(player_sprite)

	# --- feedback line
	feedback_label = _label("", 17, MUTED)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(feedback_label)

	# --- question card
	var card := _make_panel(158.0)
	column.add_child(card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 10)
	card.add_child(card_box)

	question_label = _label("", 28, TEXT)
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(question_label)
	explanation_scroll = ScrollContainer.new()
	explanation_scroll.custom_minimum_size = Vector2(0.0, 76.0)
	explanation_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	explanation_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	explanation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	explanation_scroll.visible = false
	card_box.add_child(explanation_scroll)
	explanation_label = _label("", 16, MUTED)
	explanation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation_scroll.add_child(explanation_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	card_box.add_child(grid)

	for i in 4:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0.0, 52.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", UITheme.crisp(28))
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_stylebox_override("normal", _panel_style(Color(0.16, 0.15, 0.22), EDGE, 10))
		btn.add_theme_stylebox_override("hover", _panel_style(Color(0.21, 0.20, 0.29), ACCENT, 10))
		btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.24, 0.23, 0.33), ACCENT, 10))
		btn.add_theme_stylebox_override("disabled", _panel_style(Color(0.12, 0.11, 0.16), EDGE, 10))
		btn.add_theme_color_override("font_color", TEXT)
		btn.add_theme_color_override("font_disabled_color", MUTED)
		btn.pressed.connect(_on_answer.bind(i))
		grid.add_child(btn)
		answer_buttons.append(btn)

	next_button = UITheme.button("Next", "navy", 44)
	next_button.custom_minimum_size = Vector2(180.0, 44.0)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_button.visible = false
	next_button.pressed.connect(_on_next)
	column.add_child(next_button)

	# --- player status card
	var player_card := _make_panel(60.0)
	column.add_child(player_card)
	var player_box := VBoxContainer.new()
	player_box.add_theme_constant_override("separation", 6)
	player_card.add_child(player_box)
	var player_head := HBoxContainer.new()
	player_box.add_child(player_head)
	var player_name := _display_label("Emberpup (demo)", 24, TEXT)
	player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_head.add_child(player_name)
	streak_label = _label("", 15, GOLD)
	player_head.add_child(streak_label)
	player_hp_text = _label("60 / 60", 15, MUTED)
	player_head.add_child(player_hp_text)
	player_hp_bar = ProgressBar.new()
	_style_hp_bar(player_hp_bar, ACCENT)
	player_box.add_child(player_hp_bar)

	timer_bar = ProgressBar.new()
	_style_hp_bar(timer_bar, GOLD)
	timer_bar.custom_minimum_size = Vector2(0.0, 8.0)
	timer_bar.max_value = ROUND_TIME
	timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var timer_row := HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", 12)
	column.add_child(timer_row)
	var timer_caption := _label("TIME", 12, MUTED)
	timer_caption.custom_minimum_size = Vector2(42.0, 0.0)
	timer_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_row.add_child(timer_caption)
	timer_row.add_child(timer_bar)


# ---------------------------------------------------------------- game state

func _start_battle() -> void:
	# Creature names and HP are placeholders for the demo battle, not selected
	# player/enemy data. One enemy HP represents one correct answer needed.
	var enemy_hp := maxi(1, int(ceil(float(_questions.size()) * TARGET_CORRECT_RATIO)))
	player = Creature.new("Emberpup (demo)", DEMO_PLAYER_HP, DEMO_PLAYER_DAMAGE, Color(0.98, 0.55, 0.32), false)
	enemy = Creature.new("Mudlet (demo)", enemy_hp, DEMO_ENEMY_DAMAGE, Color(0.42, 0.62, 0.96), true)
	streak = 0
	_round_number = 0
	_answered_correctly = 0

	player_sprite.set_creature(player)
	player_sprite.facing = 1
	enemy_sprite.set_creature(enemy)
	enemy_sprite.facing = -1
	_refresh_bars(false)

	if overlay != null:
		overlay.queue_free()
		overlay = null

	feedback_label.text = "Demo battle — answer correctly to damage the demo enemy."
	next_button.visible = false
	_begin_round()


func _begin_round() -> void:
	if _round_number >= _questions.size():
		_end_battle(enemy.is_down())
		return
	_round_number += 1
	_current_question = _questions[_round_number - 1]
	_correct_index = int(_current_question["correct"])

	question_label.text = "%d / %d.  %s" % [_round_number, _questions.size(), _current_question["q"]]
	explanation_label.text = ""
	explanation_scroll.visible = false
	battlefield.visible = true
	var choices: Array = _current_question["choices"]
	for i in answer_buttons.size():
		var btn := answer_buttons[i]
		btn.text = "%s.  %s" % [char(65 + i), choices[i]]
		btn.disabled = false
		btn.modulate = Color.WHITE

	_time_left = ROUND_TIME
	timer_bar.value = ROUND_TIME
	timer_bar.modulate = Color.WHITE
	_state = "answering"
	next_button.visible = false


func _process(delta: float) -> void:
	if _state != "answering":
		return
	_time_left -= delta
	timer_bar.value = maxf(_time_left, 0.0)
	if _time_left <= 3.0:
		timer_bar.modulate = Color(1.0, 0.55, 0.5)
	if _time_left <= 0.0:
		_on_answer(-1)


func _on_answer(index: int) -> void:
	if _state != "answering":
		return
	_state = "resolving"
	for btn in answer_buttons:
		btn.disabled = true

	var speed_ratio := clampf(_time_left / ROUND_TIME, 0.0, 1.0)
	var answered_right := index == _correct_index

	answer_buttons[_correct_index].add_theme_stylebox_override(
		"disabled", _panel_style(Color(0.10, 0.26, 0.17), ACCENT, 10))

	if answered_right:
		_answered_correctly += 1
		await _resolve_hit(speed_ratio)
	else:
		if index >= 0:
			answer_buttons[index].add_theme_stylebox_override(
				"disabled", _panel_style(Color(0.30, 0.11, 0.11), DANGER, 10))
		await _resolve_miss()

	var correct_text := str(answer_buttons[_correct_index].text)
	feedback_label.text = "Correct answer: %s" % correct_text
	var details: Array[String] = []
	var explanation := str(_current_question.get("explanation", "")).strip_edges()
	var page := int(_current_question.get("page", 0))
	var quote := str(_current_question.get("source_quote", "")).strip_edges()
	if explanation != "":
		details.append(explanation)
	if page > 0:
		details.append("Source: page %d" % page)
	if quote != "":
		details.append("“%s”" % quote)
	explanation_label.text = "\n".join(details)
	explanation_scroll.scroll_vertical = 0
	explanation_scroll.visible = not details.is_empty()
	battlefield.visible = details.is_empty()
	_state = "revealed"
	next_button.text = "Finish" if _round_number >= _questions.size() or enemy.is_down() or player.is_down() else "Next"
	next_button.visible = true


func _on_next() -> void:
	if _state != "revealed":
		return
	for btn in answer_buttons:
		btn.remove_theme_stylebox_override("disabled")
		btn.add_theme_stylebox_override("disabled", _panel_style(Color(0.12, 0.11, 0.16), EDGE, 10))
	if enemy.is_down():
		_end_battle(true)
	elif player.is_down():
		_end_battle(false)
	elif _round_number >= _questions.size():
		_end_battle(false)
	else:
		_begin_round()


func _resolve_hit(speed_ratio: float) -> void:
	streak += 1
	var crit := speed_ratio > 0.72
	var dealt: int = enemy.take_damage(1)

	player_sprite.play_attack(1)
	await get_tree().create_timer(0.13).timeout
	enemy_sprite.play_hit()
	_float_number(battlefield, enemy_sprite.position + Vector2(110.0, 40.0), "-%d" % dealt,
		GOLD if crit else TEXT, 38 if crit else 32)
	_refresh_bars(true)

	feedback_label.text = "Correct — %s deals %d demo damage." % [player.display_name, dealt]
	_update_streak_label()


func _resolve_miss() -> void:
	streak = 0
	_update_streak_label()
	var dealt: int = player.take_damage(DEMO_ENEMY_DAMAGE)

	enemy_sprite.play_attack(-1)
	await get_tree().create_timer(0.13).timeout
	player_sprite.play_hit()
	_float_number(battlefield, player_sprite.position + Vector2(110.0, 40.0), "-%d" % dealt,
		DANGER, 32)
	_refresh_bars(true)

	feedback_label.text = "Incorrect — %s deals %d demo damage." % [enemy.display_name, dealt]


func _end_battle(won: bool) -> void:
	_state = "over"
	if won:
		enemy_sprite.play_faint()
	else:
		player_sprite.play_faint()

	await get_tree().create_timer(0.6).timeout

	overlay = ColorRect.new()
	overlay.color = Color(0.04, 0.04, 0.06, 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(420.0, 0.0)
	center.add_child(box)

	var title := _display_label("Victory" if won else "Defeated", 48, ACCENT if won else DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := _label("Demo result — %d correct in %d questions." % [_answered_correctly, _round_number],
		18, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var again := Button.new()
	again.text = "Battle again"
	again.custom_minimum_size = Vector2(0.0, 52.0)
	again.add_theme_font_size_override("font_size", UITheme.crisp(20))
	again.add_theme_stylebox_override("normal", _panel_style(Color(0.16, 0.15, 0.22), ACCENT, 12))
	again.add_theme_stylebox_override("hover", _panel_style(Color(0.22, 0.24, 0.28), ACCENT, 12))
	again.add_theme_stylebox_override("pressed", _panel_style(Color(0.26, 0.29, 0.33), ACCENT, 12))
	again.add_theme_color_override("font_color", TEXT)
	again.pressed.connect(_start_battle)
	box.add_child(again)


# ---------------------------------------------------------------- presentation

func _refresh_bars(animated: bool) -> void:
	enemy_hp_text.text = "DEMO HP %d / %d" % [enemy.hp, enemy.max_hp]
	player_hp_text.text = "DEMO HP %d / %d" % [player.hp, player.max_hp]
	enemy_hp_bar.max_value = enemy.max_hp
	player_hp_bar.max_value = player.max_hp

	if animated:
		var t1 := create_tween()
		t1.tween_property(enemy_hp_bar, "value", enemy.hp, 0.35)
		var t2 := create_tween()
		t2.tween_property(player_hp_bar, "value", player.hp, 0.35)
	else:
		enemy_hp_bar.value = enemy.hp
		player_hp_bar.value = player.hp


func _update_streak_label() -> void:
	streak_label.text = ("Streak x%d" % streak) if streak >= 2 else ""


func _float_number(parent: Control, at: Vector2, text: String, color: Color, font_size: int) -> void:
	var l := _label(text, font_size, color)
	l.position = at
	l.size = Vector2(160.0, 50.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(l, "position:y", at.y - 60.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(l.queue_free)
