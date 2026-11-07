extends Node
## Integration tests for tactical combat, automatic progress, and recall accounting.
@export var practice_only := false
var battle: Control
var checks := 0
var failures := 0
var library_id := ""
var previous_quiz := ""
var previous_tasks := ""
var weekly_before := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("ok ", message)
	else:
		failures += 1
		printerr("FAIL ", message)
func tap(button: Button) -> void:
	var point := get_viewport().get_final_transform() * button.get_global_transform_with_canvas() * (button.size * 0.5)
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventScreenTouch.new()
	event.position = point
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame
func settle() -> void:
	for i in 500:
		if battle._state in ["answering", "over", "revealed"]:
			if battle._state == "over" and battle.result_layer == null:
				await get_tree().process_frame
				continue
			return
		await get_tree().process_frame
	check(false, "turn resolves within a bounded wait")
func correct() -> void:
	await battle._on_answer(battle._correct_index)
	check(battle._state == "auto_advancing" and not battle.next_button.visible, "correct answer auto-advances without Next")
	await settle()
func wrong() -> void:
	await battle._on_answer((battle._correct_index + 1) % 4)
	check(battle._state == "revealed" and battle.next_button.visible, "mistake waits for Continue")
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().is_empty():
		return
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(name + ".png"))
func _ready() -> void:
	Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(QuizData.SAVE_PATH):
		previous_quiz = FileAccess.get_file_as_string(QuizData.SAVE_PATH)
	if FileAccess.file_exists(TaskManager.SAVE_PATH):
		previous_tasks = FileAccess.get_file_as_string(TaskManager.SAVE_PATH)
	weekly_before = TaskManager.weekly_total_answers()
	var questions: Array = []
	for i in 8:
		var q: Dictionary = QuizData.sample()[i % 5].duplicate(true)
		q.q = "Question %d: %s" % [i + 1, q.q]
		if i == 0:
			q.explanation = "Mars is called the Red Planet because iron-rich dust gives its surface a reddish appearance. ".repeat(20)
			q.page = 3
			q.source_quote = "Mars is the Red Planet."
		questions.append(q)
	library_id = QuizLibrary.add("Tactical battle test", questions, "test", "tactical-%d" % Time.get_ticks_usec())
	QuizLibrary.play(library_id)
	get_window().size = Vector2i(800,360)
	battle = load("res://scenes/battle.tscn").instantiate()
	battle.encounter_size = 0
	battle.auto_advance_delay = 0.15
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame
	if practice_only:
		await run_practice()
	else:
		await run_combat()
	finish()
