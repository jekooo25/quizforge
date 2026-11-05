extends Node
## Headless smoke test for the one-pass battle loop.

var battle: Control
var failures := 0
var checks_run := 0
var _previous_quiz := ""


func _ready() -> void:
	var questions := QuizData.sample()
	questions[0]["explanation"] = "The answer is supported by the saved source. ".repeat(24)
	questions[0]["page"] = 3
	questions[0]["source_quote"] = "A source sentence."
	if FileAccess.file_exists(QuizData.SAVE_PATH):
		_previous_quiz = FileAccess.get_file_as_string(QuizData.SAVE_PATH)
	QuizData.save("battle smoke", questions)
	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(battle.player.hp == battle.DEMO_PLAYER_HP, "demo player starts at named demo HP")
	_check(battle.enemy.max_hp == int(ceil(questions.size() * battle.TARGET_CORRECT_RATIO)),
		"enemy HP targets the named correct-answer ratio")
	_check(battle.answer_buttons.size() == 4 and battle._state == "answering",
		"four choices and a question are ready")
	_check(battle.question_label.get_theme_font_size("font_size") >= 28
		and battle.answer_buttons[0].get_theme_font_size("font_size") >= 28,
		"question and choice text are at least 28px at design scale")
	_check(battle.ROUND_TIME >= 30.0, "timer allows time to read the question and choices")
	_check(battle._round_number == 1, "first question starts at index one")

	var first_correct: int = battle._correct_index
	await battle._on_answer((first_correct + 1) % 4)
	_check(battle._state == "revealed", "answer selection locks in a revealed state")
	_check(battle.answer_buttons.all(func(button: Button) -> bool: return button.disabled),
		"all answer buttons lock after selection")
	_check(battle.next_button.visible, "Next button appears after selection")
	_check(battle.explanation_label.text.contains("The answer is supported"),
		"explanation is shown after the answer")
	_check(battle.explanation_label.text.contains("page 3")
		and battle.explanation_label.text.contains("A source sentence"),
		"page and source excerpt are shown after the answer")
	await get_tree().process_frame
	_check(battle.explanation_scroll.visible, "the explanation area is a visible scroll container")
	_check(battle.explanation_scroll.get_v_scroll_bar().max_value
		> battle.explanation_scroll.get_v_scroll_bar().page,
		"long explanations can scroll instead of overflowing the card")
	await get_tree().create_timer(0.2).timeout
	_check(battle._round_number == 1, "question does not auto-advance")
	battle._on_next()
	await get_tree().process_frame
	_check(battle._round_number == 2 and battle._state == "answering",
		"Next advances to the next saved question")

	# Finish with correct answers until the enemy is knocked out.
	while not battle.enemy.is_down() and battle._round_number <= questions.size():
		await battle._on_answer(battle._correct_index)
		if not battle.enemy.is_down():
			battle._on_next()
			await get_tree().process_frame
	_check(battle.enemy.is_down(), "about 70 percent correct knocks out the scaled enemy")
	_check(battle._round_number <= questions.size(), "questions are not reshuffled indefinitely")
	await battle._on_next()
	await get_tree().create_timer(0.8).timeout
	_check(battle._state == "over", "knockout ends the battle")
	_check(battle.result_title_label.text == "Victory", "win results screen appears")
	_check(battle.result_stats_label.text.contains("4 / 5")
		and battle.result_stats_label.text.contains("80%"), "win results show correct/total and accuracy")
	_check(battle.result_missed_list.get_child_count() == 1, "missed question is listed in results")
	var missed_column := battle.result_missed_list.get_child(0).get_child(0) as VBoxContainer
	_check(missed_column.get_child_count() >= 3
		and str((missed_column.get_child(1) as Label).text).contains("Mars")
		and str((missed_column.get_child(2) as Label).text).contains("supported by the saved source"),
		"missed-question result includes its correct answer and explanation")
	_check(battle.retry_missed_button.visible and battle.retry_missed_button.disabled == false
		and battle.play_again_button.visible and battle.my_quizzes_button.visible,
		"results offer Retry missed, Play again, and My quizzes")

	battle._on_retry_missed()
	await get_tree().process_frame
	_check(battle._questions.size() == 1 and battle._round_number == 1,
		"Retry missed starts a battle containing only missed questions")
	await battle._on_answer(battle._correct_index)
	battle._on_next()
	await get_tree().create_timer(0.8).timeout
	_check(battle.result_title_label.text == "Victory"
		and battle.retry_missed_button.disabled, "perfect retry has no missed questions to retry")

	battle._on_play_again()
	await get_tree().process_frame
	_check(battle._questions.size() == questions.size() and battle._state == "answering",
		"Play again restores the full quiz")
	for i in 3:
		await battle._on_answer((battle._correct_index + 1) % 4)
		battle._on_next()
		if i < 2:
			await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	_check(battle.result_title_label.text == "Defeat", "loss results screen appears after player knockout")
	battle.my_quizzes_button.pressed.emit()
	await get_tree().process_frame
	_check(Nav._current != null
		and str(Nav._current.get_script().resource_path).ends_with("my_quizzes_screen.gd"),
		"My quizzes button leaves the results screen")

	if failures == 0:
		print("ALL CHECKS PASSED (%d)" % checks_run)
		_finish(0)
	else:
		printerr("%d CHECK(S) FAILED (%d ran)" % [failures, checks_run])
		_finish(1)


func _finish(code: int) -> void:
	SaveManager.forget(QuizData.SAVE_PATH)
	if _previous_quiz != "":
		var f := FileAccess.open(QuizData.SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_previous_quiz)
			f.close()
	get_tree().quit(code)


func _check(condition: bool, message: String) -> void:
	checks_run += 1
	if condition:
		print("  ok   ", message)
	else:
		failures += 1
		printerr("  FAIL ", message)
