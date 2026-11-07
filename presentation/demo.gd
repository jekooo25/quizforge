extends Node
func _ready() -> void:
 var teacher := OS.get_cmdline_user_args().has("--teacher")
 Nav.user.role = "teacher" if teacher else "student"
 Nav.user.username = "Demo Teacher" if teacher else "Demo Student"
 get_window().title = "Quizforge · %s · Laptop presentation demo" % Nav.user.role
 if not teacher and QuizLibrary.count() == 0:
  QuizLibrary.add("DEMO · General Knowledge",QuizData.sample(),"demo","presentation-sample")
 Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new())
