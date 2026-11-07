extends Node
## Two-process persistence check. Run once with -- --phase write and again with
## -- --phase read, using the same Godot user-data profile for both launches.

const BACKUP_PATH := "user://daily_tasks_restart_backup.json"
var failures := 0
var checks := 0


func _ready() -> void:
	var phase := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--phase" and i + 1 < args.size():
			phase = args[i + 1]
	if phase == "write":
		_write_phase()
	elif phase == "read":
		_read_phase()
	else:
		_fail("launch with -- --phase write, then -- --phase read")
	_finish()


func _write_phase() -> void:
	var had_save := FileAccess.file_exists(TaskManager.SAVE_PATH)
	var prior_text := FileAccess.get_file_as_string(TaskManager.SAVE_PATH) if had_save else ""
	var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
	if backup == null:
		_fail("could not snapshot the current task save")
		return
	backup.store_string(JSON.stringify({"had_save": had_save, "text": prior_text}))
	backup.close()

	TaskManager._data = TaskManager._default_data()
	TaskManager._sync_periods()
	TaskManager.record_battle(TaskManager.DAILY_SCORE_TARGET)
	TaskManager.record_answer(true)
	_check(TaskManager.claim_daily_reward(), "daily reward is claimed and saved")
	_check(TaskManager.claim_weekly_reward(), "weekly reward is claimed and saved")
	_check(TaskManager.stars_balance() == 35, "both rewards are in the saved wallet")
	_check(TaskManager.award_battle_stars("restart-test-battle", 4),
		"battle Stars and their duplicate guard are saved")
	_check(TaskManager.stars_balance() == 39, "battle Stars add to the task rewards")
	print("RESTART WRITE PHASE COMPLETE")


func _read_phase() -> void:
	_check(TaskManager.daily_best_score() == TaskManager.DAILY_SCORE_TARGET,
		"daily score survives a new Godot process")
	_check(TaskManager.daily_is_claimed(), "daily claimed state survives a new process")
	_check(TaskManager.weekly_total_answers() == 1
		and TaskManager.weekly_correct_count() == 1,
		"weekly answer counts survive a new process")
	_check(TaskManager.weekly_is_claimed(), "weekly claimed state survives a new process")
	_check(TaskManager.stars_balance() == 39, "task and battle Stars survive a new process")
	_check(not TaskManager.award_battle_stars("restart-test-battle", 99)
		and TaskManager.stars_balance() == 39,
		"the same battle cannot award Stars again after restarting")

	if FileAccess.file_exists(BACKUP_PATH):
		var backup_data = JSON.parse_string(FileAccess.get_file_as_string(BACKUP_PATH))
		if typeof(backup_data) == TYPE_DICTIONARY and bool(backup_data.get("had_save", false)):
			var prior = JSON.parse_string(str(backup_data.get("text", "")))
			if typeof(prior) == TYPE_DICTIONARY:
				SaveManager.write_json(TaskManager.SAVE_PATH, prior, "daily_tasks")
			else:
				_fail("could not restore the previous task save")
		else:
			SaveManager.forget(TaskManager.SAVE_PATH)
		SaveManager.forget(BACKUP_PATH)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("  ok   ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	printerr("  FAIL ", message)


func _finish() -> void:
	if failures == 0:
		print("ALL RESTART CHECKS PASSED (%d)" % checks)
		get_tree().quit(0)
	else:
		printerr("%d RESTART CHECK(S) FAILED" % failures)
		get_tree().quit(1)
