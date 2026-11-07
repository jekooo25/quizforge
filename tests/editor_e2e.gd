extends Node
var checks:=0
var failures:=0
func check(ok: bool,message: String)->void:
 checks+=1
 if ok:print("ok ",message)
 else:failures+=1;printerr("FAIL ",message)
func write(path: String,text: String)->void:
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()
func wait_file(path: String)->bool:
 for i in 500:
  if FileAccess.file_exists(path):return true
  await get_tree().create_timer(0.1).timeout
 return false
func wait_busy(view: Control)->void:
 for i in 600:
  if not view.busy:return
  await get_tree().process_frame
func capture(name: String)->void:
 if DisplayServer.get_name()=="headless":return
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].get_base_dir().path_join(name+".png"))
func play(id: String)->void:
 QuizLibrary.play(id)
 var battle: Control=load("res://scenes/battle.tscn").instantiate();battle.auto_advance_delay=0.05;Nav.show_screen(battle)
 for j in 6:
  if battle._state=="answering":await battle._on_answer(battle._correct_index)
  for i in 300:
   if battle._state in ["answering","over"]:break
   await get_tree().process_frame
  if battle._state=="over":break
 for i in 600:
  if battle.result_layer!=null and SharingService.state.outbox.is_empty() and not SharingService.sending:break
  await get_tree().process_frame
 check(battle._state=="over" and SharingService.state.outbox.is_empty(),"real battle completes and sends result")
