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
func _ready()->void:
 Input.emulate_mouse_from_touch=true
 Nav.user.role="student"
 var title:="Upper Extremity Kinesiology and Orthopedics: Shoulder, Elbow, Wrist and Hand Assessment with Rehabilitation Principles and Clinical Practice"
 var questions:=QuizData.sample()
 for i in 9:
  QuizLibrary.add(title if i==0 else "Shared science quiz %d" % i,questions,"received","mobile-title-%d" % i)
 QuizLibrary.add("Unbroken_"+"VeryLongDocumentFilename".repeat(10),questions,"received","mobile-title-long-token")
 for resolution in [Vector2i(800,360),Vector2i(1280,562),Vector2i(1920,1080)]:
  get_window().size=resolution
  var view: Control=load("res://scenes/SharedQuizzes.tscn").instantiate();Nav.show_screen(view);await settle()
  var scroll: ScrollContainer=view.get_node("%QuizScroll")
  check(scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"horizontal scrolling disabled at %d" % resolution.x)
  check(scroll.get_h_scroll_bar().max_value<=scroll.size.x+1,"no horizontal content overflow")
  var long_card: QuizCard
  for card: QuizCard in view.get_node("%QuizList").get_children():
   check(card.size.x<=scroll.size.x,"quiz card fits list width")
   if card.quiz_title.text==title:long_card=card
   check(card.quiz_title.get_line_count()>=1 and card.quiz_title.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART,"titles wrap including unbroken filenames")
   check(card.quiz_details.get_global_rect().end.x<=card.get_global_rect().end.x,"metadata stays inside card")
  check(long_card!=null and long_card.quiz_title.get_line_count()>1,"long title occupies multiple visible lines")
  check(long_card.quiz_title.get_visible_line_count()==long_card.quiz_title.get_line_count(),"full title remains visible without truncation")
  check(long_card.play_button.size.y<100,"REVIEW button does not stretch with title height")
  check(long_card.quiz_title.get_global_rect().end.x<=long_card.play_button.global_position.x,"wrapped title cannot overlap REVIEW")
  await capture("mobile-shared-wrapped-%d" % resolution.x)
  var before:=scroll.scroll_vertical
  await touch_drag(scroll)
  check(scroll.scroll_vertical>before,"finger swipe scrolls quiz list")
  check(Nav._current==view,"swiping does not launch a quiz")
  scroll.scroll_vertical=0
  await settle()
  await touch_drag(scroll,long_card.play_button.global_position+long_card.play_button.size*0.5)
  check(scroll.scroll_vertical>0,"swipe starting on REVIEW still scrolls")
  check(Nav._current==view,"swiping over REVIEW does not trigger it")
  scroll.scroll_vertical=0
  await settle()
  var tap:=InputEventScreenTouch.new();tap.index=0;tap.pressed=true;tap.position=get_viewport().get_final_transform()*(long_card.play_button.global_position+long_card.play_button.size*0.5)
  Input.parse_input_event(tap);await get_tree().process_frame
  tap=tap.duplicate();tap.pressed=false;Input.parse_input_event(tap);await settle()
  check(Nav._current.scene_file_path.ends_with("ReviewModeSelect.tscn"),"finger tap on REVIEW opens the quiz")
 print("MOBILE QUIZ TITLE CHECKS: %d/%d passed" % [checks-failures,checks]);get_tree().quit(1 if failures else 0)
