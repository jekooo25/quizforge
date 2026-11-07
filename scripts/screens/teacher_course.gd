extends Control
var course_id: String = ""
var course_title: String = "Course"
var sections: Array = ["Section 101 · Mon/Wed 8:00–9:30 AM", "Section 202 · Tue/Thu 1:00–2:30 PM"]
var students: Array = ["Ari Santos", "Mika Reyes", "Jordan Lee", "Sam Rivera", "Taylor Cruz"]
func _ready() -> void:
	%Title.text = course_title
	%Back.pressed.connect(_back)
	%UploadReviewer.pressed.connect(_upload_reviewer)
	%Scope.add_item("Publish to all sections")
	for section: String in sections:
		%Scope.add_item(section)
	%Publish.pressed.connect(_publish)
	for section: String in sections:
		var button: Button = Button.new()
		button.text = section
		button.custom_minimum_size = Vector2(0, 60)
		button.pressed.connect(_show_roster.bind(section))
		%Items.add_child(button)
func _show_roster(section: String) -> void:
	%Items.visible = false
	%Roster.visible = true
	%Hint.text = section + " · Students"
	for student: String in students:
		var label: Label = Label.new()
		label.text = "• " + student
		label.add_theme_font_size_override("font_size", 22)
		%Roster.add_child(label)

func _upload_reviewer() -> void:
	Nav.user["course_id"] = course_id
	Nav.call_deferred("show_screen", load("res://scenes/UploadReviewer.tscn").instantiate())

func _publish() -> void:
	var target: String = %Scope.get_item_text(%Scope.selected)
	var deadline: String = %Deadline.text.strip_edges()
	if deadline == "":
		%Status.text = "Add a deadline before publishing."
		return
	%Status.text = "Quiz queued for %s · due %s" % [target, deadline]
func _back() -> void:
	Nav.call_deferred("show_screen", load("res://scenes/TeacherMenu.tscn").instantiate())
