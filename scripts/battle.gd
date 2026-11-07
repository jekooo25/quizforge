extends Control
## Quizmon — a quiz battle slice.
##
## Choose Attack or Recover, answer, and watch the turn resolve. Correct answers
## advance automatically. Mistakes pause for reading and return as recall checks.
## Only first attempts affect battle score, task accuracy, and Stars.

signal answer_submitted(is_correct: bool)
signal battle_completed(score: int)

## Long enough to read a full question and its four choices at demo pace.
@export var timed_battle := false
@export_range(0, 20) var encounter_size := 20
@export var auto_advance_delay := 1.0

const BattleAudio := preload("res://scripts/ui/battle_audio.gd")

const ROUND_TIME := 45.0
const SHIELD_COMBO := 3
const DEMO_PLAYER_HP := 100
const DEMO_ENEMY_HP := 100
const STANDARD_PLAYER_DAMAGE := 45
const SCORE_PER_CORRECT_ANSWER := 75
const STARS_PER_CORRECT_ANSWER := 1
const STARS_FOR_WIN := 2

const Dev := preload("res://scripts/ui/dev.gd")

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
var _all_questions: Array = []
var _missed_questions: Array = []
var _source: String = ""
var _quiz_library_id := ""
var streak: int = 0
var _best_streak := 0
var _shield_ready := false
var _practice_mode := false
var _turn_effect := ""
var _state: String = "idle"
var _turns: Array = []
var _turn_index := -1
var _is_recall := false
var _combat_finished := false
var _selected_action := "attack"
var _auto_left := 0.0
var _recall_attempted := 0
var _recall_correct := 0
var _first_misses := 0
var _run_id := 0
var _suspended := false
var _resume_guard := false
var _audio: Node
var _paused_by_menu := false
var _time_left: float = 0.0
var _correct_index: int = 0
var _round_number: int = 0
var _answered_correctly: int = 0
var _current_score: int = 0
var _battle_question_count: int = 0
var _current_question: Dictionary = {}
var _battle_sequence := 0
var _battle_stars := 0

@onready var pause_menu: Control = %PauseMenu
@onready var attack_button: Button = %AttackButton
@onready var recover_button: Button = %RecoverButton
@onready var action_row: HBoxContainer = %ActionRow
@onready var enemy_sprite: CreatureSprite = %EnemySprite
@onready var player_sprite: CreatureSprite = %PlayerSprite
@onready var enemy_hp_bar: ProgressBar = %EnemyHPBar
@onready var enemy_hp_text: Label = %EnemyHPText
@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_hp_text: Label = %PlayerHPText
@onready var timer_toggle: Button = %TimerToggle
@onready var timer_bar: ProgressBar = %TimerBar
@onready var streak_label: Label = %StreakLabel
@onready var score_label: Label = %ScoreLabel
@onready var question_label: Label = %QuestionLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var explanation_label: Label = %ExplanationLabel
@onready var explanation_scroll: ScrollContainer = %ExplanationScroll
@onready var next_button: Button = %NextButton
@onready var battlefield: Control = %Battlefield
@onready var safe_area: MarginContainer = %SafeArea
@onready var answer_buttons: Array[Button] = [
	%AnswerA as Button, %AnswerB as Button, %AnswerC as Button, %AnswerD as Button]
var result_layer: Control
var _battle_reward_id := ""


const UNAVAILABLE := "We couldn't open this quiz. Please choose it again from your saved quizzes or make a new one."

## Set when the battle cannot start because there is no playable quiz. Tests and
## the debug label read these instead of digging through the node tree.
var unavailable := false
var unavailable_message := ""


