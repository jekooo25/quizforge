extends PanelContainer

@onready var question_label: Label = %QuestionText
@onready var answer_label: Label = %CorrectAnswer
@onready var explanation_label: Label = %Explanation
@onready var source_label: Label = %Source


func configure(index: int, question: Dictionary) -> void:
	question_label.text = "%d. %s" % [index + 1, str(question.get("q", ""))]
	var choices: Array = question.get("choices", [])
	var correct_index := int(question.get("correct", -1))
	var answer := str(choices[correct_index]) if correct_index >= 0 and correct_index < choices.size() else "Unavailable"
	answer_label.text = "Correct answer: %s" % answer
	explanation_label.text = str(question.get("explanation", "")).strip_edges()
	explanation_label.visible = explanation_label.text != ""
	var source := ""
	if int(question.get("page", 0)) > 0:
		source = "Source: page %d" % int(question["page"])
	var quote := str(question.get("source_quote", "")).strip_edges()
	if quote != "":
		source += (" · " if source != "" else "") + "“%s”" % quote
	source_label.text = source
	source_label.visible = source != ""
