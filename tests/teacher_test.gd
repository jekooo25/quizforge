extends Node
const Reviews := preload("res://scripts/teacher_reviews.gd")
var failures := 0
var checks := 0
func check(ok: bool, msg: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL ",msg)
 else: print("ok ",msg)
func tap(button: Button) -> void:
 var event := InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.position = get_viewport().get_final_transform() * button.get_global_transform_with_canvas() * (button.size * 0.5)
 event.pressed = true
 get_viewport().push_input(event)
 await get_tree().process_frame
 event = event.duplicate()
 event.pressed = false
 get_viewport().push_input(event)
 await get_tree().process_frame
func _ready() -> void:
 # Server-backed approval is covered by teacher_ui.tscn. This test is the
 # offline dashboard/layout smoke test and must not depend on saved reviews.
 Nav.user.role = "teacher"
 Nav.user.username = "Teacher test"
 for resolution in [Vector2i(800,360),Vector2i(1280,562)]:
  get_window().size = resolution
  Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new())
  await get_tree().process_frame
  await get_tree().process_frame
  check(Nav._current.scene_file_path.ends_with("TeacherMenu.tscn"),"teacher routes to dashboard")
  # TeacherCards now lives inside the editable Column in TeacherMenu.tscn;
  # use its unique scene name instead of the old code-built menu path.
  var cards: HBoxContainer = Nav._current.get_node("%TeacherCards")
  check(cards != null and cards.get_child_count()==3,"three teacher panels")
  if cards != null:
   for card: Control in cards.get_children():
 check(get_viewport().get_visible_rect().encloses(Rect2(card.global_position,card.size)),"teacher card fits viewport")
  if not OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("teacher-menu-%d.png" % resolution.x))
  var pending_button: Button = Nav._current.get_node("%Pending")
  # The dashboard now reads reviews from the laptop sharing server.  Keep this
  # offline smoke test focused on editable layout and routing; the server-backed
  # approval/publishing journey is exercised by teacher_ui.tscn.
  check(pending_button != null and pending_button.text == "Review pending","pending action is available")
  check(Nav._current.get_node("%Library") != null and Nav._current.get_node("%Published") != null,"library and published actions are available")
 Nav.user.role = "student"
 Nav.user.username = "Student test"
 Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new())
 check(Nav._current.get_script().resource_path.ends_with("/menu_screen.gd"),"student menu preserved")
 print("TEACHER CHECKS: %d/%d passed" % [checks-failures,checks])
 get_tree().quit(1 if failures else 0)
