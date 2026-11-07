extends Node
func _ready() -> void:
 var teacher: bool = OS.get_cmdline_user_args().has("--teacher")
 var second_student: bool = OS.get_cmdline_user_args().has("--student-2")
 Nav.user.role = "teacher" if teacher else "student"
 Nav.user.username = "Demo Teacher" if teacher else "Demo Student 2" if second_student else "Demo Student"
 get_window().title = "Quizforge · %s · Laptop presentation demo" % Nav.user.role
 if not teacher and QuizLibrary.count() == 0:
  QuizLibrary.add("DEMO · General Knowledge",QuizData.sample(),"demo","presentation-sample")
 Nav.show_screen(load("res://scenes/TeacherMenu.tscn").instantiate() if teacher else load("res://scenes/HomeScreen.tscn").instantiate())
