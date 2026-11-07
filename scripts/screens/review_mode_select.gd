extends Control
const Spells := preload("res://scripts/quiz/spell_questions.gd")
@export var library_id := ""
var battle_count := 0
var spell_count := 0
var loaded := false
func _ready() -> void:
 %BackButton.pressed.connect(back)
 %BattleButton.pressed.connect(open_battle)
 %SpellButton.pressed.connect(open_spell)
 %Difficulty.add_item("Easy · 45 seconds")
 %Difficulty.add_item("Normal · 30 seconds")
 %Difficulty.add_item("Hard · 20 seconds")
 %Difficulty.select(int(Nav.user.get("battle_difficulty", 1)))
 %Difficulty.item_selected.connect(func(index: int) -> void: Nav.user["battle_difficulty"] = index)
 var quiz := QuizLibrary.get_quiz(library_id)
 var questions: Variant = quiz.get("questions",[])
 if quiz.is_empty() or not questions is Array or questions.is_empty():
  %QuizTitle.text = "Quiz unavailable"
  %Status.text = "This quiz could not be opened. Return to My Quizzes and choose another."
  %BattleReason.text = "No playable questions were found."
  %SpellReason.text = "No saved reviewer sentences were found."
  %BattleButton.disabled = true
  %SpellButton.disabled = true
  return
 loaded = true
 %QuizTitle.text = str(quiz.get("title","Untitled quiz"))
 var shared: Dictionary=SharingService.state.joins.get(library_id,{})
 if shared.has("review_version"): %QuizTitle.text += " · v%d" % int(shared.review_version)
 var all_valid := true
 for question: Variant in questions:
  if question is Dictionary and QuizData.validate([question]).is_empty(): battle_count += 1
  else: all_valid = false
 spell_count = Spells.build(questions).size()
 %BattleCount.text = "%d multiple-choice questions" % battle_count
 %SpellCount.text = "%d source-supported sentences" % spell_count
 %BattleButton.disabled = not all_valid or battle_count==0
 %SpellButton.disabled = spell_count==0
 %BattleReason.text = "Up to 5 questions per battle. First-attempt scores count toward battle progress." if all_valid else "Some questions are incomplete. Review or regenerate this quiz before battling."
 %SpellReason.text = "Up to 5 sentences per round. Practice scores stay separate from battles." if spell_count>0 else "Needs a source page and quote with the answer once. Regenerate this quiz."
 %Status.text = "Choose how you want to review. Both modes use this saved quiz."
 if not %BattleButton.disabled: %BattleButton.grab_focus()
 elif not %SpellButton.disabled: %SpellButton.grab_focus()
 else: %BackButton.grab_focus()
 resized.connect(_apply_safe_area)
 _apply_safe_area.call_deferred()
func open_battle() -> void:
 if %BattleButton.disabled: return
 if not QuizLibrary.play(library_id):
  %Status.text = "This quiz could not be saved for battle. Try again."
  return
 Nav.show_screen(load("res://scenes/battle.tscn").instantiate())
func open_spell() -> void:
 if %SpellButton.disabled: return
 var mode: Control = load("res://scenes/CompleteTheSpell.tscn").instantiate()
 mode.library_id = library_id
 Nav.show_screen(mode)
func back() -> void:
 var path: String="res://scenes/SharedQuizzes.tscn" if QuizLibrary.is_shared({"id":library_id,"source":QuizLibrary.get_quiz(library_id).get("source","")}) else "res://scenes/my_quizzes.tscn"
 Nav.show_screen(load(path).instantiate())
func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  back()
func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready(): back()
func _apply_safe_area() -> void:
 if OS.get_name()!="Android": return
 var safe := DisplayServer.get_display_safe_area()
 var dimensions := Vector2(DisplayServer.window_get_size())
 if not safe.has_area() or dimensions.x<=0 or dimensions.y<=0: return
 var ratio := size/dimensions
 %SafeArea.offset_left = 32+maxf(0,safe.position.x)*ratio.x
 %SafeArea.offset_right = -32-maxf(0,dimensions.x-safe.end.x)*ratio.x
 %SafeArea.offset_top = 16+maxf(0,safe.position.y)*ratio.y
 %SafeArea.offset_bottom = -16-maxf(0,dimensions.y-safe.end.y)*ratio.y
