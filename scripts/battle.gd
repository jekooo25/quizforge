extends Control
## Quizmon — a quiz battle slice.
##
## Loop: a question appears with a shrinking timer. Answer correctly and your
## creature attacks, harder the faster you answered. Answer wrong (or run out of
## time) and the enemy gets a free hit. First one to 0 HP loses.

const ROUND_TIME := 12.0
const REVEAL_DELAY := 0.95

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
var streak: int = 0
var _state: String = "idle"
var _time_left: float = 0.0
var _pool: Array = []
var _correct_index: int = 0
var _round_number: int = 0

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
var answer_buttons: Array[Button] = []
var battlefield: Control
var overlay: Control


func _ready() -> void:
	# The reviewed set wins; the built-in questions keep the battle playable
	# on its own, before any reviewer has been generated.
	_questions = QuizData.load_saved().get("questions", [])
	if _questions.is_empty():
		_questions = QUESTIONS.duplicate()
	_build_ui()
	_start_battle()


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
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
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
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	# --- enemy status card, right aligned
	var enemy_row := HBoxContainer.new()
	column.add_child(enemy_row)
	var enemy_spacer := Control.new()
	enemy_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_row.add_child(enemy_spacer)
	var enemy_card := _make_panel(78.0)
	enemy_card.custom_minimum_size = Vector2(390.0, 78.0)
	enemy_row.add_child(enemy_card)
	var enemy_box := VBoxContainer.new()
	enemy_box.add_theme_constant_override("separation", 6)
	enemy_card.add_child(enemy_box)
	var enemy_head := HBoxContainer.new()
	enemy_box.add_child(enemy_head)
	var enemy_name := _label("Mudlet", 21, TEXT)
	enemy_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_head.add_child(enemy_name)
	enemy_hp_text = _label("60 / 60", 15, MUTED)
	enemy_head.add_child(enemy_hp_text)
	enemy_hp_bar = ProgressBar.new()
	_style_hp_bar(enemy_hp_bar, ACCENT)
	enemy_box.add_child(enemy_hp_bar)

	# --- battlefield
	battlefield = Control.new()
	battlefield.custom_minimum_size = Vector2(0.0, 176.0)
	battlefield.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battlefield.clip_contents = false
	column.add_child(battlefield)

	enemy_sprite = CreatureSprite.new()
	enemy_sprite.custom_minimum_size = Vector2(190.0, 190.0)
	enemy_sprite.anchor_left = 1.0
	enemy_sprite.anchor_right = 1.0
	enemy_sprite.anchor_top = 1.0
	enemy_sprite.anchor_bottom = 1.0
	enemy_sprite.offset_left = -240.0
	enemy_sprite.offset_right = -50.0
	enemy_sprite.offset_top = -190.0
	enemy_sprite.offset_bottom = 0.0
	battlefield.add_child(enemy_sprite)

	player_sprite = CreatureSprite.new()
	player_sprite.custom_minimum_size = Vector2(190.0, 190.0)
	player_sprite.anchor_left = 0.0
	player_sprite.anchor_right = 0.0
	player_sprite.anchor_top = 1.0
	player_sprite.anchor_bottom = 1.0
	player_sprite.offset_left = 50.0
	player_sprite.offset_right = 240.0
	player_sprite.offset_top = -190.0
	player_sprite.offset_bottom = 0.0
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

	question_label = _label("", 22, TEXT)
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(question_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	card_box.add_child(grid)

	for i in 4:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0.0, 44.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 17)
		btn.add_theme_stylebox_override("normal", _panel_style(Color(0.16, 0.15, 0.22), EDGE, 10))
		btn.add_theme_stylebox_override("hover", _panel_style(Color(0.21, 0.20, 0.29), ACCENT, 10))
		btn.add_theme_stylebox_override("pressed", _panel_style(Color(0.24, 0.23, 0.33), ACCENT, 10))
		btn.add_theme_stylebox_override("disabled", _panel_style(Color(0.12, 0.11, 0.16), EDGE, 10))
		btn.add_theme_color_override("font_color", TEXT)
		btn.add_theme_color_override("font_disabled_color", MUTED)
		btn.pressed.connect(_on_answer.bind(i))
		grid.add_child(btn)
		answer_buttons.append(btn)

	# --- player status card
	var player_card := _make_panel(78.0)
	column.add_child(player_card)
	var player_box := VBoxContainer.new()
	player_box.add_theme_constant_override("separation", 6)
	player_card.add_child(player_box)
	var player_head := HBoxContainer.new()
	player_box.add_child(player_head)
	var player_name := _label("Emberpup", 21, TEXT)
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
	player = Creature.new("Emberpup", 60, 9, Color(0.98, 0.55, 0.32), false)
	enemy = Creature.new("Mudlet", 60, 8, Color(0.42, 0.62, 0.96), true)
	streak = 0
	_round_number = 0
	_pool.clear()

	player_sprite.set_creature(player)
	player_sprite.facing = 1
	enemy_sprite.set_creature(enemy)
	enemy_sprite.facing = -1
	_refresh_bars(false)

	if overlay != null:
		overlay.queue_free()
		overlay = null

	feedback_label.text = "Answer correctly to attack. Be quick — speed is power."
	_begin_round()