func _ready()->void:
 SharingService.base_url="http://127.0.0.1:8772"
 var path:=OS.get_cmdline_user_args()[0]
 var teacher:=OS.get_cmdline_user_args().has("--teacher")
 Nav.user.role="teacher" if teacher else "student"
 Nav.user.username="Editor Teacher" if teacher else "Editor Student"
 Nav.user.leaderboard_nickname="Fox"
 get_window().size=Vector2i(800,360)
 if teacher:
  var rows: Array=[]
  for i in 400:
   var reply: Dictionary=await SharingService.api("/reviews")
   rows=reply.get("reviews",[]).filter(func(r: Dictionary)->bool:return r.title==path.get_file())
   if not rows.is_empty():break
   await get_tree().create_timer(0.1).timeout
  check(not rows.is_empty(),"teacher receives original student submission")
  if rows.is_empty():get_tree().quit(1);return
  var id: String=rows[0].id
  await SharingService.api("/reviews/"+id+"/status",HTTPClient.METHOD_POST,{"status":"approved"})
  var dialog: Control=load("res://scenes/PublishReview.tscn").instantiate();dialog.review_id=id;add_child(dialog)
  dialog.select("public");dialog.get_node("%Leaderboard").button_pressed=true
  await capture("leaderboard-publish-option")
  await dialog.apply()
  var reply: Dictionary=await SharingService.api("/reviews")
  var original: Dictionary=reply.reviews.filter(func(r: Dictionary)->bool:return r.id==id)[0]
  check(bool(original.leaderboard_enabled),"teacher enables public leaderboard through scene control")
  var original_code: String=original.code
  write(path,JSON.stringify({"id":id,"code":original.code}))
  if not await wait_file(path+".draft"):check(false,"student submits private revision");get_tree().quit(1);return
  var revision_id:=FileAccess.get_file_as_string(path+".draft")
  reply=await SharingService.api("/reviews")
  var revision: Dictionary=reply.reviews.filter(func(r: Dictionary)->bool:return r.id==revision_id)[0]
  check(revision.status=="pending" and revision.visibility=="private" and int(revision.review_version)==2,"student edit is private pending version 2")
  var blocked: Dictionary=await SharingService.api("/reviews/"+revision_id+"/publish",HTTPClient.METHOD_POST,{"visibility":"public"})
  check(not blocked.get("ok",false),"unapproved student revision cannot be published")
  var editor: Control=load("res://scenes/QuizEditor.tscn").instantiate();editor.review_id=revision_id;Nav.show_screen(editor)
  await wait_busy(editor)
  check(editor.questions.size()==5,"teacher editor loads submitted revision")
  check(editor.get_node("%Question").owner==editor,"question field is editable scene node")
  editor.get_node("%Explanation").text += " Teacher clarification."
  await capture("quiz-editor-teacher")
  await editor.save_draft()
  check(editor.review_id!=revision_id,"teacher edit creates another new private revision")
  reply=await SharingService.api("/reviews")
  var teacher_draft: Dictionary=reply.reviews.filter(func(r: Dictionary)->bool:return r.id==editor.review_id)[0]
  check(teacher_draft.status=="pending" and teacher_draft.visibility=="private","teacher-edited copy also needs explicit approval")
  await SharingService.api("/reviews/"+revision_id+"/status",HTTPClient.METHOD_POST,{"status":"approved"})
  var pub: Dictionary=await SharingService.api("/reviews/"+revision_id+"/publish",HTTPClient.METHOD_POST,{"visibility":"public","leaderboard_enabled":true})
  check(pub.get("ok",false),"approved revision can be published")
  write(path+".approved",str(pub.review.code))
  if not await wait_file(path+".played"):check(false,"student finishes both quiz versions");get_tree().quit(1);return
  var old_board: Dictionary=await SharingService.api("/public/"+id+"/leaderboard")
  var new_board: Dictionary=await SharingService.api("/public/"+revision_id+"/leaderboard")
  check(old_board.entries.size()==1 and new_board.entries.size()==1,"versions keep separate leaderboards")
  check(old_board.entries[0].nickname=="Fox" and new_board.entries[0].nickname=="Fox","leaderboards expose nickname rather than student identity")
  reply=await SharingService.api("/reviews")
  original=reply.reviews.filter(func(r: Dictionary)->bool:return r.id==id)[0]
  check(original.questions[0].q.begins_with("Which planet") and original.code==original_code and original.code!=pub.review.code,"original publication still exists")
  var view: Control=load("res://scenes/PublicLeaderboard.tscn").instantiate();view.review_id=revision_id;Nav.show_screen(view);await wait_busy(view)
  check(view.get_node("%Entries").get_child_count()==1,"editable leaderboard scene loads live ranks")
  await get_tree().process_frame
  check(view.get_node("%Entries").get_child(0).size.y<=140,"leaderboard row fits compact landscape window")
  await capture("public-quiz-leaderboard")
 else:
  var questions:=QuizData.sample()
  questions[0].source_quote="Mars is known as the Red Planet.";questions[0].page=2
  var id:=QuizLibrary.add(path.get_file(),questions,"test","editor-e2e")
  var original:=QuizLibrary.get_quiz(id).duplicate(true)
  var submitted: Dictionary=await SharingService.submit_quiz(id)
  check(submitted.get("ok",false),"saved quiz can be submitted with normalized numeric fields")
  if not await wait_file(path):check(false,"teacher publishes original");get_tree().quit(1);return
  var publication: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
  var joined: Dictionary=await SharingService.join_quiz(publication.code)
  await play(str(joined.library_id))
  var editor: Control=load("res://scenes/QuizEditor.tscn").instantiate();editor.library_id=id;Nav.show_screen(editor)
  editor.get_node("%Question").text="Revised private question: Which planet is known as the Red Planet?"
  editor.get_node("%ChoiceA").text="Mars"
  check(not editor.validate().is_empty(),"editor rejects duplicate choices")
  editor.get_node("%ChoiceA").text="Venus"
  check(editor.validate().is_empty(),"valid edit passes validation")
  var count:=QuizLibrary.count()
  editor.preview()
  check(editor.has_node("QuizPreview") and QuizLibrary.count()==count,"editable preview does not save or publish")
  editor.get_node("QuizPreview").queue_free()
  await editor.save_draft()
  var draft_id: String=editor.saved_id
  check(draft_id!="" and draft_id!=id,"saving makes a new private local draft")
  check(QuizLibrary.get_quiz(id)==original,"editor preserves original quiz and its contents")
  await editor.submit()
  var revision_id: String=SharingService.state.submissions[draft_id]
  check(revision_id!=publication.id,"student revision gets separate submission identity")
  var denied: Dictionary=await SharingService.api("/reviews/"+revision_id+"/publish",HTTPClient.METHOD_POST,{"visibility":"public"})
  check(not denied.get("ok",false),"student cannot publish their own draft")
  write(path+".draft",revision_id)
  if not await wait_file(path+".approved"):check(false,"teacher approves revised quiz");get_tree().quit(1);return
  joined=await SharingService.join_quiz(FileAccess.get_file_as_string(path+".approved"))
  check(int(SharingService.state.joins[joined.library_id].review_version)==2,"downloaded revision records quiz version")
  await play(str(joined.library_id))
  var board: Dictionary=await SharingService.api("/public/"+revision_id+"/leaderboard")
  check(board.entries.size()==1 and board.entries[0].nickname=="Fox","completed revised battle enters leaderboard")
  write(path+".played","done")
 print("%s EDITOR CHECKS: %d/%d passed" % ["TEACHER" if teacher else "STUDENT",checks-failures,checks])
 get_tree().quit(1 if failures else 0)