func _ready() -> void:
	var saved := QuizData.load_saved()
	var status := str(saved.get("status", SaveManager.STATUS_OK))
	_quiz_library_id = str(saved.get("library_id", ""))
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
	_all_questions = _questions.duplicate(true)
	answer_submitted.connect(TaskManager.record_answer)
	battle_completed.connect(TaskManager.record_battle)
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
	safe_area.visible = false
	answer_buttons.clear()
	var unavailable_scene := preload("res://scenes/BattleUnavailable.tscn") as PackedScene
	var unavailable_view := unavailable_scene.instantiate() as Control
	add_child(unavailable_view)
	unavailable_view.connect("return_to_menu", _on_return_to_menu)


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
	l.add_theme_font_override("font", UITheme.font_body)
	l.add_theme_font_size_override("font_size", UITheme.crisp(font_size))
	l.add_theme_color_override("font_color", color)
	return l


## Banners and names use the shared UI font through the battle scene theme.
func _build_ui() -> void:
	resized.connect(_apply_battle_safe_area)
	_apply_battle_safe_area.call_deferred()
	%PauseButton.pressed.connect(_pause_battle)
	pause_menu.resume_requested.connect(_resume_battle)
	pause_menu.get_node("%ResumeButton").pressed.connect(_resume_battle)
	pause_menu.get_node("%ReturnButton").pressed.connect(func() -> void: pause_menu.get_node("%LeaveConfirmation").popup_centered())
	pause_menu.get_node("%LeaveConfirmation").confirmed.connect(_leave_paused_battle)
	var slider: HSlider = pause_menu.get_node("%SoundSlider")
	slider.value = AudioMixer.volume_of(Nav.user,"volume_sfx")
	slider.value_changed.connect(func(value: float) -> void:
		Nav.user["volume_sfx"] = int(value)
		AudioMixer.set_volume_percent(AudioMixer.SFX,int(value))
		Nav.save_profile())
	_audio = BattleAudio.new()
	add_child(_audio)
	attack_button.pressed.connect(_select_action.bind("attack"))
	recover_button.pressed.connect(_select_action.bind("recover"))
	timer_bar.max_value = ROUND_TIME
	timer_toggle.pressed.connect(_toggle_timer)
	for i in answer_buttons.size():
		var btn := answer_buttons[i]
		btn.pressed.connect(_on_answer.bind(i))
	next_button.pressed.connect(_on_next)
# ---------------------------------------------------------------- game state

func _start_battle() -> void:
	_run_id += 1
	_auto_left = 0.0
	_combat_finished = false
	_recall_attempted = 0
	_recall_correct = 0
	_first_misses = 0
	_turn_index = -1
	_turns.clear()
	if not _practice_mode and encounter_size > 0 and _questions.size() > encounter_size:
		_questions = _questions.duplicate(true)
		_questions.shuffle()
		_questions = _questions.slice(0, encounter_size)
	for i in _questions.size():
		var question: Dictionary = _questions[i].duplicate(true)
		question["_learning_id"] = i
		question["_source_index"] = _all_questions.find(_questions[i])
		_turns.append({"question": question, "recall": false})
	var enemy_hp: int = _questions.size() if _practice_mode else DEMO_ENEMY_HP
	var damage_per_answer: int = maxi(1, int(100.0 / float(maxi(1, _questions.size()))))
	player = Creature.new("Emberpup", DEMO_PLAYER_HP, damage_per_answer,
		ShopManager.equipped_body_color(), ShopManager.has_equipped_horns())
	enemy = Creature.new("Mudlet", enemy_hp, STANDARD_PLAYER_DAMAGE, Color(0.42, 0.62, 0.96), true)
	streak = 0
	_best_streak = 0
	_shield_ready = false
	_update_streak_label()
	_round_number = 0
	_answered_correctly = 0
	_current_score = 0
	_battle_question_count = _questions.size()
	_missed_questions.clear()
	_battle_sequence += 1
	_battle_reward_id = "%d_%d_%d" % [get_instance_id(), int(Time.get_unix_time_from_system()), _battle_sequence]

	player_sprite.set_creature(player)
	player_sprite.facing = 1
	enemy_sprite.set_creature(enemy)
	enemy_sprite.facing = -1
	_refresh_bars(false)
	score_label.text = "Score 0"

	safe_area.visible = true
	if is_instance_valid(result_layer):
		result_layer.queue_free()
		result_layer = null

	feedback_label.modulate = Color.WHITE
	feedback_label.text = "PRACTICE — recall the answer. No timer or HP loss." if _practice_mode else "Ember Spark: answer correctly. 3 in a row earns a shield!"
	next_button.visible = false
	_begin_round()


