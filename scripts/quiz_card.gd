class_name QuizCard
extends PanelContainer
## Data and interaction wiring for one instance of scenes/quiz_card.tscn.

signal play_requested(quiz_id: String)
signal action_requested(action_id: int, quiz_id: String, quiz_title: String)

@onready var quiz_title: Label = %QuizTitle
@onready var quiz_details: Label = %QuizDetails
@onready var quiz_score: Label = %QuizScore
@onready var play_button: Button = %PlayButton
@onready var menu_button: MenuButton = %MenuButton

var _quiz_id := ""
var _title := ""


func _ready() -> void:
	play_button.pressed.connect(func() -> void:
		play_requested.emit(_quiz_id))
	%OpenArea.pressed.connect(func()->void:play_requested.emit(_quiz_id))
	var popup := menu_button.get_popup()
	popup.add_item("Rename", 0)
	popup.add_item("Delete", 1)
	popup.add_item("Edit private draft", 4)
	popup.add_item("Choose review mode", 3)
	if Nav.user.get("role", "student") == "student":
		popup.add_item("Submit to teacher", 2)
	popup.id_pressed.connect(_on_action_selected)


func setup(quiz: Dictionary, detail_line: String, score_line: String) -> void:
	_quiz_id = str(quiz.get("id", ""))
	_title = str(quiz.get("title", "Untitled"))
	quiz_title.text = _title
	quiz_details.text = detail_line
	quiz_score.text = score_line
	if QuizLibrary.is_shared(quiz):
		var popup:=menu_button.get_popup()
		for id in [0,2]:
			var index:=popup.get_item_index(id)
			if index>=0:popup.remove_item(index)


func _on_action_selected(action_id: int) -> void:
	action_requested.emit(action_id, _quiz_id, _title)
