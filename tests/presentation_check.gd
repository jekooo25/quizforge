extends Node
func _ready() -> void:
 var demo: Node = load("res://presentation/demo.tscn").instantiate()
 add_child(demo)
 await get_tree().create_timer(0.5).timeout
 var teacher := OS.get_cmdline_user_args().has("--teacher")
 if teacher:
  var panel: Control = load("res://scenes/TeacherReviewers.tscn").instantiate()
  panel.filter = "shared"
  Nav.show_screen(panel)
  await get_tree().create_timer(0.5).timeout
 get_window().size = Vector2i(800,360)
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var args := OS.get_cmdline_user_args()
 get_viewport().get_texture().get_image().save_png(args[0].path_join("sharing-" + ("teacher" if teacher else "student") + ".png"))
 print("PRESENTATION SCENE OK: ", Nav.user.role, " quiz count=", QuizLibrary.count())
 get_tree().quit()