func _begin_round() -> void:
	_turn_index += 1
	if _turn_index >= _turns.size():
		_end_battle(_missed_questions.is_empty() if _practice_mode else enemy.is_down())
		return
	for effect in battlefield.get_children():
		if effect is Label:
			effect.queue_free()
	var turn: Dictionary = _turns[_turn_index]
	_is_recall = _practice_mode or bool(turn["recall"])
	_current_question = turn["question"]
	if not bool(turn["recall"]):
		_round_number += 1
	_correct_index = int(_current_question["correct"])
	_selected_action = "attack"
	feedback_label.modulate = Color.WHITE
	feedback_label.text = "RECALL CHECK — no HP loss or timer. Remember the answer?" if _is_recall else "Choose Attack or Recover, then answer. 3 correct earns a shield!"
	var prefix := "Recall" if _is_recall else "%d / %d" % [_round_number, _battle_question_count]
	question_label.text = "%s. %s" % [prefix, _current_question["q"]]
	question_label.modulate.a = 0.0
	create_tween().tween_property(question_label, "modulate:a", 1.0, 0.18)
	question_label.visible = true
	%QuestionScroll.visible = true
	%QuestionScroll.scroll_vertical = 0
	%AnswerDock.scroll_vertical = 0
	%QuestionProgress.text = "Recall" if _is_recall else "%d / %d" % [_round_number,_battle_question_count]
	%AutoAdvanceBar.visible = false
	%AnswerDock.visible = true
	%ActionDock.visible = not _is_recall
	%PlayerSprite.visible = true
	%EnemySprite.visible = true
	%PlayerPlatform.visible = true
	%EnemyPlatform.visible = true
	%QuestionPanel.anchor_left = 0.20
	%QuestionPanel.anchor_right = 0.80
	explanation_label.text = ""
	explanation_scroll.visible = false
	battlefield.visible = true
	action_row.visible = not _is_recall
	%ChoiceGrid.visible = true
	%QuestionPanel.size_flags_vertical = Control.SIZE_FILL
	var choices: Array = _current_question["choices"]
	for i in answer_buttons.size():
		var button := answer_buttons[i]
		button.text = "%s. %s" % [char(65 + i), choices[i]]
		button.disabled = false
		button.modulate = Color.WHITE
		button.remove_theme_stylebox_override("disabled")
	_time_left = ROUND_TIME
	_state = "answering"
	_refresh_timer_mode()
	_refresh_actions()
	timer_bar.value = ROUND_TIME
	timer_bar.modulate = Color.WHITE
	next_button.visible = false
	answer_buttons[0].grab_focus()


func _select_action(action: String) -> void:
	if _state != "answering" or _is_recall:
		return
	if action == "recover" and player.hp >= player.max_hp:
		return
	_selected_action = action
	_refresh_actions()


func _refresh_actions() -> void:
	attack_button.disabled = _state != "answering"
	recover_button.disabled = _state != "answering" or player.hp >= player.max_hp
	%ActionHint.text = "Correct answer restores 1 HP" if _selected_action == "recover" else "Correct answer deals 1 damage"
	attack_button.set_pressed_no_signal(_selected_action == "attack")
	recover_button.set_pressed_no_signal(_selected_action == "recover")
	recover_button.text = "Recover: HP full" if player.hp >= player.max_hp else "Recover: +1 HP"


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_pause_battle()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _state == "answering":
		var index := [KEY_1, KEY_2, KEY_3, KEY_4].find(event.keycode)
		if index >= 0:
			get_viewport().set_input_as_handled()
			_on_answer(index)


