extends Control
## Daily Tasks view. Layout and typography are edited in DailyTasks.tscn/theme.

const REWARD_POPUP: PackedScene = preload("res://scenes/RewardPopup.tscn")

@onready var stars_label: Label = %StarsLabel
@onready var close_button: Button = %CloseButton
@onready var daily_icon: Control = %DailyTaskIcon
@onready var daily_status_label: Label = %DailyStatusLabel
@onready var daily_progress_text: Label = %DailyProgressText
@onready var daily_progress_bar: ProgressBar = %DailyProgressBar
@onready var daily_claim_button: Button = %DailyClaimButton
@onready var weekly_icon: Control = %WeeklyTaskIcon
@onready var weekly_status_label: Label = %WeeklyStatusLabel
@onready var weekly_progress_text: Label = %WeeklyProgressText
@onready var weekly_progress_bar: ProgressBar = %WeeklyProgressBar
@onready var weekly_claim_button: Button = %WeeklyClaimButton

var _daily_was_complete := false
var _weekly_was_complete := false
var _daily_claim_pulse: Tween
var _weekly_claim_pulse: Tween


func _ready() -> void:
	_daily_was_complete = TaskManager.daily_is_complete()
	_weekly_was_complete = TaskManager.weekly_is_complete()
	close_button.pressed.connect(_on_close_pressed)
	daily_claim_button.pressed.connect(_on_daily_claim_pressed)
	weekly_claim_button.pressed.connect(_on_weekly_claim_pressed)
	TaskManager.tasks_changed.connect(_refresh)
	TaskManager.reward_claimed.connect(_on_reward_claimed)
	_refresh()


func _refresh() -> void:
	stars_label.text = "Stars: %d" % TaskManager.stars_balance()

	var daily_best := TaskManager.daily_best_score()
	var daily_target := TaskManager.DAILY_SCORE_TARGET
	daily_progress_text.text = "Best today: %d / %d Points" % [daily_best, daily_target]
	daily_progress_bar.max_value = daily_target
	daily_progress_bar.value = TaskManager.daily_progress()
	var daily_complete := TaskManager.daily_is_complete()
	var daily_claimed := TaskManager.daily_is_claimed()
	_update_task_state(daily_status_label, daily_claim_button, daily_complete, daily_claimed)
	_update_claim_pulse(daily_claim_button, daily_complete and not daily_claimed, true)
	if daily_complete and not _daily_was_complete:
		_play_completion_effect(daily_icon)
	_daily_was_complete = daily_complete

	var weekly_correct := TaskManager.weekly_correct_count()
	var weekly_total := TaskManager.weekly_total_answers()
	var weekly_accuracy := TaskManager.weekly_accuracy_percent()
	weekly_progress_text.text = "%d / %d Correct Answers · %d%% accuracy" % [
		weekly_correct, weekly_total, roundi(weekly_accuracy)]
	weekly_progress_bar.max_value = TaskManager.WEEKLY_ACCURACY_TARGET
	weekly_progress_bar.value = maxf(minf(weekly_accuracy, TaskManager.WEEKLY_ACCURACY_TARGET),
		TaskManager.WEEKLY_ACCURACY_TARGET if TaskManager.weekly_is_complete() else 0.0)
	var weekly_complete := TaskManager.weekly_is_complete()
	var weekly_claimed := TaskManager.weekly_is_claimed()
	_update_task_state(weekly_status_label, weekly_claim_button, weekly_complete, weekly_claimed)
	_update_claim_pulse(weekly_claim_button, weekly_complete and not weekly_claimed, false)
	if weekly_complete and not _weekly_was_complete:
		_play_completion_effect(weekly_icon)
	_weekly_was_complete = weekly_complete


func _update_task_state(status: Label, button: Button, completed: bool, claimed: bool) -> void:
	if claimed:
		status.text = "CLAIMED"
		status.visible = true
		button.text = "CLAIMED"
		button.disabled = true
	elif completed:
		status.text = "COMPLETED · REWARD READY"
		status.visible = true
		button.text = "CLAIM"
		button.disabled = false
	else:
		status.text = ""
		status.visible = false
		button.text = "CLAIM"
		button.disabled = true


func _update_claim_pulse(button: Button, should_pulse: bool, daily: bool) -> void:
	var pulse: Tween = _daily_claim_pulse if daily else _weekly_claim_pulse
	if should_pulse:
		if pulse != null and pulse.is_running():
			return
		button.pivot_offset = button.size * 0.5
		pulse = create_tween().set_loops()
		pulse.tween_property(button, "scale", Vector2(1.045, 1.045), 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(button, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		if pulse != null and pulse.is_running():
			pulse.kill()
		button.scale = Vector2.ONE
	if daily:
		_daily_claim_pulse = pulse
	else:
		_weekly_claim_pulse = pulse


func _play_completion_effect(icon: Control) -> void:
	icon.pivot_offset = icon.size * 0.5
	icon.scale = Vector2(0.55, 0.55)
	icon.modulate = Color(1.5, 1.35, 0.55, 1.0)
	var effect := create_tween()
	effect.tween_property(icon, "scale", Vector2(1.3, 1.3), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	effect.tween_property(icon, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	effect.parallel().tween_property(icon, "modulate", Color.WHITE, 0.4)


func _on_daily_claim_pressed() -> void:
	TaskManager.claim_daily_reward()


func _on_weekly_claim_pressed() -> void:
	TaskManager.claim_weekly_reward()


func _on_reward_claimed(_task_id: String, stars_awarded: int) -> void:
	var popup := REWARD_POPUP.instantiate() as Control
	popup.call("configure", stars_awarded, TaskManager.stars_balance())
	add_child(popup)


func _on_close_pressed() -> void:
	Nav.show_screen(load("res://scenes/HomeScreen.tscn").instantiate())
