extends SceneTree
## Headless smoke test for the battle loop. Run with:
##   godot --headless --path . --script res://tests/smoke_test.gd

var battle: Control
var failures: int = 0


func _initialize() -> void:
	_run()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		failures += 1
		printerr("  FAIL ", message)


func _run() -> void:
	await process_frame
	battle = load("res://scenes/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame

	print("-- setup --")
	_check(battle.player != null and battle.player.hp == 60, "player starts at 60 HP")
	_check(battle.enemy != null and battle.enemy.hp == 60, "enemy starts at 60 HP")
	_check(battle.answer_buttons.size() == 4, "four answer buttons")
	_check(battle.question_label.text.length() > 3, "a question is displayed")
	_check(battle._state == "answering", "state is answering")

	print("-- correct answer deals damage --")
	battle._on_answer(battle._correct_index)
	await create_timer(1.9).timeout
	_check(battle.enemy.hp < 60, "enemy took damage (enemy %d/60)" % battle.enemy.hp)
	_check(battle.player.hp == 60, "player unharmed on a correct answer")
	_check(battle.streak == 1, "streak incremented")
	_check(battle._state == "answering", "next round started")

	print("-- wrong answer costs HP --")
	var before: int = battle.player.hp
	var wrong: int = (battle._correct_index + 1) % 4
	battle._on_answer(wrong)
	await create_timer(1.9).timeout
	_check(battle.player.hp < before, "player took damage (player %d/60)" % battle.player.hp)
	_check(battle.streak == 0, "streak reset")

	print("-- winning ends the battle --")
	var guard := 0
	while battle.enemy.hp > 0 and guard < 40:
		guard += 1
		battle._on_answer(battle._correct_index)
		await create_timer(1.8).timeout
	_check(battle.enemy.hp == 0, "enemy reached 0 HP")
	await create_timer(1.0).timeout
	_check(battle._state == "over", "state is over")
	_check(battle.overlay != null, "victory overlay shown")

	print("-- restart restores the battle --")
	battle._start_battle()
	await process_frame
	_check(battle.player.hp == 60, "player HP restored")
	_check(battle.enemy.hp == 60, "enemy HP restored")
	_check(battle.overlay == null, "overlay cleared")
	_check(battle._state == "answering", "battle restarted")

	print("-- timer runs out --")
	battle._time_left = 0.05
	await create_timer(0.5).timeout
	await create_timer(1.9).timeout
	_check(battle.player.hp < 60, "timeout counts as a miss")

	print("")
	if failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		printerr("%d CHECK(S) FAILED" % failures)
		quit(1)