func _toggle_timer() -> void:
	if _is_recall or _state != "answering":
		return
	timed_battle = not timed_battle
	_time_left = ROUND_TIME
	_refresh_timer_mode()


func _refresh_timer_mode() -> void:
	timer_toggle.text = "Untimed recall" if _is_recall else ("Timer: ON" if timed_battle else "Timer: OFF")
	timer_toggle.disabled = _is_recall
	timer_bar.visible = timed_battle and not _is_recall
	timer_bar.get_parent().visible = timer_bar.visible


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _paused_by_menu: _resume_battle()
		else: _pause_battle()
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_suspended = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_suspended = false
		_resume_guard = true


func _process(delta: float) -> void:
	if _suspended or _paused_by_menu:
		return
	if _resume_guard:
		_resume_guard = false
		return
	if _state == "auto_advancing":
		_auto_left -= delta
		%AutoAdvanceBar.value = _auto_left
		if _auto_left <= 0.0:
			_advance_turn()
		return
	if _state != "answering" or _is_recall or not timed_battle:
		return
	_time_left -= delta
	timer_bar.value = maxf(_time_left, 0.0)
	if _time_left <= 3.0:
		timer_bar.modulate = Color(1.0, 0.55, 0.5)
	if _time_left <= 0.0:
		_on_answer(-1)


func _on_answer(index: int) -> void:
	if _state != "answering" or index < -1 or index >= answer_buttons.size():
		return
	_state = "resolving"
	var run := _run_id
	timer_toggle.disabled = true
	_refresh_actions()
	for button in answer_buttons:
		button.disabled = true
	_turn_effect = ""
	var correct := index == _correct_index
	answer_buttons[_correct_index].text = "Correct · " + str(_current_question["choices"][_correct_index])
	if not correct and index >= 0:
		answer_buttons[index].text = "Incorrect · " + str(_current_question["choices"][index])
	var verdict := "CORRECT!" if correct else ("TIME UP!" if index == -1 else "INCORRECT")
	feedback_label.text = verdict + (" Recover!" if correct and _selected_action == "recover" and not _is_recall else (" Ember Spark!" if correct else " Read the explanation."))
	feedback_label.modulate = ACCENT if correct else DANGER
	if not _is_recall:
		answer_submitted.emit(correct)
	elif not _practice_mode:
		_recall_attempted += 1
	answer_buttons[_correct_index].add_theme_stylebox_override("disabled", _panel_style(Color(0.10, 0.26, 0.17), ACCENT, 10))
	if correct:
		if not _is_recall or _practice_mode:
			_answered_correctly += 1
			_current_score += SCORE_PER_CORRECT_ANSWER
			score_label.text = ("Practice %d" if _practice_mode else "Score %d") % _current_score
		if _is_recall and not _practice_mode:
			_recall_correct += 1
			var id: int = _current_question["_learning_id"]
			_missed_questions = _missed_questions.filter(func(q: Dictionary) -> bool: return int(q["_learning_id"]) != id)
		await _resolve_hit()
	else:
		if index >= 0:
			answer_buttons[index].add_theme_stylebox_override("disabled", _panel_style(Color(0.30, 0.11, 0.11), DANGER, 10))
		if not _is_recall or _practice_mode:
			_missed_questions.append(_current_question.duplicate(true))
			if not _practice_mode:
				_first_misses += 1
				# Two intervening questions when available; one bounded retry per error.
				var recall := _shuffle_question(_current_question)
				_turns.insert(mini(_turn_index + 3, _turns.size()), {"question": recall, "recall": true})
		await _resolve_miss()
	if run != _run_id or not is_inside_tree():
		return
	var correct_text := str(_current_question["choices"][_correct_index])
	feedback_label.text = "%s %s Answer: %s" % [verdict, _turn_effect, correct_text]
	if correct:
		feedback_label.text += " · Next question..."
		%AutoAdvanceBar.max_value = auto_advance_delay
		%AutoAdvanceBar.value = auto_advance_delay
		%AutoAdvanceBar.visible = true
		_state = "auto_advancing"
		_auto_left = auto_advance_delay
		next_button.visible = false
		return
	# Put all reading material in one expanding scroll area, including long questions.
	feedback_label.text = "%s %s" % [verdict, _turn_effect]
	question_label.visible = false
	%QuestionScroll.visible = false
	%AnswerDock.visible = false
	%ActionDock.visible = false
	%PlayerSprite.visible = false
	%EnemySprite.visible = false
	%PlayerPlatform.visible = false
	%EnemyPlatform.visible = false
	%QuestionPanel.anchor_left = 0.02
	%QuestionPanel.anchor_right = 0.98
	%ReviewQuestion.text = question_label.text
	var details: Array[String] = ["Correct answer: %s" % correct_text]
	var explanation := str(_current_question.get("explanation", "")).strip_edges()
	var page := int(_current_question.get("page", 0))
	var quote := str(_current_question.get("source_quote", "")).strip_edges()
	if explanation != "":
		details.append("Why: " + explanation)
	elif quote == "":
		details.append("Recall this: %s — %s.\nNo explanation was saved; check your reviewer for the reasoning." % [_current_question["q"], correct_text])
	if page > 0:
		details.append("Reviewer source: page %d" % page)
	if quote != "":
		details.append("“%s”" % quote)
	explanation_label.text = "\n".join(details)
	explanation_scroll.scroll_vertical = 0
	explanation_scroll.visible = true
	battlefield.visible = true
	%ChoiceGrid.visible = false
	%QuestionPanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_state = "revealed"
	next_button.text = "Continue"
	next_button.visible = true
	next_button.grab_focus()


