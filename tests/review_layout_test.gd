extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if ok: print("ok ", message)
 else:
  failures += 1
  printerr("FAIL ", message)
func _ready() -> void:
 for resolution in [Vector2i(800,360), Vector2i(1280,562)]:
  get_window().size = resolution
  for variant in ["short", "long-source", "long-question"]:
   var questions := QuizData.sample()
   questions[0] = {
    "q": "Fill in the blank: ____: A number that makes an equation true is a solution to that equation.",
    "choices": ["Coefficient", "Variable", "Solution", "Expression"], "correct": 2,
    "explanation": "The passage names Solution here.", "page": 6,
    "source_quote": "Solution: A number that makes an equation true is a solution to that equation."
   }
   if variant == "long-source":
    questions[0].source_quote = str(questions[0].source_quote).repeat(20) + " END OF SOURCE"
   elif variant == "long-question":
    questions[0].q = str(questions[0].q).repeat(20)
   QuizData.save("Review layout test", questions)
   var battle: Control = load("res://scenes/battle.tscn").instantiate()
   add_child(battle)
   await get_tree().process_frame
   await battle._on_answer(0)
   await get_tree().process_frame
   await get_tree().process_frame
   var scroll: ScrollContainer = battle.explanation_scroll
   var panel: Control = battle.get_node("%QuestionPanel")
   check(scroll.size.y >= panel.size.y - 40, "review uses panel height at %s / %s" % [resolution, variant])
   check(not battle.question_label.visible and battle.get_node("%ReviewQuestion").text.contains("Fill in the blank"), "long question shares the scroll area")
   check(battle.explanation_label.text.contains("Correct answer: Solution") and battle.explanation_label.text.contains("page 6"), "answer and source are in readable review content")
   check(get_viewport().get_visible_rect().encloses(Rect2(battle.next_button.global_position, battle.next_button.size)), "Continue stays on screen")
   check(scroll.get_h_scroll_bar().max_value <= scroll.get_h_scroll_bar().page + 1, "review wraps without horizontal overflow")
   if variant == "short":
    check(scroll.get_v_scroll_bar().max_value <= scroll.get_v_scroll_bar().page + 1, "screenshot-sized source fits without unnecessary clipping")
   else:
    check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "oversized content can scroll")
    scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
    await get_tree().process_frame
    await get_tree().process_frame
    var bottom: float = battle.explanation_label.global_position.y + battle.explanation_label.size.y
    check(bottom <= scroll.global_position.y + scroll.size.y + 2 and bottom >= scroll.global_position.y, "end of review text is reachable")
   if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join("review-%s-%d.png" % [variant, resolution.x]))
   battle._on_next()
   check(battle._state == "answering", "Continue still advances normally")
   battle.queue_free()
   await get_tree().process_frame
 print("REVIEW LAYOUT CHECKS: %d/%d passed" % [checks - failures, checks])
 get_tree().quit(1 if failures else 0)
