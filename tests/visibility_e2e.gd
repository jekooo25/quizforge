extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if ok: print("ok ",message)
 else:
  failures += 1
  printerr("FAIL ",message)
func save(path: String,text: String) -> void:
 var file := FileAccess.open(path,FileAccess.WRITE)
 file.store_string(text)
 file.close()
func wait_file(path: String) -> bool:
 for i in 400:
  if FileAccess.file_exists(path): return true
  await get_tree().create_timer(0.1).timeout
 return false
func wait_busy(view: Control) -> void:
 for i in 300:
  if not view.busy: return
  await get_tree().process_frame
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless": return
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].get_base_dir().path_join(name+".png"))
func _ready() -> void:
 SharingService.base_url = "http://127.0.0.1:8770"
 var coordinate := OS.get_cmdline_user_args()[0]
 var teacher := OS.get_cmdline_user_args().has("--teacher")
 Nav.user.role = "teacher" if teacher else "student"
 Nav.user.username = "Visibility Teacher" if teacher else "Visibility Student"
 get_window().size = Vector2i(800,360)
 if teacher:
  var rows: Array = []
  for i in 300:
   var reply: Dictionary = await SharingService.api("/reviews")
   rows = reply.get("reviews",[]).filter(func(r: Dictionary) -> bool: return r.source_id==coordinate)
   if not rows.is_empty(): break
   await get_tree().create_timer(0.1).timeout
  check(not rows.is_empty(),"teacher receives private submission")
  if rows.is_empty(): get_tree().quit(1); return
  var id: String = rows[0].id
  var panel: Control = load("res://scenes/TeacherReviewers.tscn").instantiate()
  panel.filter = "pending"
  Nav.show_screen(panel)
  await wait_busy(panel)
  var card: Control
  for child in panel.get_node("%Items").get_children():
   if child.get("data") is Dictionary and child.data.get("id")==id: card = child
  check(card!=null and card.scene_file_path.ends_with("ReviewerCard.tscn"),"submission card is editable scene")
  card.get_node("%Approve").pressed.emit()
  await wait_busy(panel)
  panel.filter = "list"
  panel.refresh()
  await wait_busy(panel)
  for child in panel.get_node("%Items").get_children():
   if child.get("data") is Dictionary and child.data.get("id")==id: card = child
  card.get_node("%Publish").pressed.emit()
  var dialog: Control = panel.get_node("PublishReview")
  check(dialog.selected=="private" and dialog.get_node("%Public").owner==dialog,"editable publish dialog defaults private")
  await capture("publish-visibility-dialog")
  dialog.select("code_only")
  await dialog.apply()
  await wait_busy(panel)
  var row: Dictionary = panel.rows.filter(func(r: Dictionary) -> bool: return r.id==id)[0]
  check(row.visibility=="code_only" and row.status=="shared","teacher publishes code-only through dialog")
  save(coordinate,JSON.stringify({"id":id,"code":row.code}))
  check(await wait_file(coordinate+".checked"),"student checks code-only access")
  panel.change(id,"visibility")
  dialog = panel.get_node("PublishReview")
  dialog.select("public")
  await dialog.apply()
  await wait_busy(panel)
  save(coordinate+".public","ready")
  var results: Array = []
  for i in 300:
   var reply: Dictionary = await SharingService.api("/reviews/"+id+"/results")
   results = reply.get("results",[])
   if not results.is_empty(): break
   await get_tree().create_timer(0.1).timeout
  check(results.size()==1 and int(results[0].score)==100,"public-joined game submits teacher result")
  panel.change(id,"visibility")
  dialog = panel.get_node("PublishReview")
  dialog.select("private")
  await dialog.apply()
  await wait_busy(panel)
  var report: Dictionary = await SharingService.api("/reviews/"+id+"/results")
  check(report.results.size()==1,"making private retains earlier results")
  save(coordinate+".closed","ready")
 else:
  var q := QuizData.sample().slice(0,1)
  var reply: Dictionary = await SharingService.api("/reviews",HTTPClient.METHOD_POST,{"source_id":coordinate,"author":Nav.user.username,"title":"Visibility integration quiz","questions":q,"visibility":"public"})
  check(reply.get("ok",false) and reply.review.visibility=="private","student upload cannot bypass private default")
  if not await wait_file(coordinate): check(false,"teacher provides code");get_tree().quit(1);return
  var shared: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(coordinate))
  var catalog: Dictionary = await SharingService.api("/public")
  check(not catalog.quizzes.any(func(r: Dictionary) -> bool:return r.id==shared.id),"code-only quiz is hidden from public browser")
  var denied: Dictionary = await SharingService.join_public(shared.id)
  check(not denied.get("ok",false),"public join cannot access code-only quiz")
  var joined: Dictionary = await SharingService.join_quiz(shared.code)
  check(joined.get("ok",false),"code-only quiz can be joined with code")
  QuizLibrary.record_result(joined.library_id,"1/1",true,Time.get_datetime_string_from_system())
  save(coordinate+".checked","ready")
  if not await wait_file(coordinate+".public"): check(false,"teacher publishes public");get_tree().quit(1);return
  var browser: Control = load("res://scenes/PublicQuizzes.tscn").instantiate()
  Nav.show_screen(browser)
  await wait_busy(browser)
  var public_card: Control
  for child in browser.get_node("%Items").get_children():
   if str(child.quiz_id)==shared.id: public_card = child
  check(public_card!=null and public_card.scene_file_path.ends_with("PublicQuizCard.tscn"),"public browser shows editable approved quiz card")
  await capture("public-quiz-browser")
  public_card.get_node("%Join").pressed.emit()
  for i in 300:
   if Nav._current.scene_file_path.ends_with("ReviewModeSelect.tscn"): break
   await get_tree().process_frame
  check(Nav._current.scene_file_path.ends_with("ReviewModeSelect.tscn"),"public join opens existing mode picker")
  var id: String = Nav._current.library_id
  check(id==joined.library_id,"public join reuses existing downloaded quiz")
  check(QuizLibrary.get_quiz(id).get("last_score","")=="1/1","joining again preserves previous local result")
  Nav._current.open_battle()
  var battle: Control = Nav._current
  battle.auto_advance_delay = 0.1
  await battle._on_answer(battle._correct_index)
  for i in 400:
   if battle._state=="over" and battle.result_layer!=null and not SharingService.sending and SharingService.state.outbox.is_empty(): break
   await get_tree().process_frame
  check(battle._state=="over","downloaded public quiz is playable")
  if not await wait_file(coordinate+".closed"):check(false,"teacher makes quiz private");get_tree().quit(1);return
  catalog = await SharingService.api("/public")
  check(not catalog.quizzes.any(func(r: Dictionary) -> bool:return r.id==shared.id),"private quiz disappears from catalog")
  denied = await SharingService.join_quiz(shared.code)
  check(not denied.get("ok",false),"private quiz blocks new code joins")
  check(not QuizLibrary.get_quiz(id).is_empty(),"existing student copy is preserved")
 print("%s VISIBILITY CHECKS: %d/%d passed" % ["TEACHER" if teacher else "STUDENT",checks-failures,checks])
 get_tree().quit(1 if failures else 0)