func _on_next() -> void:
	if _state == "revealed":
		_advance_turn()


func _advance_turn() -> void:
	# Change state immediately so repeated taps cannot advance twice.
	if _state not in ["revealed", "auto_advancing"]:
		return
	_state = "advancing"
	next_button.visible = false
	if not _practice_mode and not _combat_finished and (enemy.is_down() or player.is_down()):
		_combat_finished = true
		var rest := _turns.slice(_turn_index + 1).filter(func(turn: Dictionary) -> bool: return bool(turn["recall"]))
		_turns = _turns.slice(0, _turn_index + 1) + rest
	_begin_round()


func _shuffle_question(question: Dictionary) -> Dictionary:
	var result := question.duplicate(true)
	var choices: Array = result["choices"]
	var original: int = result["correct"]
	var order: Array = range(choices.size())
	order.shuffle()
	if order.find(original) == original:
		var other := (original + 1) % order.size()
		var swap: int = order[original]
		order[original] = order[other]
		order[other] = swap
	var shuffled: Array = []
	for i: int in order:
		shuffled.append(choices[i])
	result["choices"] = shuffled
	result["correct"] = order.find(original)
	return result


func _resolve_hit() -> void:
	if _is_recall:
		_turn_effect = "Recalled in practice."
		player_sprite.play_recover()
		_audio.play_cue("recover")
		await get_tree().create_timer(0.55, false).timeout
		return
	streak += 1
	_best_streak = maxi(_best_streak, streak)
	if not _practice_mode and streak % SHIELD_COMBO == 0 and not _shield_ready:
		_shield_ready = true
		_turn_effect = "Shield earned!"
	if _selected_action == "recover":
		var restored := mini(1, player.max_hp - player.hp)
		player.hp += restored
		_turn_effect += " +%d HP." % restored
		player_sprite.play_recover()
		_audio.play_cue("recover")
		_float_number(battlefield, player_sprite.position + Vector2(60, 40), "+%d HP" % restored, ACCENT, 32)
		_refresh_bars(true)
		_update_streak_label()
		await get_tree().create_timer(0.69, false).timeout
		return
	var dealt: int = enemy.take_damage(player.atk)
	_turn_effect += " -%d enemy HP." % dealt
	_audio.play_cue("attack")

	player_sprite.play_attack(1)
	_play_ember_spark()
	await get_tree().create_timer(0.13, false).timeout
	enemy_sprite.play_hit()
	_float_number(battlefield, enemy_sprite.position + Vector2(110.0, 40.0), "-%d" % dealt,
		GOLD, 32)
	_refresh_bars(true)
	# Let the lunge, impact flash, shake, and bar tween finish before Next appears.
	await get_tree().create_timer(0.56, false).timeout

	_update_streak_label()


