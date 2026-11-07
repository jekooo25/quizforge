extends Control
## Scene-backed results view for one completed battle.

signal retry_missed
signal play_again
signal my_quizzes
signal return_to_menu

const MISSED_QUESTION_SCENE: PackedScene = preload("res://scenes/BattleMissedQuestion.tscn")

@onready var title_label: Label = %ResultTitle
@onready var summary_label: Label = %ResultSummary
@onready var score_label: Label = %FinalScore
@onready var stars_label: Label = %StarsEarned
@onready var missed_list: VBoxContainer = %MissedList
@onready var perfect_run_label: Label = %PerfectRunLabel
@onready var retry_button: Button = %RetryButton
@onready var play_again_button: Button = %PlayAgainButton
@onready var my_quizzes_button: Button = %MyQuizzesButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	retry_button.pressed.connect(func() -> void: retry_missed.emit())
	play_again_button.pressed.connect(func() -> void: play_again.emit())
	my_quizzes_button.pressed.connect(func() -> void: my_quizzes.emit())
	menu_button.pressed.connect(func() -> void: return_to_menu.emit())


func configure(result: Dictionary) -> void:
	var practice := bool(result.get("practice", false))
	var delivery := UITheme.sans("Shared quiz: results are saved for delivery. If offline, retry from Shared quizzes.",20,Color.WHITE)
	delivery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delivery.visible = bool(result.get("shared_quiz",false)) and not practice
	%LearningTip.get_parent().add_child(delivery)
	var won := bool(result.get("won", false))
	var correct := int(result.get("correct", 0))
	var answered := int(result.get("answered", 0))
	var unattempted := maxi(0, int(result.get("question_count", answered)) - answered)
	var incorrect := maxi(0, answered - correct)
	var accuracy := int(round(100.0 * float(correct) / float(maxi(answered, 1))))
	title_label.text = ("PRACTICE COMPLETE" if won else "KEEP PRACTICING") if practice else ("VICTORY!" if won else "DEFEAT")
	title_label.modulate = Color("7dda9f") if won else Color("e8695f")
	title_label.scale = Vector2(0.82, 0.82)
	title_label.pivot_offset = title_label.size * 0.5
	var title_tween := create_tween()
	title_tween.tween_property(title_label, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	summary_label.text = ("%d practised · %d recalled · %d to review · %d%% recall" if practice else "%d first attempts · %d correct · %d incorrect · %d%% accuracy") % [
		answered, correct, incorrect, accuracy]
	score_label.text = "Recalled %d of %d in practice" % [correct, answered] if practice else "Final score: %d  ·  Best combo: %d" % [int(result.get("score", 0)), int(result.get("best_streak", 0))]
	%RecallSummary.text = "Recall checks: %d/%d recalled · %d still to review" % [int(result.get("recall_correct", 0)), int(result.get("recall_attempted", 0)), result.get("missed", []).size()]
	%RecallSummary.visible = not practice and int(result.get("first_misses", 0)) > 0
	stars_label.text = "Practice keeps your battle score and Stars unchanged." if practice else "+%d Stars earned" % int(result.get("stars", 0))
	
	for child in missed_list.get_children():
		if child != perfect_run_label:
			child.queue_free()
	var missed: Array = result.get("missed", [])
	retry_button.disabled = missed.is_empty()
	perfect_run_label.visible = missed.is_empty()
	perfect_run_label.text = "All reviewed answers recalled! Try the full quiz later." if practice else ("Earlier mistakes recalled. Try again later to check retention." if int(result.get("first_misses", 0)) > 0 else "No missed answers in this encounter!")
	%LearningTip.text = ("You recalled these answers now. Revisit the full quiz later." if won else "Still unsure? Read the source, then practise the remaining questions.") if practice else "Read your missed answers below, then practise them without a timer or HP loss."
	if retry_button.disabled:
		play_again_button.grab_focus()
	else:
		retry_button.grab_focus()
	if not practice and unattempted > 0:
		if int(result.get("first_misses", 0)) == 0:
			perfect_run_label.text = "No mistakes among answered questions."
		%LearningTip.text += " %d questions were not reached; play the full quiz again to study them." % unattempted
	for i in missed.size():
		_add_missed_question(i, missed[i])


func _add_missed_question(index: int, question: Dictionary) -> void:
	var card := MISSED_QUESTION_SCENE.instantiate() as PanelContainer
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	missed_list.add_child(card)
	card.call("configure", index, question)
