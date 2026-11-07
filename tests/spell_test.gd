extends Node
const Cards := preload("res://scripts/quiz/spell_questions.gd")
var checks := 0
var failures := 0
var mode: Control
func check(ok: bool, message: String) -> void:
 checks += 1
 if ok: print("ok ",message)
 else:
  failures += 1
  printerr("FAIL ",message)
func tap(button: Button) -> void:
 var point := get_viewport().get_final_transform() * button.get_global_transform_with_canvas() * (button.size*0.5)
 var event := InputEventScreenTouch.new()
 event.position = point
 event.pressed = true
 Input.parse_input_event(event)
 await get_tree().process_frame
 event = InputEventScreenTouch.new()
 event.position = point
 event.pressed = false
 Input.parse_input_event(event)
 await get_tree().process_frame
func settle() -> void:
 for i in 500:
  if mode.state in ["answering","review","results"]: return
  await get_tree().process_frame
 check(false,"cast completes within bounded wait")
func correct() -> void:
 mode.select_word(mode.bank.find(mode.current.answer))
 await mode.submit()
 check(mode.state=="auto_advancing","correct spell auto-advances")
 await settle()
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless" or OS.get_cmdline_user_args().is_empty(): return
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(name+".png"))
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 Input.emulate_mouse_from_touch = true
 var terms := ["Solution","Variable","Coefficient","Equation"]
 var definitions := ["a number that makes an equation true","a letter representing an unknown number","a number multiplied by a variable","a statement that two expressions are equal"]
 var questions: Array = []
 for i in 4:
  questions.append({"q":"Which term matches this description: "+definitions[i]+"?","choices":terms.duplicate(),"correct":i,"source_quote":terms[i]+": "+definitions[i]+".","page":6,"explanation":"The reviewer defines "+terms[i]+" as "+definitions[i]+". "})
 var original := questions.duplicate(true)
 check(Cards.build(questions).size()==4,"four source-supported cloze cards")
 check(questions==original,"building spell cards does not mutate MCQs")
 var invalid: Dictionary = questions[0].duplicate(true)
 invalid.source_quote = "A solution is called a solution."
 check(Cards.build([invalid]).is_empty(),"repeated answer that leaks the solution is skipped")
 invalid.source_quote = "A mathematical sentence without the correct term."
 check(Cards.build([invalid]).is_empty(),"answer missing from source is skipped")
 invalid = questions[0].duplicate(true)
 invalid.choices = ["Solution"," solution ","Coefficient","Equation"]
 check(Cards.build([invalid]).is_empty(),"duplicate word-bank answers are skipped")
 invalid = questions[0].duplicate(true)
 invalid.page = 0
 check(Cards.build([invalid]).is_empty(),"missing source page is skipped")
 invalid = questions[0].duplicate(true)
 invalid.correct = true
 check(Cards.build([invalid]).is_empty(),"boolean answer index is rejected")
 var from_json: Array = JSON.parse_string(JSON.stringify(questions))
 check(Cards.build(from_json).size()==4,"JSON numeric indices remain playable")
 var whole_word: Dictionary = questions[0].duplicate(true)
 whole_word.source_quote = "Dissolution is not the term sought here."
 check(Cards.build([whole_word]).is_empty(),"partial-word matches do not create blanks")
 for card: Dictionary in Cards.build(questions):
  check(card.prompt.count("_____")==1 and not card.prompt.to_lower().contains(card.answer.to_lower()),"one blank with no revealed answer")
 var id := QuizLibrary.add("Spell learning test",questions,"test","spell-test")
 var library_before := QuizLibrary.get_quiz(id).duplicate(true)
 var stars: int = TaskManager.stars_balance()
 var answers: int = TaskManager.weekly_total_answers()
 var score: int = TaskManager.daily_best_score()
 get_window().size = Vector2i(800,360)
 Nav.show_screen(load("res://scenes/my_quizzes.tscn").instantiate())
 await get_tree().process_frame
 await get_tree().process_frame
 var shelf: Control = Nav._current
 shelf._on_menu_pressed(3,id,"Spell learning test")
 Nav._current.get_node("%SpellButton").pressed.emit()
 mode = Nav._current
 mode.auto_advance_delay = 0.15
 check(mode.scene_file_path.ends_with("CompleteTheSpell.tscn"),"saved quiz menu opens separate spell scene")
 check(mode.eligible.size()==4 and mode.state=="answering","persisted quiz produces playable spells")
 # Use the long first explanation to test scrollable mistake review.
 mode.deck = mode.eligible.duplicate(true)
 mode.deck[0].explanation = str(mode.deck[0].explanation).repeat(30)
 mode.begin_deck()
 check(mode.get_node("%CastButton").disabled,"Cast disabled until a word is selected")
 await mode.submit()
 check(mode.state=="answering" and mode.first_correct==0,"empty submission cannot consume a question")
 for resolution in [Vector2i(800,360),Vector2i(1280,562)]:
  get_window().size = resolution
  await get_tree().create_timer(0.2).timeout
  for button: Button in mode.words+[mode.get_node("%CastButton"),mode.get_node("%PauseButton")]:
   check(get_viewport().get_visible_rect().encloses(Rect2(button.global_position,button.size)),"spell control stays on screen at %s" % resolution)
   check(button.size.y*get_viewport().get_final_transform().get_scale().y>=48,"word-bank touch target is large enough")
  await capture("spell-layout-%d" % resolution.x)
 get_window().size = Vector2i(800,360)
 await get_tree().create_timer(0.2).timeout
 var wrong_index: int = (mode.bank.find(mode.current.answer)+1)%4
 await tap(mode.words[wrong_index])
 check(mode.get_node("%Prompt").text.contains(str(mode.bank[wrong_index])),"touch fills the blank with chosen word")
 check(not mode.get_node("%CastButton").disabled,"choosing a word enables Cast")
 await tap(mode.get_node("%CastButton"))
 check(mode.state=="review" and mode.missed.size()==1,"wrong spell opens source review")
 check(mode.get_node("%CorrectAnswer").text.contains(mode.current.answer) and mode.get_node("%SourceLabel").text.contains("6"),"review shows correct answer and reviewer page")
 await get_tree().create_timer(0.4).timeout
 check(mode.index==0 and mode.state=="review","mistake waits for reading")
 var scroll: ScrollContainer = mode.get_node("%BoardScroll")
 check(scroll.get_v_scroll_bar().max_value>scroll.get_v_scroll_bar().page,"long explanation can scroll")
 await capture("spell-review-800")
 await tap(mode.get_node("%ContinueButton"))
 check(mode.index==1 and mode.state=="answering","Continue reaches next sentence")
 # Verify pause freezes both cast resolution and automatic advancement.
 mode.select_word(mode.bank.find(mode.current.answer))
 mode.submit()
 mode.pause()
 await get_tree().create_timer(0.7).timeout
 check(mode.state=="casting","pause freezes spell animation resolution")
 mode.resume()
 await get_tree().create_timer(0.57).timeout
 check(mode.state=="auto_advancing","correct cast reaches automatic feedback")
 mode.pause()
 var time: float = mode.auto_left
 await get_tree().create_timer(0.5).timeout
 check(mode.auto_left==time,"pause freezes automatic progression")
 mode.resume()
 await settle()
 check(mode.index==2,"automatic progression advances once")
 await correct()
 await correct()
 check(mode.state=="results" and mode.first_correct==3 and mode.first_total==4,"results show first-pass accuracy separately")
 check(mode.get_node("%Results").get_node("%Practise").disabled==false,"remaining mistake enables practice")
 await capture("spell-results-800")
 var previous_position: int = mode.missed[0].last_position
 await tap(mode.get_node("%Results").get_node("%Practise"))
 check(mode.practice and mode.deck.size()==1,"results practice includes only missed sentence")
 check(mode.bank.find(mode.current.answer)!=previous_position,"practice moves correct word to another position")
 await correct()
 check(mode.state=="results" and mode.practice_correct==1 and mode.practice_attempted==1 and mode.first_correct==3,"practice recall does not overwrite first pass")
 check(mode.get_node("%Results").get_node("%Practise").disabled,"perfect practice disables retry")
 check(TaskManager.stars_balance()==stars and TaskManager.weekly_total_answers()==answers and TaskManager.daily_best_score()==score,"spell mode preserves Stars and battle task statistics")
 check(QuizLibrary.get_quiz(id)==library_before,"spell mode preserves quiz contents and battle report")
 var missing_id := QuizLibrary.add("No source",QuizData.sample(),"test","spell-missing")
 var empty: Control = load("res://scenes/CompleteTheSpell.tscn").instantiate()
 empty.library_id = missing_id
 Nav.show_screen(empty)
 check(empty.state=="unavailable" and empty.get_node("%Unavailable").visible,"unsupported quiz has honest unavailable state")
 empty.open_quizzes()
 await get_tree().process_frame
 check(Nav._current.get_script().resource_path.ends_with("my_quizzes_screen.gd"),"mode returns to saved quizzes")
 QuizLibrary.remove(id)
 QuizLibrary.remove(missing_id)
 print("SPELL CHECKS: %d/%d passed" % [checks-failures,checks])
 get_tree().quit(1 if failures else 0)