func run_combat() -> void:
	check(battle._state == "answering" and battle.answer_buttons.size() == 4, "battle loads four answers")
	check(battle.recover_button.disabled, "Recover is disabled at full HP")
	check(battle.attack_button.button_pressed, "Attack is the default action")
	var time: float = battle._time_left
	battle._process(60)
	check(battle._time_left == time, "untimed battle does not run down")
	await tap(battle.timer_toggle)
	check(battle.timed_battle, "touch enables optional timer")
	battle._process(1)
	check(battle._time_left < time, "optional timer counts down")
	await tap(battle.timer_toggle)
	check(not battle.timed_battle, "timer can be disabled")
	for button: Button in battle.answer_buttons + [battle.attack_button, battle.recover_button]:
		var rect := Rect2(button.global_position, button.size)
		check(get_viewport().get_visible_rect().encloses(rect), "touch control fits phone viewport")
		check(button.size.y * get_viewport().get_final_transform().get_scale().y >= 48, "touch control is at least 48 output pixels tall")
	await capture("tactical-choices-800")
	var correct_index: int = battle._correct_index
	await tap(battle.answer_buttons[(correct_index + 1) % 4])
	battle.answer_buttons[correct_index].pressed.emit()
	battle._on_next()
	check(battle._turn_index == 0 and battle._state == "resolving", "double input cannot skip an attack animation")
	await settle()
	check(TaskManager.weekly_total_answers() == weekly_before + 1, "one touch records one first attempt")
	check(battle.player.hp == 2 and battle._state == "revealed", "wrong answer costs one HP and waits")
	check(battle.explanation_label.text.contains("iron-rich") and battle.explanation_label.text.contains("page 3") and battle.explanation_label.text.contains("Mars is the Red Planet"), "review shows saved explanation and source")
	check(battle.explanation_scroll.visible and battle.explanation_scroll.get_v_scroll_bar().max_value > battle.explanation_scroll.get_v_scroll_bar().page, "long explanation scrolls")
	await get_tree().create_timer(1.1).timeout
	check(battle._turn_index == 0, "wrong answer never auto-advances while reading")
	await capture("tactical-explanation-800")
	await tap(battle.next_button)
	check(battle._turn_index == 1 and not battle._is_recall, "Continue reaches first intervening question")
	var enemy_hp: int = battle.enemy.hp
	await correct()
	check(battle.enemy.hp == enemy_hp - 1, "Attack deals one damage on correct answer")
	check(battle._turn_index == 2 and not battle._is_recall, "correct answer advances to second intervening question")
	await tap(battle.recover_button)
	check(battle._selected_action == "recover", "touch selects Recover")
	enemy_hp = battle.enemy.hp
	await correct()
	check(battle.player.hp == 3 and battle.enemy.hp == enemy_hp, "correct Recover heals one HP without damaging enemy")
	check(battle._is_recall and battle._turn_index == 3, "mistake returns after two intervening questions")
	check(battle._correct_index != correct_index and battle._current_question.choices[battle._correct_index] == "Mars", "recall reorders choices and preserves correct answer")
	check(not battle.action_row.visible and battle.timer_toggle.disabled, "recall has no combat choice or time limit")
	var score: int = battle._current_score
	var weekly: int = TaskManager.weekly_total_answers()
	await correct()
	check(battle._recall_correct == 1 and battle._missed_questions.is_empty(), "successful recall removes question from remaining review")
	check(battle._current_score == score and TaskManager.weekly_total_answers() == weekly, "recall does not inflate first-attempt score or task accuracy")
	check(battle._round_number == 4, "first-attempt question counter excludes recall check")
	await correct()
	check(battle._shield_ready, "three correct first attempts earn shield")
	await correct()
	await wrong()
	check(battle.player.hp == 3 and not battle._shield_ready, "shield blocks one mistake")
	battle._on_next()
	await wrong()
	check(battle.player.hp == 2, "next mistake damages HP after shield is used")
	battle._on_next()
	await correct()
	check(battle._is_recall, "end of encounter drains pending recall checks")
	await wrong()
	var review_hp: int = battle.player.hp
	battle._on_next()
	check(battle._is_recall, "second pending recall is still presented")
	await correct()
	check(battle.player.hp == review_hp, "recall errors do not cost combat HP")
	check(battle._state == "over" and battle.result_layer != null, "final correct recall opens results automatically")
	check(battle._round_number == 8 and battle._answered_correctly == 5 and battle._current_score == 500, "results preserve first-attempt counts and score")
	check(battle._recall_attempted == 3 and battle._recall_correct == 2 and battle._missed_questions.size() == 1, "recall success and remaining mistakes are separate")
	check(battle.result_layer.get_node("%ResultSummary").text.contains("5 correct") and battle.result_layer.get_node("%RecallSummary").text.contains("2/3"), "results display separate accuracy and recall")
	check(TaskManager.weekly_total_answers() == weekly_before + 8, "only eight first attempts reach weekly statistics")
	var saved: Dictionary = QuizLibrary.get_quiz(library_id)
	var entries: Array = QuizLibrary.all().filter(func(item: Dictionary) -> bool: return item.id == library_id)
	check(entries[0].last_score == "5/8" and entries[0].play_count == 1, "library records first-attempt result exactly once")
	var stars: int = TaskManager.stars_balance()
	battle._end_battle(false)
	check(TaskManager.stars_balance() == stars, "repeated completion cannot award twice")
	await capture("tactical-results-800")
	battle._on_play_again()
	check(not battle._is_recall and not battle._shield_ready and battle._selected_action == "attack", "replay clears pending turn and combat state")
	for i in 6:
		await correct()
	check(battle._state == "over" and battle.result_layer.get_node("%ResultTitle").text == "VICTORY!", "winning attack opens victory without a Next tap")
	check(TaskManager.stars_balance() == stars + 8, "victory Stars use only six first-attempt answers plus win bonus")
	battle.result_layer.get_node("%MyQuizzesButton").pressed.emit()
	await get_tree().process_frame
	check(Nav._current.get_script().resource_path.ends_with("my_quizzes_screen.gd"), "results navigate back to saved quizzes")
