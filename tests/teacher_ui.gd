extends Node
var failures:=0
var checks:=0
func check(value: bool,message: String)->void:
 checks+=1
 if value:print("ok ",message)
 else:failures+=1;printerr("FAIL ",message)
func settle()->void:
 for i in 6:await get_tree().process_frame
func ready_view(view: Control)->void:
 for i in 600:
  await get_tree().process_frame
  if not view.busy:break
 await settle()
func tap(button: Button)->void:
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT
 event.position=get_viewport().get_final_transform()*button.get_global_transform_with_canvas()*(button.size*0.5)
 event.pressed=true
 get_viewport().push_input(event)
 await get_tree().process_frame
 event=event.duplicate();event.pressed=false;get_viewport().push_input(event)
 await settle()
func capture(name: String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(name+".png"))
func _ready()->void:
 SharingService.base_url="http://127.0.0.1:8772"
 Nav.user.username="Presentation Student"
 Nav.user.role="student"
 var created: Dictionary=await SharingService.api("/reviews",HTTPClient.METHOD_POST,{"title":"Earth and Space Science","source_id":str(Time.get_ticks_usec()),"author":"Presentation Student","questions":QuizData.sample()})
 check(created.get("ok",false),"student creates a real pending submission")
 if not created.get("ok",false):get_tree().quit(1);return
 var id: String=created.review.id
 Nav.user.role="teacher";Nav.user.username="Myles"
 for resolution in [Vector2i(800,360),Vector2i(1280,562),Vector2i(1920,1080)]:
  get_window().size=resolution
  var menu: Control=load("res://scenes/TeacherMenu.tscn").instantiate();Nav.show_screen(menu);await ready_view(menu)
  check(menu.get_node("%Pending").owner==menu,"dashboard action is editable in scene tree")
  for field in [menu.get_node("%Pending"),menu.get_node("%Library"),menu.get_node("%Published"),menu.get_node("%Refresh")]:
   check(get_viewport().get_visible_rect().encloses(field.get_global_rect()),"dashboard control fits %d" % resolution.x)
  await capture("teacher-dashboard-%d" % resolution.x)
  await tap(menu.get_node("%Pending"))
  var panel: Control=Nav._current;await ready_view(panel)
  check(panel.filter=="pending" and panel.get_node("%Items").get_child_count()>0,"physical click opens pending quizzes")
  panel.get_node("%Search").text="Earth and Space Science";panel.get_node("%Search").text_changed.emit("Earth and Space Science");await settle()
  var card: Control=panel.get_node("%Items").get_child(0)
  check(card.size.y<270,"pending card stays compact")
  check(not card.get_node("%Tools").visible,"secondary actions start collapsed")
  await capture("teacher-pending-%d" % resolution.x)
  await tap(card.get_node("%Read"))
  check(panel.has_node("TeacherQuizReview"),"physical click opens dedicated review scene")
  var detail: Control=panel.get_node("TeacherQuizReview")
  check(detail.get_node("%Question").owner==detail,"review question is editable scene node")
  await tap(detail.get_node("%Next"));check(detail.current==1,"review next question works")
  check(get_viewport().get_visible_rect().encloses(detail.get_node("%Approve").get_global_rect()),"approve action fits landscape window")
  await capture("teacher-question-review-%d" % resolution.x)
  await tap(detail.get_node("%Back"))
  panel.get_node("%Search").text="no matching quiz";panel.get_node("%Search").text_changed.emit("no matching quiz");await settle()
  check(panel.get_node("%Empty").visible,"search has a clear empty state")
  panel.get_node("%Search").text="";panel.get_node("%Search").text_changed.emit("");await settle()
 # Approve through the review UI; then publish through the actual dialog.
 var panel: Control=Nav._current
 panel.get_node("%Search").text="Earth and Space Science";panel.get_node("%Search").text_changed.emit("Earth and Space Science");await settle()
 var card: Control=panel.get_node("%Items").get_child(0)
 await tap(card.get_node("%Read"));await tap(panel.get_node("TeacherQuizReview").get_node("%Approve"));await ready_view(panel)
 check(panel.get_node("%Items").get_child_count()==0,"approval removes quiz from pending")
 await tap(panel.get_node("%LibraryTab"));await settle()
 card=panel.get_node("%Items").get_child(0)
 await tap(card.get_node("%Publish"));check(panel.has_node("PublishReview"),"approved quiz opens publication scene")
 var publish: Control=panel.get_node("PublishReview")
 await tap(publish.get_node("%Public"));publish.get_node("%Leaderboard").button_pressed=true
 await capture("teacher-publication")
 await tap(publish.get_node("%Apply"));await ready_view(panel)
 await tap(panel.get_node("%PublishedTab"));await settle()
 card=panel.get_node("%Items").get_child(0)
 check(card.get_node("%ShareRow").visible,"published quiz displays join code")
 var code: String=card.data.code
 await tap(card.get_node("%Copy"));check(DisplayServer.clipboard_get()==code,"copy code copies only the join code")
 await capture("teacher-published")
 await tap(card.get_node("%Results"));var results: Control=Nav._current;await ready_view(results)
 check(results.get_node("%Empty").visible,"student results page shows real empty state")
 await capture("teacher-results-clean")
 # Shared controller still supports the student code entry and download.
 Nav.user.role="student";Nav.user.username="Presentation Student"
 var join: Control=load("res://scenes/TeacherReviewers.tscn").instantiate();Nav.show_screen(join);await settle()
 check(join.get_node("%StudentControls").visible and not join.get_node("%Tabs").visible,"student join controls stay separate")
 join.get_node("%CodeField").text=code
 await tap(join.get_node("%Join"));await ready_view(join)
 check(join.get_node("%OpenQuizzes").visible,"student can still download published quiz")
 print("TEACHER UI CHECKS: %d/%d passed" % [checks-failures,checks]);get_tree().quit(1 if failures else 0)
