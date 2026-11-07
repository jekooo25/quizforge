extends Node
## Persistence and UI checks for the Daily Tasks feature.

var failures := 0
var checks_run := 0
var _previous_task_save := ""


func _ready() -> void:
	if FileAccess.file_exists(TaskManager.SAVE_PATH):
		_previous_task_save = FileAccess.get_file_as_string(TaskManager.SAVE_PATH)
	TaskManager._data = TaskManager._default_data()
	TaskManager._sync_periods()

	_check(TaskManager.daily_best_score() == 0 and not TaskManager.daily_is_complete(),
		"daily task starts from real zero progress")
	var week_start_day := TaskManager._current_week_anchor_day()
	_check(posmod(week_start_day + 4, 7) == 1,
		"weekly reset anchor resolves to Monday for the current local date")
	TaskManager.record_battle(200)
	_check(TaskManager.daily_best_score() == 200 and not TaskManager.daily_is_complete(),
		"completed battle score updates daily high score")
	TaskManager.record_battle(300)
	TaskManager.record_battle(250)
	_check(TaskManager.daily_best_score() == 300 and TaskManager.daily_is_complete(),
		"daily task keeps the best score and completes at its target")
	_check(TaskManager.claim_daily_reward(), "completed daily reward can be claimed")
	_check(not TaskManager.claim_daily_reward() and TaskManager.stars_balance() == 10,
		"daily reward cannot be claimed twice")

	for i in 4:
		TaskManager.record_answer(false)
	_check(not TaskManager.weekly_is_complete(), "weekly task is incomplete below 50 percent")
	for i in 4:
		TaskManager.record_answer(true)
	_check(TaskManager.weekly_accuracy_percent() == 50.0
		and TaskManager.weekly_correct_count() == 4
		and TaskManager.weekly_total_answers() == 8,
		"weekly accuracy is calculated from submitted correct and incorrect answers")
	_check(TaskManager.weekly_is_complete(), "weekly challenge completes at 50 percent")
	_check(TaskManager.claim_weekly_reward(), "completed weekly reward can be claimed")
	_check(not TaskManager.claim_weekly_reward() and TaskManager.stars_balance() == 35,
		"weekly reward cannot be claimed twice and Stars are added")

	TaskManager._load_state()
	_check(TaskManager.daily_best_score() == 300 and TaskManager.daily_is_claimed()
		and TaskManager.weekly_is_claimed() and TaskManager.stars_balance() == 35,
		"score, accuracy, claim state, and wallet survive a save reload")

	TaskManager._data["daily_date"] = "2000-01-01"
	TaskManager._data["daily_best_score"] = 900
	TaskManager._data["daily_claimed"] = true
	TaskManager._data["week_anchor_day"] = -100
	TaskManager._data["weekly_correct"] = 9
	TaskManager._data["weekly_total"] = 10
	TaskManager._data["weekly_completed"] = true
	TaskManager._data["weekly_claimed"] = true
	TaskManager._sync_periods()
	_check(TaskManager.daily_best_score() == 0 and not TaskManager.daily_is_claimed(),
		"daily period change resets score and claim state")
	_check(TaskManager.weekly_total_answers() == 0 and not TaskManager.weekly_is_complete()
		and not TaskManager.weekly_is_claimed(),
		"weekly period change resets accuracy and claim state")
	_check(TaskManager.stars_balance() == 35, "period resets preserve earned Stars")

	var daily_scene := load("res://scenes/DailyTasks.tscn") as PackedScene
	var screen := daily_scene.instantiate() as Control
	Nav.show_screen(screen)
	await get_tree().process_frame
	_check(screen.get_node("%DailyClaimButton").disabled
		and screen.get_node("%WeeklyClaimButton").disabled,
		"incomplete tasks show disabled claim buttons")
	_check(str(screen.get_node("%StarsLabel").text) == "Stars: 35",
		"task screen displays the saved Stars balance")
	TaskManager.record_battle(TaskManager.DAILY_SCORE_TARGET)
	await get_tree().process_frame
	_check(screen.get_node("%DailyStatusLabel").text == "COMPLETED · REWARD READY"
		and not screen.get_node("%DailyClaimButton").disabled,
		"completed task shows its status and enables the claim button")
	_check(screen.get_node("%DailyTaskIcon").scale.x > 1.05
		and screen.get_node("%DailyTaskIcon").scale.x < 1.5,
		"task completion starts the pixel icon bounce animation")
	var claim_style := screen.get_node("%DailyClaimButton").get_theme_stylebox("normal") as StyleBoxFlat
	_check(claim_style != null and claim_style.bg_color.g > claim_style.bg_color.r,
		"available claim uses the green reward button style")
	screen.get_node("%DailyClaimButton").pressed.emit()
	await get_tree().process_frame
	var reward_popup: Control = screen.get_node_or_null("RewardPopup") as Control
	_check(TaskManager.daily_is_claimed() and TaskManager.stars_balance() == 45,
		"claim button saves the reward exactly once")
	_check(reward_popup != null
		and str(reward_popup.get_node("%RewardText").text).contains("You received 10 Stars"),
		"claim displays the reward popup scene with the amount received")
	if reward_popup != null:
		reward_popup.get_node("%OKButton").pressed.emit()
		await get_tree().create_timer(0.2).timeout
	screen.get_node("%CloseButton").pressed.emit()
	await get_tree().process_frame
	_check(Nav._current != null
		and str(Nav._current.get_script().resource_path).ends_with("menu_screen.gd"),
		"close button returns to the main menu")

	_restore_task_data()
	if failures == 0:
		print("ALL DAILY TASK CHECKS PASSED (%d)" % checks_run)
		get_tree().quit(0)
	else:
		printerr("%d DAILY TASK CHECK(S) FAILED (%d ran)" % [failures, checks_run])
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	checks_run += 1
	if condition:
		print("  ok   ", message)
	else:
		failures += 1
		printerr("  FAIL ", message)


func _restore_task_data() -> void:
	if _previous_task_save == "":
		SaveManager.forget(TaskManager.SAVE_PATH)
		TaskManager._data = TaskManager._default_data()
		return
	var file := FileAccess.open(TaskManager.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(_previous_task_save)
		file.close()
	TaskManager._load_state()
