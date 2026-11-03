extends Node
## Headless smoke test for the battle loop. Run with:
##   godot --headless --path . res://tests/smoke.tscn
##
## The battle refuses to invent a quiz now, so this test writes its own known set
## first instead of depending on whatever happens to be saved on the machine.
##
## This runs as a scene rather than a --script entry point: a --script main loop
## is compiled before the autoloads exist, so anything it references statically
## (QuizData, and through it SaveManager) fails to resolve.

## Every check this run must reach. A script error inside an assertion skips it
## without counting as a failure, which would otherwise print "ALL CHECKS PASSED"
## over a crashed run.
const EXPECTED_CHECKS := 21

var battle: Control
var failures: int = 0
var checks_run: int = 0
var _previous_quiz := ""


func _ready() -> void:
	_run()


func _check(condition: bool, message: String) -> void:
	checks_run += 1
	if condition:
		print("  ok   ", message)
	else:
		failures += 1
		printerr("  FAIL ", message)


func _finish(code: int) -> void:
	# put the machine's own quiz back
	SaveManager.forget(QuizData.SAVE_PATH)
	if _previous_quiz != "":
		var f := FileAccess.open(QuizData.SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_previous_quiz)
			f.close()
	get_tree().quit(code)


func _run() -> void:
	if SaveManager == null:
		printerr("  FAIL the SaveManager autoload did not load")
		printerr("SMOKE CHECKS FAILED")
		get_tree().quit(1)
		return

	await get_tree().process_frame

	if FileAccess.file_exists(QuizData.SAVE_PATH):
		_previous_quiz = FileAccess.get_file_as_string(QuizData.SAVE_PATH)
	QuizData.save("smoke test", QuizData.sample())

	battle = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame
	await get_tree().process_frame

	print("-- setup --")
	_check(battle.player != null and battle.player.hp == 60, "player starts at 60 HP")
	_check(battle.enemy != null and battle.enemy.hp == 60, "enemy starts at 60 HP")
	_check(battle.answer_buttons.size() == 4, "four answer buttons")
	_check(battle.question_label.text.length() > 3, "a question is displayed")
	_check(battle._state == "answering", "state is answering")
	_check(battle.unavailable == false, "the battle actually started")
	_check(battle._questions.size() == QuizData.sample().size(),
		"it plays the saved quiz, not a substitute")

	print("-- correct answer deals damage --")
	battle._on_answer(battle._correct_index)
	await get_tree().create_timer(1.9).timeout
	_check(battle.enemy.hp < 60, "enemy took damage (enemy %d/60)" % battle.enemy.hp)
	_check(battle.player.hp == 60, "player unharmed on a correct answer")
	_check(battle.streak == 1, "streak incremented")
	_check(battle._state == "answering", "next round started")

	print("-- wrong answer costs HP --")
	var before: int = battle.player.hp
	var wrong: int = (battle._correct_index + 1) % 4
	battle._on_answer(wrong)
	await get_tree().create_timer(1.9).timeout
	_check(battle.player.hp < before, "player took damage (player %d/60)" % battle.player.hp)
	_check(battle.streak == 0, "streak reset")

	print("-- winning ends the battle --")
	var guard := 0
	while battle.enemy.hp > 0 and guard < 40:
		guard += 1
		battle._on_answer(battle._correct_index)
		await get_tree().create_timer(1.8).timeout
	_check(battle.enemy.hp == 0, "enemy reached 0 HP")
	await get_tree().create_timer(1.0).timeout
	_check(battle._state == "over", "state is over")
	_check(battle.overlay != null, "victory overlay shown")

	print("-- restart restores the battle --")
	battle._start_battle()
	await get_tree().process_frame
	_check(battle.player.hp == 60, "player HP restored")
	_check(battle.enemy.hp == 60, "enemy HP restored")
	_check(battle.overlay == null, "overlay cleared")
	_check(battle._state == "answering", "battle restarted")

	print("-- timer runs out --")
	battle._time_left = 0.05
	await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(1.9).timeout
	_check(battle.player.hp < 60, "timeout counts as a miss")

	if checks_run != EXPECTED_CHECKS:
		failures += 1
		printerr("  FAIL ran %d checks, expected %d — an assertion errored and was skipped" % [
			checks_run, EXPECTED_CHECKS])

	print("")
	if failures == 0:
		print("ALL CHECKS PASSED")
		_finish(0)
	else:
		printerr("%d CHECK(S) FAILED" % failures)
		_finish(1)