func run_practice() -> void:
	# Three wrong first attempts knock the player out; pending recall stays safe.
	for i in 3:
		await wrong()
		battle._on_next()
	check(battle.player.is_down() and battle._is_recall, "knockout enters safe recall instead of losing review questions")
	for i in 3:
		await wrong()
		battle._on_next()
	await settle()
	check(battle._state == "over" and battle._missed_questions.size() == 3, "unrecalled questions remain available after defeat")
	var stars: int = TaskManager.stars_balance()
	var weekly: int = TaskManager.weekly_total_answers()
	var entries: Array = QuizLibrary.all().filter(func(item: Dictionary) -> bool: return item.id == library_id)
	var saved_entry: Dictionary = entries[0].duplicate(true)
	await tap(battle.result_layer.get_node("%RetryButton"))
	check(battle._practice_mode and battle._questions.size() == 3, "touch practice starts only remaining mistakes")
	check(battle.timer_toggle.disabled and not battle.action_row.visible, "practice is untimed and has no combat choice")
	var frozen: float = battle._time_left
	battle._process(1000)
	check(battle._time_left == frozen and battle._state == "answering", "practice cannot time out")
	await correct()
	check(battle._round_number == 2, "correct practice answer advances automatically")
	await wrong()
	await get_tree().create_timer(0.5).timeout
	check(battle._state == "revealed", "practice mistake waits for explanation reading")
	battle._on_next()
	await correct()
	check(battle._state == "over" and battle._missed_questions.size() == 1, "practice reaches results automatically and retains remaining mistake")
	check(TaskManager.stars_balance() == stars and TaskManager.weekly_total_answers() == weekly, "practice leaves wallet and task statistics unchanged")
	entries = QuizLibrary.all().filter(func(item: Dictionary) -> bool: return item.id == library_id)
	check(entries[0] == saved_entry, "practice preserves original library result")
	battle._on_retry_missed()
	await correct()
	check(battle.result_layer.get_node("%ResultTitle").text == "PRACTICE COMPLETE", "last correct practice answer opens completion automatically")
	check(battle.result_layer.get_node("%RetryButton").disabled, "no remaining errors disables practice button")
	battle._on_play_again()
	# Simulate an old auto-advance tick after replay: answering state must ignore it.
	var index: int = battle._turn_index
	battle._advance_turn()
	check(battle._turn_index == index, "stale auto-advance cannot skip a replay question")
	battle._questions = battle._all_questions.duplicate(true)
	battle.encounter_size = 5
	battle._start_battle()
	check(battle._questions.size() == 5 and battle._all_questions.size() == 8, "short encounter preserves full saved quiz")
	await wrong()
	battle._on_next()
	battle._select_action("recover")
	await correct()
	await correct()
	check(battle._is_recall, "short encounter includes delayed recall")
	await correct()
	await correct()
	await correct()
	check(battle._state == "over" and battle.result_layer.get_node("%ResultTitle").text == "VICTORY!",
		"five-question encounter can be won after a mistake and a Recover turn")
	battle._on_play_again()
	battle._suspended = true
	var time: float = battle._time_left
	battle.timed_battle = true
	battle._process(100)
	check(battle._time_left == time, "suspended application does not consume question time")
	battle._suspended = false
	battle._time_left = 0
	battle._process(0.01)
	await settle()
	check(battle.feedback_label.text.contains("TIME UP") and battle._state == "revealed", "optional timeout shows explanation and waits")
	battle._on_return_to_menu()
	await get_tree().process_frame
	check(Nav._current.get_script().resource_path.ends_with("menu_screen.gd"), "battle can return to menu")
func finish() -> void:
	if library_id != "":
		QuizLibrary.remove(library_id)
	SaveManager.forget(QuizData.SAVE_PATH)
	if previous_quiz != "":
		var quiz_file := FileAccess.open(QuizData.SAVE_PATH, FileAccess.WRITE)
		quiz_file.store_string(previous_quiz)
		quiz_file.close()
	SaveManager.forget(TaskManager.SAVE_PATH)
	if previous_tasks != "":
		var task_file := FileAccess.open(TaskManager.SAVE_PATH, FileAccess.WRITE)
		task_file.store_string(previous_tasks)
		task_file.close()
	print("TACTICAL %s CHECKS: %d/%d passed" % ["PRACTICE" if practice_only else "BATTLE", checks - failures, checks])
	get_tree().quit(1 if failures else 0)
