extends Node
var battle: Control
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
 checks += 1
 if ok: print("ok ",text)
 else:
  failures += 1
  printerr("FAIL ",text)
func tap(button: Button) -> void:
 await get_tree().process_frame
 await get_tree().process_frame
 var event := InputEventMouseButton.new()
 event.button_index = MOUSE_BUTTON_LEFT
 event.position = get_viewport().get_final_transform() * button.get_global_transform_with_canvas() * (button.size*0.5)
 event.pressed = true
 get_viewport().push_input(event)
 await get_tree().process_frame
 event = event.duplicate()
 event.pressed = false
 get_viewport().push_input(event)
 await get_tree().process_frame
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless" or OS.get_cmdline_user_args().is_empty(): return
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(name+".png"))
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 QuizData.save("Battle UI test",QuizData.sample())
 for resolution in [Vector2i(800,360),Vector2i(1280,562),Vector2i(1920,1080)]:
  get_window().size = resolution
  await get_tree().create_timer(0.3).timeout
  battle = load("res://scenes/battle.tscn").instantiate()
  add_child(battle)
  await get_tree().process_frame
  await get_tree().process_frame
  for name in ["HUD","QuestionPanel","ActionRow","AnswerDock","PauseButton","QuestionScroll"]:
   check(battle.get_node("%"+name).owner==battle,"editable scene node: "+name)
  check(battle.pause_menu.scene_file_path.ends_with("BattlePauseMenu.tscn"),"pause menu is an editable subscene")
  for button: Button in battle.answer_buttons + [battle.attack_button,battle.recover_button,battle.get_node("%PauseButton")]:
   check(get_viewport().get_visible_rect().encloses(Rect2(button.global_position,button.size)),"control fits viewport at %s" % resolution)
  battle.timed_battle = true
  battle._refresh_timer_mode()
  await tap(battle.get_node("%PauseButton"))
  check(get_tree().paused and battle.pause_menu.visible,"Pause opens and pauses the scene tree")
  var time: float = battle._time_left
  await get_tree().create_timer(0.4).timeout
  check(battle._time_left==time,"pause freezes question timer")
  await capture("battle-pause-%d" % resolution.x)
  await tap(battle.pause_menu.get_node("%ResumeButton"))
  check(not get_tree().paused and not battle.pause_menu.visible,"Resume restores gameplay")
  # Pause midway through the existing awaited attack timers.
  battle._on_answer(battle._correct_index)
  await get_tree().create_timer(0.05).timeout
  battle._pause_battle()
  await get_tree().create_timer(0.9).timeout
  check(battle._state=="resolving","pause freezes awaited combat animation handling")
  battle._resume_battle()
  await get_tree().create_timer(0.75).timeout
  check(battle._state=="auto_advancing" and battle.get_node("%AutoAdvanceBar").visible,"correct feedback shows auto-advance progress")
  battle._pause_battle()
  var remaining: float = battle._auto_left
  var index: int = battle._turn_index
  await get_tree().create_timer(1.2).timeout
  check(battle._auto_left==remaining and battle._turn_index==index,"pause freezes automatic progression")
  battle._resume_battle()
  await get_tree().create_timer(1.2).timeout
  check(battle._state=="answering" and battle._turn_index==index+1,"resume advances exactly one question")
  battle._pause_battle()
  await tap(battle.pause_menu.get_node("%ReturnButton"))
  check(battle.pause_menu.get_node("%LeaveConfirmation").visible,"leaving requires confirmation")
  battle.pause_menu.get_node("%LeaveConfirmation").hide()
  battle._resume_battle()
  await capture("battle-layout-%d" % resolution.x)
  battle.queue_free()
  await get_tree().process_frame
 check(not get_tree().paused,"freeing paused battle never leaves app frozen")
 print("BATTLE UI CHECKS: %d/%d passed" % [checks-failures,checks])
 get_tree().quit(1 if failures else 0)
