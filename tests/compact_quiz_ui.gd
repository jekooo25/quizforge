extends Node
var checks:=0
var failures:=0
func check(ok: bool,message: String)->void:
 checks+=1
 if ok:print("ok ",message)
 else:failures+=1;printerr("FAIL ",message)
func settle()->void:
 for i in 8:await get_tree().process_frame
func touch_drag(scroll: ScrollContainer,start: Vector2=Vector2.ZERO)->void:
 var point:=scroll.global_position+Vector2(scroll.size.x*0.4,scroll.size.y-20) if start==Vector2.ZERO else start
 var transform:=get_viewport().get_final_transform()
 var down:=InputEventScreenTouch.new();down.index=0;down.pressed=true;down.position=transform*point
 Input.parse_input_event(down)
 await get_tree().process_frame
 for i in 12:
  var next:=point+Vector2(0,-12)
  var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=transform*next;drag.relative=transform*next-transform*point
  Input.parse_input_event(drag);point=next
  await get_tree().process_frame
 var up:=InputEventScreenTouch.new();up.index=0;up.pressed=false;up.position=transform*point
 Input.parse_input_event(up);await settle()
func capture(name: String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(name+".png"))
func tap(button: Button)->void:
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=get_viewport().get_final_transform()*(button.global_position+button.size*0.5)
 get_viewport().push_input(event);await get_tree().process_frame
 event=event.duplicate();event.pressed=false;get_viewport().push_input(event);await settle()
func _ready()->void:
 Input.emulate_mouse_from_touch=true
 Nav.user.role="student";Nav.user.username="Myles"
 var title:="Upper Extremity Kinesiology and Orthopedics: Shoulder, Elbow, Wrist and Hand Assessment with Rehabilitation Principles and Clinical Practice"
 var questions:=QuizData.sample();questions[0].source_quote="Mars is known as the Red Planet.";questions[0].page=2
 var id:=QuizLibrary.add(title,questions,"received","compact-long")
 for i in 6:QuizLibrary.add("Science review %d" % i,questions,"received","compact-%d" % i)
 var own:=QuizLibrary.add("Private quiz",questions,"draft","private")
 QuizData.save("Active quiz preserved",QuizData.sample())
 var saved:=FileAccess.get_file_as_string(QuizData.SAVE_PATH)
 for resolution in [Vector2i(800,360),Vector2i(1280,562),Vector2i(1920,1080)]:
  get_window().size=resolution
  var view: Control=load("res://scenes/SharedQuizzes.tscn").instantiate();Nav.show_screen(view);await settle()
  var join: Control=view.get_node("%SharedJoin")
  check(not join.get_node("%Entry").visible,"code entry starts collapsed")
  check(not join.get_node("%Send").visible,"retry hidden with no pending results")
  await tap(join.get_node("%ToggleCode"));check(join.get_node("%Entry").visible,"Join with code reveals entry")
  await tap(join.get_node("%ToggleCode"));check(not join.get_node("%Entry").visible,"code entry can collapse")
  var scroll: ScrollContainer=view.get_node("%QuizScroll")
  check(scroll.get_h_scroll_bar().max_value<=scroll.size.x+1,"list has no sideways overflow")
  var long_card: QuizCard
  for card: QuizCard in view.get_node("%QuizList").get_children():
   check(card.size.y<=190,"card stays compact with long title")
   check(card.quiz_title.get_visible_line_count()<=2,"card title preview shows at most two lines")
   if card._quiz_id==id:long_card=card
  check(long_card!=null,"long-title shared quiz remains listed")
  await capture("compact-shared-quizzes-%d" % resolution.x)
  var before:=scroll.scroll_vertical;await touch_drag(scroll)
  check(scroll.scroll_vertical>before and Nav._current==view,"finger swipes scroll without opening a quiz")
  scroll.scroll_vertical=0;await settle()
  scroll.ensure_control_visible(long_card);await settle()
  await tap(long_card.get_node("%OpenArea"))
  var detail: Control=Nav._current
  check(detail.scene_file_path.ends_with("QuizDetails.tscn"),"tapping card opens its own details scene")
  check(detail.get_node("%QuizTitle").text==title,"details show the complete original title")
  check(detail.get_node("%QuizTitle").owner==detail and detail.get_node("%Start").owner==detail,"details controls are editable scene nodes")
  check(detail.battle_count==5 and detail.spell_count==1,"details preserve real mode availability")
  check(FileAccess.get_file_as_string(QuizData.SAVE_PATH)==saved,"viewing details does not replace active quiz")
  check(get_viewport().get_visible_rect().encloses(detail.get_node("%Start").get_global_rect()),"Start remains visible at every window size")
  check(detail.get_node("%Scroll").get_h_scroll_bar().max_value<=detail.get_node("%Scroll").size.x+1,"full title never requires sideways scrolling")
  await capture("compact-quiz-details-%d" % resolution.x)
  detail.get_node("%Scroll").ensure_control_visible(detail.get_node("%SpellButton"));await settle()
  await tap(detail.get_node("%SpellButton"))
  check(Nav._current==detail and detail.selected_mode=="word_bank","selecting a mode waits for Start")
  await tap(detail.get_node("%Start"))
  check(Nav._current.scene_file_path.ends_with("CompleteTheSpell.tscn") and Nav._current.library_id==id,"Start opens selected word-bank quiz")
  detail=load("res://scenes/QuizDetails.tscn").instantiate();detail.library_id=id;Nav.show_screen(detail);await settle()
  await tap(detail.get_node("%BackButton"));check(Nav._current.scene_file_path.ends_with("SharedQuizzes.tscn"),"details Back returns to Shared Quizzes")
 var detail: Control=load("res://scenes/QuizDetails.tscn").instantiate();detail.library_id=own;Nav.show_screen(detail);await settle()
 await tap(detail.get_node("%Start"));check(Nav._current.scene_file_path.ends_with("battle.tscn") and Nav._current._quiz_library_id==own,"default Start opens the correct battle")
 detail=load("res://scenes/QuizDetails.tscn").instantiate();detail.library_id="missing";Nav.show_screen(detail);await settle()
 check(detail.get_node("%Start").disabled,"missing quiz cannot start")
 SharingService.state.outbox=[{"attempt_id":"test-pending"}]
 Nav.show_screen(load("res://scenes/SharedQuizzes.tscn").instantiate());await settle()
 check(Nav._current.get_node("%SharedJoin").get_node("%Send").visible,"pending results reveal retry action")
 SharingService.state.outbox=[]
 print("COMPACT QUIZ UI CHECKS: %d/%d passed" % [checks-failures,checks]);get_tree().quit(1 if failures else 0)