func _resolve_miss() -> void:
	streak = 0
	_update_streak_label()
	if _is_recall:
		_turn_effect = "Read the explanation below."
		await get_tree().create_timer(0.25, false).timeout
		return
	var blocked := _shield_ready
	_shield_ready = false
	var dealt: int = 0 if blocked else player.take_damage(enemy.atk)
	_turn_effect = "Shield blocked the hit!" if blocked else "-%d HP. You can review this later." % dealt
	_update_streak_label()

	_audio.play_cue("shield" if blocked else "hit")
	enemy_sprite.play_attack(-1)
	await get_tree().create_timer(0.13, false).timeout
	player_sprite.play_hit()
	_float_number(battlefield, player_sprite.position + Vector2(110.0, 40.0), "BLOCK" if blocked else "-%d" % dealt,
		GOLD if blocked else DANGER, 32)
	_refresh_bars(true)
	await get_tree().create_timer(0.56, false).timeout



func _end_battle(won: bool) -> void:
	if _state == "over":
		return
	_state = "over"
	if _practice_mode:
		_battle_stars = 0
		_show_results(won)
		return
	var remaining_indices: Array = []
	for question: Dictionary in _missed_questions:
		if int(question.get("_source_index",-1))>=0 and not remaining_indices.has(int(question._source_index)): remaining_indices.append(int(question._source_index))
	SharingService.queue_result(_quiz_library_id, _battle_reward_id, {
		"review_mode": "battle", "remaining_indices": remaining_indices,
		"correct": _answered_correctly, "answered": _round_number, "score": _current_score,
		"recall_correct": _recall_correct, "recall_attempted": _recall_attempted, "won": won})
	battle_completed.emit(_current_score)
	if not _quiz_library_id.is_empty():
		QuizLibrary.record_result(
			_quiz_library_id,
			"%d/%d" % [_answered_correctly, _round_number],
			won,
			Time.get_datetime_string_from_system())
	var stars := _answered_correctly * STARS_PER_CORRECT_ANSWER + (STARS_FOR_WIN if won else 0)
	_battle_stars = stars if TaskManager.award_battle_stars(_battle_reward_id, stars) else 0
	if won:
		_audio.play_cue("victory")
		enemy_sprite.play_faint()
	else:
		if player.is_down():
			player_sprite.play_faint()
	var run := _run_id
	await get_tree().create_timer(0.55, false).timeout
	if run == _run_id and is_inside_tree():
		_show_results(won)


func _show_results(won: bool) -> void:
	safe_area.visible = false
	var results_scene := preload("res://scenes/BattleResults.tscn") as PackedScene
	result_layer = results_scene.instantiate() as Control
	add_child(result_layer)
	result_layer.connect("retry_missed", _on_retry_missed)
	result_layer.connect("play_again", _on_play_again)
	result_layer.connect("my_quizzes", _on_my_quizzes)
	result_layer.connect("return_to_menu", _on_return_to_menu)
	result_layer.call("configure", {
		"won": won,
		"shared_quiz": SharingService.state.joins.has(_quiz_library_id),
		"practice": _practice_mode,
		"best_streak": _best_streak,
		"recall_correct": _recall_correct,
		"recall_attempted": _recall_attempted,
		"first_misses": _first_misses,
		"correct": _answered_correctly,
		"answered": _round_number,
		"question_count": _questions.size(),
		"score": _current_score,
		"stars": _battle_stars,
		"missed": _missed_questions.duplicate(true),
	})
