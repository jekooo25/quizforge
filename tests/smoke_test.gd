extends Node
## Headless smoke test for the one-pass battle loop.

var battle: Control
var failures := 0
var checks_run := 0
var _previous_quiz := ""


func _ready() -> void:
	var questions := QuizData.sample()
	questions[0]["explanation"] = "The answer is supported by the saved source."
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
	_check(battle.overlay != null, "battle end screen appears")

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
