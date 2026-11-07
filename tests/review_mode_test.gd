extends Node
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
 checks += 1
 if ok: print("ok ",text)
 else:
  failures += 1
  printerr("FAIL ",text)
func tap(button: Button) -> void:
 var event := InputEventScreenTouch.new()
 event.position = get_viewport().get_final_transform()*button.get_global_transform_with_canvas()*(button.size*0.5)
 event.pressed = true
 Input.parse_input_event(event)
 await get_tree().process_frame
 event = InputEventScreenTouch.new()
 event.position = get_viewport().get_final_transform()*button.get_global_transform_with_canvas()*(button.size*0.5)
 event.pressed = false
 Input.parse_input_event(event)
 await get_tree().process_frame
func show_picker(id: String) -> Control:
 var view: Control = load("res://scenes/ReviewModeSelect.tscn").instantiate()
 view.library_id = id
 Nav.show_screen(view)
 await get_tree().process_frame
 await get_tree().process_frame
 return view
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless" or OS.get_cmdline_user_args().is_empty(): return
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(name+".png"))
func _ready() -> void:
 Input.emulate_mouse_from_touch = true
 var questions := QuizData.sample()
 questions[0].source_quote = "Mars is known as the Red Planet."
 questions[0].page = 2
 questions[0].explanation = "The reviewer identifies Mars as the Red Planet."
 var id := QuizLibrary.add("Algebra and science reviewer",questions,"test","mode-picker")
 var no_source := QuizLibrary.add("Older multiple-choice quiz",QuizData.sample(),"test","mode-no-source")
 QuizData.save("Previously selected quiz",QuizData.sample())
 var saved_before := FileAccess.get_file_as_string(QuizData.SAVE_PATH)
 for size in [Vector2i(800,360),Vector2i(1280,562)]:
  saved_before = FileAccess.get_file_as_string(QuizData.SAVE_PATH)
  get_window().size = size
  Nav.show_screen(load("res://scenes/my_quizzes.tscn").instantiate())
  await get_tree().process_frame
  await get_tree().process_frame
  Nav._current._on_menu_pressed(3,id,"")
  await get_tree().process_frame
  await get_tree().process_frame
  var picker: Control = Nav._current
  check(picker.scene_file_path.ends_with("ReviewModeSelect.tscn"),"saved quiz opens editable mode scene")
  check(picker.battle_count==5 and picker.spell_count==1,"mode counts reflect saved quiz and eligible source quotes")
  check(not picker.get_node("%BattleButton").disabled and not picker.get_node("%SpellButton").disabled,"both available modes are enabled")
  check(FileAccess.get_file_as_string(QuizData.SAVE_PATH)==saved_before,"opening picker does not overwrite active battle quiz")
  for name in ["BattleCard","SpellCard","BattleCount","SpellCount","BattleReason","SpellReason","BackButton"]:
   check(picker.get_node("%"+name).owner==picker,"scene-tree editable: "+name)
  check(picker.get_node("%QuizTitle").text=="Algebra and science reviewer","selected quiz title is visible")
  check(picker.get_node("%Scroll").get_h_scroll_bar().max_value<=picker.get_node("%Scroll").get_h_scroll_bar().page+1,"mode cards do not overflow sideways")
  await capture("review-mode-picker-%d" % size.x)
  picker.get_node("%Scroll").ensure_control_visible(picker.get_node("%SpellButton"))
  await get_tree().process_frame
  await tap(picker.get_node("%SpellButton"))
  check(Nav._current.scene_file_path.ends_with("CompleteTheSpell.tscn") and Nav._current.library_id==id,"touch starts the selected quiz's word-bank mode")
  picker = await show_picker(id)
  picker.get_node("%Scroll").ensure_control_visible(picker.get_node("%BattleButton"))
  await get_tree().process_frame
  await tap(picker.get_node("%BattleButton"))
  check(Nav._current.scene_file_path.ends_with("battle.tscn") and Nav._current._quiz_library_id==id,"touch starts correct saved quiz in battle")
  var loaded := QuizData.load_saved()
  check(loaded.title=="Algebra and science reviewer","battle choice hands quiz to existing save path")
  QuizData.save("Previously selected quiz",QuizData.sample())
 var picker: Control = await show_picker(no_source)
 check(picker.battle_count==5 and picker.spell_count==0,"older quiz remains available for battle")
 check(not picker.get_node("%BattleButton").disabled and picker.get_node("%SpellButton").disabled,"unsupported word-bank mode is disabled")
 check(picker.get_node("%SpellReason").text.contains("source page and quote"),"unavailable mode gives actionable explanation")
 picker.open_spell()
 check(Nav._current==picker,"disabled mode cannot be opened")
 await capture("review-mode-unavailable")
 picker = await show_picker("missing-library-id")
 check(not picker.loaded and picker.get_node("%BattleButton").disabled and picker.get_node("%SpellButton").disabled,"missing quiz disables both modes safely")
 picker.open_battle()
 check(Nav._current==picker,"missing quiz cannot overwrite battle data")
 await tap(picker.get_node("%BackButton"))
 check(Nav._current.get_script().resource_path.ends_with("my_quizzes_screen.gd"),"Back returns to saved quizzes")
 var invalid := questions.duplicate(true)
 invalid[0].choices = ["Missing other choices"]
 var invalid_id := QuizLibrary.add("Incomplete quiz",invalid,"test","mode-invalid")
 picker = await show_picker(invalid_id)
 check(picker.get_node("%BattleButton").disabled and picker.get_node("%BattleReason").text.contains("incomplete"),"malformed battle questions show a repair explanation")
 QuizLibrary.remove(id)
 QuizLibrary.remove(no_source)
 QuizLibrary.remove(invalid_id)
 print("MODE PICKER CHECKS: %d/%d passed" % [checks-failures,checks])
 get_tree().quit(1 if failures else 0)
