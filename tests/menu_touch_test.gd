extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL ", message)
 else:
  print("ok ", message)
func tap(button: Button) -> void:
 var at := get_viewport().get_final_transform() * button.get_global_transform_with_canvas() * (button.size * 0.5)
 var touch := InputEventScreenTouch.new()
 touch.index = 0
 touch.position = at
 touch.pressed = true
 Input.parse_input_event(touch)
 await get_tree().process_frame
 touch = InputEventScreenTouch.new()
 touch.index = 0
 touch.position = at
 touch.pressed = false
 Input.parse_input_event(touch)
 await get_tree().process_frame
 await get_tree().process_frame
func menu() -> Control:
 var view: Control = load("res://scripts/screens/menu_screen.gd").new()
 Nav.show_screen(view)
 await get_tree().process_frame
 await get_tree().process_frame
 return view
func _ready() -> void:
 Input.emulate_mouse_from_touch = true
 for resolution in [Vector2i(800,360), Vector2i(1280,562), Vector2i(1920,1080), Vector2i(2400,1080)]:
  get_window().size = resolution
  var view: Control = await menu()
  var cards: HBoxContainer = view._content.get_node("MenuCards")
  var frame := get_viewport().get_final_transform()
  var controls: Array = cards.get_children() + [view._profile, view._gear, view._shop_button]
  for button: Button in controls:
   var rect := Rect2(frame * button.global_position, button.size * frame.get_scale())
   check(rect.size.x >= 48 and rect.size.y >= 48, "%s touch target at %s" % [button.name, resolution])
   check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(rect), "%s stays on screen" % button.name)
  await tap(cards.get_node("PlayQuizzes"))
  check(Nav._current.get_script().resource_path.ends_with("my_quizzes_screen.gd"), "touch Play Quizzes opens library")
  view = await menu()
  await tap(view._content.get_node("MenuCards/UploadReviewer"))
  check(Nav._current.get_script().resource_path.ends_with("upload_screen.gd"), "touch Upload Reviewer opens upload")
  view = await menu()
  await tap(view._content.get_node("MenuCards/DailyTasks"))
  check(Nav._current.get_script().resource_path.ends_with("DailyTasks.gd"), "touch Daily Tasks opens tasks")
  view = await menu()
  await tap(view._shop_button)
  check(Nav._current.get_script().resource_path.ends_with("StarsShop.gd"), "touch Shop opens shop")
  view = await menu()
  await tap(view._gear)
  check(Nav._current.get_script().resource_path.ends_with("settings_screen.gd"), "touch Settings opens settings")
  view = await menu()
  var before := view.get_child_count()
  await tap(view._profile)
  check(view.get_child_count() > before, "touch Profile opens profile")
 print("MENU TOUCH CHECKS: %d passed / %d" % [checks - failures, checks])
 get_tree().quit(1 if failures else 0)