func _begin_round() -> void:
	_round_number += 1
	var question: Dictionary = _draw_question()
	_correct_index = int(question["correct"])

	question_label.text = "%d.  %s" % [_round_number, question["q"]]
	var choices: Array = question["choices"]
	for i in answer_buttons.size():
		var btn := answer_buttons[i]
		btn.text = "%s.  %s" % [char(65 + i), choices[i]]
		btn.disabled = false
		btn.modulate = Color.WHITE

	_time_left = ROUND_TIME
	timer_bar.value = ROUND_TIME
	timer_bar.modulate = Color.WHITE
	_state = "answering"


func _draw_question() -> Dictionary:
	if _pool.is_empty():
		_pool = _questions.duplicate(true)
		_pool.shuffle()
	return _pool.pop_back()


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
		_resolve_hit(speed_ratio)
	else:
		if index >= 0:
			answer_buttons[index].add_theme_stylebox_override(
				"disabled", _panel_style(Color(0.30, 0.11, 0.11), DANGER, 10))
		_resolve_miss()

	await get_tree().create_timer(REVEAL_DELAY).timeout
	if _state != "resolving":
		return
	for btn in answer_buttons:
		btn.remove_theme_stylebox_override("disabled")
		btn.add_theme_stylebox_override("disabled", _panel_style(Color(0.12, 0.11, 0.16), EDGE, 10))
	_check_end()


func _resolve_hit(speed_ratio: float) -> void:
	streak += 1
	var crit := speed_ratio > 0.72
	var damage: float = float(player.atk) * (1.0 + speed_ratio) + float(streak - 1) * 1.5
	if crit:
		damage *= 1.4
	var dealt: int = enemy.take_damage(int(round(damage)))

	player_sprite.play_attack(1)
	await get_tree().create_timer(0.13).timeout
	enemy_sprite.play_hit()
	_float_number(battlefield, enemy_sprite.position + Vector2(110.0, 40.0), "-%d" % dealt,
		GOLD if crit else TEXT, 38 if crit else 32)
	_refresh_bars(true)

	var flavour := "Critical! " if crit else ""
	feedback_label.text = "%sCorrect — %s strikes for %d (%.0f%% speed)." % [
		flavour, player.display_name, dealt, speed_ratio * 100.0]
	_update_streak_label()


func _resolve_miss() -> void:
	streak = 0
	_update_streak_label()
	var dealt: int = player.take_damage(enemy.atk)

	enemy_sprite.play_attack(-1)
	await get_tree().create_timer(0.13).timeout
	player_sprite.play_hit()
	_float_number(battlefield, player_sprite.position + Vector2(110.0, 40.0), "-%d" % dealt,
		DANGER, 32)
	_refresh_bars(true)

	feedback_label.text = "Missed — %s hits back for %d. The answer was \"%s\"." % [
		enemy.display_name, dealt, answer_buttons[_correct_index].text.substr(4)]


func _check_end() -> void:
	if enemy.is_down():
		_end_battle(true)
	elif player.is_down():
		_end_battle(false)
	else:
		_state = "idle"
		feedback_label.text = feedback_label.text + "  Next question…"
		await get_tree().create_timer(0.55).timeout
		if _state == "idle":
			_begin_round()


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

	var title := _label("Victory" if won else "Defeated", 46, ACCENT if won else DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := _label("Cleared in %d question%s." % [_round_number, "" if _round_number == 1 else "s"],
		18, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var again := Button.new()
	again.text = "Battle again"
	again.custom_minimum_size = Vector2(0.0, 52.0)
	again.add_theme_font_size_override("font_size", 20)
	again.add_theme_stylebox_override("normal", _panel_style(Color(0.16, 0.15, 0.22), ACCENT, 12))
	again.add_theme_stylebox_override("hover", _panel_style(Color(0.22, 0.24, 0.28), ACCENT, 12))
	again.add_theme_stylebox_override("pressed", _panel_style(Color(0.26, 0.29, 0.33), ACCENT, 12))
	again.add_theme_color_override("font_color", TEXT)
	again.pressed.connect(_start_battle)
	box.add_child(again)


# ---------------------------------------------------------------- presentation

func _refresh_bars(animated: bool) -> void:
	enemy_hp_text.text = "%d / %d" % [enemy.hp, enemy.max_hp]
	player_hp_text.text = "%d / %d" % [player.hp, player.max_hp]
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
