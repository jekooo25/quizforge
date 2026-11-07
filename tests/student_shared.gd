extends Node
var checks:=0
var failures:=0
func check(ok: bool,message: String)->void:
 checks+=1
 if ok:print("ok ",message)
 else:failures+=1;printerr("FAIL ",message)
func settle()->void:
 for i in 6:await get_tree().process_frame
func wait_busy(view: Control)->void:
 for i in 600:
  await get_tree().process_frame
  if not view.busy:break
 await settle()
func tap(button: Button)->void:
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
 event.position=get_viewport().get_final_transform()*button.get_global_transform_with_canvas()*(button.size*0.5)
 event.pressed=true;get_viewport().push_input(event);await get_tree().process_frame
 event=event.duplicate();event.pressed=false;get_viewport().push_input(event);await settle()
func capture(name: String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(name+".png"))
func _ready()->void:
 SharingService.base_url="http://127.0.0.1:8773"
 Nav.user.role="student";Nav.user.username="Library Student"
 var questions:=QuizData.sample()
 var mine:=QuizLibrary.add("My own science quiz",questions,"generated","own")
 var legacy:=QuizLibrary.add("Previously downloaded quiz",questions,"received","legacy-download")
 QuizLibrary.record_result(legacy,"2/3",false,Time.get_datetime_string_from_system())
 var submitted: Dictionary=await SharingService.submit_quiz(mine)
 check(submitted.get("ok",false),"real student submission succeeds")
 var copy:=QuizLibrary.add("Renamed identical copy",questions,"draft")
 var again: Dictionary=await SharingService.submit_quiz(copy)
 check(again.get("duplicate",false) and again.review.id==submitted.review.id,"identical copy returns original submission")
 QuizLibrary.remove(copy)
 var id: String=submitted.review.id
 Nav.user.role="teacher"
 await SharingService.api("/reviews/"+id+"/status",HTTPClient.METHOD_POST,{"status":"approved"})
 var publication: Dictionary=await SharingService.api("/reviews/"+id+"/publish",HTTPClient.METHOD_POST,{"visibility":"code_only"})
 Nav.user.role="student"
 var code: String=publication.review.code
 for resolution in [Vector2i(800,360),Vector2i(1280,562)]:
  get_window().size=resolution
  var view: Control=load("res://scenes/my_quizzes.tscn").instantiate();Nav.show_screen(view);await settle()
  check(view.get_node("%QuizList").get_child_count()==1,"My Quizzes excludes existing received copies")
  await tap(view.get_node("%BrowseSharedTab"))
  check(Nav._current==view and view._tab=="browse","Shared tab stays in the student's library")
  check(view.get_node("%QuizList").get_child_count()>=1,"Shared tab lists older downloads without migration")
  check(QuizLibrary.get_quiz(legacy).last_score=="2/3","older downloaded score stays intact")
  var join: Control=view.get_node("%SharedJoin")
  check(join.get_node("%Code").owner.scene_file_path.ends_with("SharedQuizJoin.tscn"),"join controls have their own editable scene")
  await tap(join.get_node("%ToggleCode"));join.get_node("%Code").text="BAD123";await tap(join.get_node("%Join"));await wait_busy(view)
  check(not join.get_node("%Status").text.begins_with("Quiz ready"),"invalid code shows feedback")
  join.get_node("%Code").text=code;await tap(join.get_node("%Join"));await wait_busy(view)
  check(view.get_node("%QuizList").get_child_count()==2,"joined quiz appears directly in Shared Quizzes")
  var count:=QuizLibrary.count()
  await tap(join.get_node("%ToggleCode"));join.get_node("%Code").text=code;await tap(join.get_node("%Join"));await wait_busy(view)
  check(QuizLibrary.count()==count,"joining the same publication twice does not duplicate download")
  for button in [join.get_node("%Join"),join.get_node("%Public"),view.get_node("%SearchBox")]:
   check(get_viewport().get_visible_rect().encloses(button.get_global_rect()),"shared controls fit landscape viewport")
  await capture("student-shared-library-%d" % resolution.x)
  var card: Control=view.get_node("%QuizList").get_child(0)
  check(card.get_node("%MenuButton").get_popup().get_item_index(2)==-1,"shared copy cannot be submitted straight back to teacher")
  await tap(card.get_node("%PlayButton"))
  check(Nav._current.scene_file_path.ends_with("QuizDetails.tscn"),"shared quiz opens full details before starting")
  await tap(Nav._current.get_node("%BackButton"));await settle()
  check(Nav._current._tab=="browse","mode picker Back returns to Shared Quizzes")
  view=Nav._current
  await tap(view.get_node("%SharedJoin").get_node("%Public"));await wait_busy(Nav._current)
  check(Nav._current.scene_file_path.ends_with("PublicQuizzes.tscn"),"public browser remains accessible")
  await tap(Nav._current.get_node("%Back"));await settle()
  check(Nav._current._tab=="browse","public browser Back returns to shared library")
 # Older student route is forwarded to the shared library.
 Nav.show_screen(load("res://scenes/TeacherReviewers.tscn").instantiate());await settle()
 check(Nav._current.scene_file_path.ends_with("SharedQuizzes.tscn"),"legacy student join route opens actual shared library")
 print("STUDENT SHARED CHECKS: %d/%d passed" % [checks-failures,checks]);get_tree().quit(1 if failures else 0)
