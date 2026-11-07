extends Node
var failures := 0
var checks := 0
func check(ok: bool, text: String) -> void:
 checks += 1
 if ok: print("ok ",text)
 else:
  failures += 1
  printerr("FAIL ",text)
func _ready() -> void:
 var args := OS.get_cmdline_user_args()
 var teacher := args.has("--teacher")
 var coordinate := args[0]
 Nav.user.role = "teacher" if teacher else "student"
 Nav.user.username = "Laptop Teacher" if teacher else "Laptop Student"
 Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new())
 if teacher:
  var rows: Array = []
  for i in 100:
   var reply: Dictionary = await SharingService.api("/reviews")
   rows = reply.get("reviews",[]).filter(func(r: Dictionary) -> bool: return r.source_id == coordinate)
   if not rows.is_empty(): break
   await get_tree().create_timer(0.2).timeout
  check(not rows.is_empty(),"teacher receives independent student's submission")
  if rows.is_empty(): get_tree().quit(1); return
  var id: String = rows[0].id
  var approved: Dictionary = await SharingService.api("/reviews/"+id+"/status",HTTPClient.METHOD_POST,{"status":"approved"})
  check(approved.get("ok",false),"teacher approves server submission")
  var published: Dictionary = await SharingService.api("/reviews/"+id+"/status",HTTPClient.METHOD_POST,{"status":"shared"})
  check(published.get("ok",false),"teacher publishes a join code")
  var file := FileAccess.open(coordinate,FileAccess.WRITE)
  file.store_string(published.review.code)
  file.close()
  var panel: Control = load("res://scenes/TeacherReviewers.tscn").instantiate()
  panel.filter = "shared"
  Nav.show_screen(panel)
  var report: Array = []
  for i in 150:
   var reply: Dictionary = await SharingService.api("/reviews/"+id+"/results")
   report = reply.get("results",[])
   if not report.is_empty(): break
   await get_tree().create_timer(0.2).timeout
  check(report.size()==1,"teacher receives one result after student's offline retry")
  if not report.is_empty():
   check(report[0].student=="Laptop Student" and report[0].correct==1 and report[0].answered==1 and report[0].score==100,"teacher sees correct student, accuracy, and score")
  await get_tree().create_timer(0.3).timeout
  if panel.get_node("%Items").get_child_count()>0:
   await panel.show_results(id,panel.get_node("%Items").get_child(0))
  check(panel.status_label.text.begins_with("Connected"),"teacher reporting panel connects")
 else:
  var questions := QuizData.sample().slice(0,1)
  var id := QuizLibrary.add("Laptop sharing integration",questions,"test",coordinate)
  # Use independent source ID so this test never picks another run's submission.
  var submitted: Dictionary = await SharingService.api("/reviews",HTTPClient.METHOD_POST,{"source_id":coordinate,"author":Nav.user.username,"title":"Laptop sharing integration","questions":questions})
  check(submitted.get("ok",false),"student sends real quiz to laptop server")
  for i in 150:
   if FileAccess.file_exists(coordinate): break
   await get_tree().create_timer(0.2).timeout
  if not FileAccess.file_exists(coordinate): check(false,"teacher supplied a code"); get_tree().quit(1); return
  var invalid: Dictionary = await SharingService.join_quiz("BADBAD")
  check(not invalid.get("ok",false),"invalid code gives readable failure")
  var joined: Dictionary = await SharingService.join_quiz(FileAccess.get_file_as_string(coordinate))
  check(joined.get("ok",false),"student joins teacher code from separate save folder")
  if not joined.get("ok",false): get_tree().quit(1); return
  var received := QuizLibrary.get_quiz(joined.library_id)
  check(received.questions[0].q==questions[0].q,"downloaded quiz content matches teacher publication")
  var count := QuizLibrary.count()
  await SharingService.join_quiz(FileAccess.get_file_as_string(coordinate))
  check(QuizLibrary.count()==count,"joining same code does not duplicate quiz")
  QuizLibrary.play(joined.library_id)
  var battle: Control = load("res://scenes/battle.tscn").instantiate()
  Nav.show_screen(battle)
  await get_tree().process_frame
  SharingService.base_url = "http://127.0.0.1:8767"
  battle.answer_buttons[battle._correct_index].pressed.emit()
  for i in 400:
   if battle._state=="over" and battle.result_layer!=null and not SharingService.sending: break
   await get_tree().process_frame
  check(battle._state=="over" and battle.result_layer!=null,"real battle completes and results open automatically")
  check(SharingService.state.outbox.size()==1,"server interruption leaves result saved for retry")
  var saved := SaveManager.read_json(SharingService.PATH)
  check(saved.get("ok",false) and saved.data.outbox.size()==1,"pending result is persisted on disk")
  SharingService.base_url = SharingService.URL
  var sent: Dictionary = await SharingService.send_pending()
  check(sent.get("ok",false) and SharingService.state.outbox.is_empty(),"saved result reaches server after reconnect")
 print("%s SHARING CHECKS: %d/%d passed" % ["TEACHER" if teacher else "STUDENT",checks-failures,checks])
 get_tree().quit(1 if failures else 0)
