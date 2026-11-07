extends Node
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if ok: print("ok ",message)
 else:
  failures += 1
  printerr("FAIL ",message)
func wait_for_send() -> void:
 for i in 300:
  if not SharingService.sending and SharingService.state.outbox.is_empty(): return
  await get_tree().process_frame
func settle(mode: Control) -> void:
 for i in 400:
  if mode.state in ["answering","results","review"]: return
  await get_tree().process_frame
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 SharingService.base_url = "http://127.0.0.1:8768"
 var args := OS.get_cmdline_user_args()
 var coordinate := args[0]
 var teacher := args.has("--teacher")
 Nav.user.role = "teacher" if teacher else "student"
 Nav.user.username = "Reports Teacher" if teacher else "Reports Student"
 get_window().size = Vector2i(800,360)
 if teacher:
  var rows: Array = []
  for i in 200:
   var reply: Dictionary = await SharingService.api("/reviews")
   rows = reply.get("reviews",[]).filter(func(row: Dictionary) -> bool: return row.source_id==coordinate)
   if not rows.is_empty(): break
   await get_tree().create_timer(0.1).timeout
  check(not rows.is_empty(),"teacher receives student's source-supported reviewer")
  if rows.is_empty(): get_tree().quit(1); return
  var id: String = rows[0].id
  await SharingService.api("/reviews/"+id+"/status",HTTPClient.METHOD_POST,{"status":"approved"})
  var published: Dictionary = await SharingService.api("/reviews/"+id+"/status",HTTPClient.METHOD_POST,{"status":"shared"})
  var file := FileAccess.open(coordinate,FileAccess.WRITE)
  file.store_string(published.review.code)
  file.close()
  var reports: Array = []
  for i in 300:
   var reply: Dictionary = await SharingService.api("/reviews/"+id+"/results")
   reports = reply.get("results",[])
   if reports.size()==2 and reports.any(func(r: Dictionary) -> bool: return r.review_mode=="word_bank" and int(r.revision)==1): break
   await get_tree().create_timer(0.1).timeout
  check(reports.size()==2,"teacher receives exactly one battle and one word-bank round")
  var word: Array = reports.filter(func(r: Dictionary) -> bool: return r.review_mode=="word_bank")
  check(word.size()==1 and int(word[0].correct)==1 and int(word[0].answered)==2,"word-bank practice preserves original first-pass accuracy")
  check(word.size()==1 and int(word[0].recall_correct)==1 and int(word[0].recall_attempted)==1 and word[0].remaining_concepts.is_empty(),"teacher receives updated practice recall and remaining concepts")
  var screen: Control = load("res://scenes/TeacherResults.tscn").instantiate()
  screen.review_id = id
  Nav.show_screen(screen)
  for i in 200:
   if not screen.busy: break
   await get_tree().process_frame
  check(screen.get_node("%BattleList").get_child_count()==1 and screen.get_node("%SpellList").get_child_count()==1,"editable teacher scene separates review modes")
  var card: Control = screen.get_node("%SpellList").get_child(0)
  check(card.scene_file_path.ends_with("TeacherResultCard.tscn"),"report card is its own editable scene")
  check(card.get_node("%FirstPass").text.contains("50%") and card.get_node("%Recall").text.contains("1/1"),"teacher card displays separate accuracy and recall")
  check(card.get_node("%Completed").text.contains("UTC+8") and card.get_node("%Remaining").text.contains("None remaining"),"teacher card displays local completion date and remaining review")
  screen.set_filter("word_bank")
  check(not screen.get_node("%BattleSection").visible and screen.get_node("%SpellSection").visible,"Word Bank filter hides battle section")
  if not DisplayServer.get_name()=="headless":
   await get_tree().process_frame
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png(coordinate.get_base_dir().path_join("teacher-word-bank-results.png"))
  screen.set_filter("battle")
  check(screen.get_node("%BattleSection").visible and not screen.get_node("%SpellSection").visible,"Battle filter hides word-bank section")
 else:
  var choices := ["Solution","Variable","Coefficient","Equation"]
  var questions := [{"q":"Which term makes an equation true?","choices":choices,"correct":0,"source_quote":"Solution: a number that makes an equation true.","page":6,"explanation":"The definition identifies a value that satisfies the equation."},{"q":"Which term represents an unknown number?","choices":choices,"correct":1,"source_quote":"Variable: a letter representing an unknown number.","page":6,"explanation":"The letter stands for a number that is not yet known."}]
  var submitted: Dictionary = await SharingService.api("/reviews",HTTPClient.METHOD_POST,{"source_id":coordinate,"author":Nav.user.username,"title":"Word-bank teacher report demo","questions":questions})
  check(submitted.get("ok",false),"student submits quiz from independent save folder")
  for i in 200:
   if FileAccess.file_exists(coordinate): break
   await get_tree().create_timer(0.1).timeout
  if not FileAccess.file_exists(coordinate): check(false,"teacher supplies code"); get_tree().quit(1); return
  var joined: Dictionary = await SharingService.join_quiz(FileAccess.get_file_as_string(coordinate))
  check(joined.get("ok",false),"student joins teacher publication")
  if not joined.get("ok",false): get_tree().quit(1); return
  var id: String = joined.library_id
  var stars: int = TaskManager.stars_balance()
  var weekly: int = TaskManager.weekly_total_answers()
  var mode: Control = load("res://scenes/CompleteTheSpell.tscn").instantiate()
  mode.library_id = id
  mode.auto_advance_delay = 0.1
  Nav.show_screen(mode)
  mode.select_word((mode.bank.find(mode.current.answer)+1)%4)
  await mode.submit()
  mode.advance()
  mode.select_word(mode.bank.find(mode.current.answer))
  await mode.submit()
  await settle(mode)
  await wait_for_send()
  check(mode.state=="results" and mode.first_correct==1 and mode.first_total==2,"real spell round completes with first-pass counts")
  check(SharingService.state.outbox.is_empty(),"initial word-bank report is delivered")
  var attempt: String = mode.report_attempt
  SharingService.base_url = "http://127.0.0.1:8769"
  mode.practise_missed()
  mode.select_word(mode.bank.find(mode.current.answer))
  await mode.submit()
  await settle(mode)
  await get_tree().process_frame
  for i in 600:
   if not SharingService.sending: break
   await get_tree().process_frame
  check(SharingService.state.outbox.size()==1 and int(SharingService.state.outbox[0].revision)==1,"offline practice update is queued as the same round")
  check(mode.report_attempt==attempt and mode.first_correct==1,"practice retains attempt identity and first-pass score")
  var saved := SaveManager.read_json(SharingService.PATH)
  SharingService.state = saved.data
  SharingService.base_url = "http://127.0.0.1:8768"
  var sent: Dictionary = await SharingService.send_pending()
  if not sent.get("ok",false): print("SEND DIAGNOSTIC ",sent," busy=",SharingService.sending)
  check(sent.get("ok",false) and SharingService.state.outbox.is_empty(),"JSON-restored practice update sends after reconnect")
  check(TaskManager.stars_balance()==stars and TaskManager.weekly_total_answers()==weekly,"word-bank reporting does not award battle Stars or task answers")
  QuizLibrary.play(id)
  var battle: Control = load("res://scenes/battle.tscn").instantiate()
  battle.auto_advance_delay = 0.1
  Nav.show_screen(battle)
  await battle._on_answer(battle._correct_index)
  for i in 400:
   if battle._state=="over" and battle.result_layer!=null: break
   await get_tree().process_frame
  await wait_for_send()
  check(battle._state=="over" and SharingService.state.outbox.is_empty(),"battle result is delivered separately")
 print("%s REPORT CHECKS: %d/%d passed" % ["TEACHER" if teacher else "STUDENT",checks-failures,checks])
 get_tree().quit(1 if failures else 0)