func _on_retry_missed() -> void:
	if _missed_questions.is_empty():
		return
	_practice_mode = true
	_questions = _missed_questions.duplicate(true)
	for i in _questions.size():
		_questions[i] = _shuffle_question(_questions[i])
	_start_battle()


func _on_play_again() -> void:
	_practice_mode = false
	_questions = _all_questions.duplicate(true)
	_start_battle()


func _on_my_quizzes() -> void:
	var quizzes_scene := load("res://scenes/my_quizzes.tscn") as PackedScene
	if quizzes_scene != null:
		Nav.show_screen(quizzes_scene.instantiate() as Control)


func _on_return_to_menu() -> void:
	Nav.show_screen(load("res://scenes/HomeScreen.tscn").instantiate())


# ---------------------------------------------------------------- presentation

func _refresh_bars(animated: bool) -> void:
	enemy_hp_text.text = "HP %d / %d" % [enemy.hp, enemy.max_hp]
	player_hp_text.text = "HP %d / %d" % [player.hp, player.max_hp]
	enemy_hp_bar.max_value = enemy.max_hp
	player_hp_bar.max_value = player.max_hp

	if animated:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(enemy_hp_bar, "value", enemy.hp, 0.35)
		tween.tween_property(player_hp_bar, "value", player.hp, 0.35)
	else:
		enemy_hp_bar.value = enemy.hp
		player_hp_bar.value = player.hp


func _update_streak_label() -> void:
	%ShieldIcon.visible = _shield_ready
	streak_label.text = "SHIELD READY" if _shield_ready else ("Combo %d/%d" % [streak % SHIELD_COMBO, SHIELD_COMBO] if streak > 0 and not _practice_mode else "")


func _float_number(parent: Control, at: Vector2, text: String, color: Color, font_size: int) -> void:
	var l := _label(text, font_size, color)
	l.position = Vector2(clampf(at.x - 80.0, 0.0, maxf(0.0, parent.size.x - 160.0)), at.y)
	l.size = Vector2(160.0, 50.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(l, "position:y", l.position.y - 60.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(l.queue_free)


func _play_ember_spark() -> void:
	# A short projectile joins the existing lunge and impact animations.
	var spark := Polygon2D.new()
	spark.polygon = PackedVector2Array([Vector2(-16, 0), Vector2(0, -9), Vector2(18, 0), Vector2(0, 9)])
	spark.color = GOLD
	battlefield.add_child(spark)
	spark.position = player_sprite.position + player_sprite.size * 0.5
	var tween := create_tween()
	tween.tween_property(spark, "position", enemy_sprite.position + enemy_sprite.size * 0.5, 0.13)
	tween.tween_callback(spark.queue_free)


func _pause_battle() -> void:
	if _state == "over" or unavailable: return
	_paused_by_menu = true
	pause_menu.visible = true
	get_tree().paused = true
	pause_menu.get_node("%ResumeButton").grab_focus()

func _resume_battle() -> void:
	get_tree().paused = false
	_paused_by_menu = false
	pause_menu.visible = false

func _leave_paused_battle() -> void:
	_resume_battle()
	_on_my_quizzes()

func _exit_tree() -> void:
	if _paused_by_menu:
		get_tree().paused = false


func _apply_battle_safe_area() -> void:
	if OS.get_name() != "Android": return
	var safe := DisplayServer.get_display_safe_area()
	var window_size := Vector2(DisplayServer.window_get_size())
	if not safe.has_area() or window_size.x <= 0 or window_size.y <= 0: return
	var ratio := size / window_size
	safe_area.offset_left = 24 + maxf(0,safe.position.x) * ratio.x
	safe_area.offset_right = -24 - maxf(0,window_size.x-safe.end.x) * ratio.x
	safe_area.offset_top = 8 + maxf(0,safe.position.y) * ratio.y
	safe_area.offset_bottom = -8 - maxf(0,window_size.y-safe.end.y) * ratio.y
