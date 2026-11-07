extends Node
var checks:=0
var failures:=0
func check(ok: bool,message: String)->void:
 checks+=1
 if ok:print("ok ",message)
 else:failures+=1;printerr("FAIL ",message)
func settle()->void:
 for i in 6:await get_tree().process_frame
func wait_generation(view: Control)->void:
 for i in 3600:
  await get_tree().process_frame
  if view._finished:return
 check(false,"generation completes within timeout")
func tap(button: Button)->void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true
 e.position=get_viewport().get_final_transform()*button.get_global_transform_with_canvas()*(button.size*0.5)
 get_viewport().push_input(e);await get_tree().process_frame
 e=e.duplicate();e.pressed=false;get_viewport().push_input(e);await settle()
func capture(name: String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(name+".png"))
func upload()->Control:
 var view: Control=load("res://scenes/UploadReviewer.tscn").instantiate();Nav.show_screen(view);await settle();return view
func _ready()->void:
 Nav.user.role="student";Nav.user.username="Myles";Nav.user.server_url="http://127.0.0.1:8774"
 var root:=OS.get_cmdline_user_args()[0]
 QuizData.save("Previous active quiz",QuizData.sample())
 var before:=FileAccess.get_file_as_string(QuizData.SAVE_PATH)
 for resolution in [Vector2i(800,360),Vector2i(1280,562)]:
  get_window().size=resolution
  var view: Control=await upload()
  check(view.get_node("%Generate").disabled,"generation blocked before choosing a file")
  view._on_file_selected(root.path_join("upload-preview-empty.txt"))
  check(view.get_node("%Generate").disabled and view.get_node("%Status").text.contains("empty"),"empty file rejected before upload")
  view._on_file_selected(root.path_join("unsupported.docx"))
  check(view.get_node("%Generate").disabled and view.get_node("%Status").text.contains("Unsupported"),"unsupported format rejected")
  view.get_node("%FileDialog").file_selected.emit(root.path_join("upload-preview-source.txt"))
  check(not view.get_node("%Generate").disabled and view.get_node("%FileInfo").text.contains("KB"),"real file selection shows format and size")
  check(not view.get_node("%PdfOptions").visible,"PDF range hidden for text files")
  view.get_node("%Mode").select(1);view.update_mode(1)
  check(view.get_node("%ModeHint").text.contains("missing answer") or view.get_node("%ModeHint").text.contains("sentences"),"Word Bank format has a clear explanation")
  for name in ["Generate","Pick","Mode","Count"]:check(get_viewport().get_visible_rect().encloses(view.get_node("%"+name).get_global_rect()),"upload control fits landscape: "+name)
  await capture("upload-reviewer-%d" % resolution.x)
  var count:=QuizLibrary.count()
  await tap(view.get_node("%Generate"))
  var generation: Control=Nav._current;await wait_generation(generation);await settle()
  check(generation._failure=="" and not generation.get_node("%Preview").disabled,"real TXT generation finishes without sample substitution")
  check(QuizLibrary.count()==count and FileAccess.get_file_as_string(QuizData.SAVE_PATH)==before,"generation does not save or replace active quiz")
  check(generation._payload.questions.size()>0 and generation._payload.source.provider=="offline","offline service produces source-backed questions")
  await capture("generate-quiz-%d" % resolution.x)
  await tap(generation.get_node("%Preview"));var preview: Control=Nav._current
  check(preview.scene_file_path.ends_with("GeneratedQuizPreview.tscn"),"generated quiz opens editable preview scene")
  check(preview.get_node("%StylePreview").visible and preview.get_node("%StylePreview").text.contains("____"),"Word Bank preview displays an actual source sentence blank")
  check(preview.get_node("%Question").owner!=null and not preview.get_node("%Submit").visible,"preview reuses scene-tree fields and does not publish")
  await tap(preview.get_node("%Source"))
  check(preview.get_node("%Text").text.contains("Solution") and preview.get_node("%Text").text.contains("\n"),"source dialog shows original readable text")
  preview.get_node("%SourceDialog").hide()
  await capture("generated-preview-%d" % resolution.x)
  var choice: String=preview.get_node("%ChoiceA").text
  preview.get_node("%ChoiceA").text=preview.get_node("%ChoiceB").text
  await preview.save_draft();check(Nav._current==preview and QuizLibrary.count()==count,"invalid duplicate choices block saving")
  preview.get_node("%ChoiceA").text=choice
  var edited: String=preview.get_node("%Question").text+" (reviewed)"
  preview.get_node("%Question").text=edited
  await tap(preview.get_node("%Save"))
  var detail: Control=Nav._current
  check(detail.scene_file_path.ends_with("QuizDetails.tscn") and detail.selected_mode=="word_bank","Save opens details with selected review style")
  check(QuizLibrary.count()==count+1 and QuizLibrary.get_quiz(detail.library_id).questions[0].q==edited,"edited questions saved exactly once")
  check(FileAccess.get_file_as_string(QuizData.SAVE_PATH)==before,"saving waits for Start before changing the active battle quiz")
 # PDF page-range feedback through the real HTTP endpoint.
 var view: Control=await upload()
 view._on_file_selected(root.path_join("upload-preview-source.pdf"))
 check(view.get_node("%PdfOptions").visible,"PDF enables optional page range")
 view.get_node("%Pages").text="not pages";view._on_continue();check(Nav._current==view,"invalid page syntax stays on upload")
 view.get_node("%Pages").text="999";await tap(view.get_node("%Generate"));await wait_generation(Nav._current)
 check(Nav._current._failure.contains("page range") and Nav._current.get_node("%Preview").disabled,"out-of-range PDF pages show useful failure")
 await tap(Nav._current.get_node("%Back"));view=Nav._current
 view._on_file_selected(root.path_join("upload-preview-source.pdf"));view.get_node("%Mode").select(0)
 view.get_node("%Pages").text="1";await tap(view.get_node("%Generate"));await wait_generation(Nav._current)
 check(Nav._current._failure=="" and Nav._current._payload.questions.size()>0,"real text PDF generates successfully")
 var generation: Control=Nav._current
 for question: Dictionary in generation._payload.questions:check(not question.q.contains("____"),"Quiz Battle question is complete multiple choice")
 # Insufficient text produces actionable feedback, no stale quiz reuse.
 view=await upload();view._on_file_selected(root.path_join("upload-preview-short.txt"));await tap(view.get_node("%Generate"));await wait_generation(Nav._current)
 check(Nav._current._failure.contains("Not enough") and Nav._current.get_node("%Retry").visible,"short source offers retry and a useful reason")
 var failure: Control=Nav._current;failure._review_questions();check(Nav._current==failure,"failed generation cannot open an old saved quiz")
 print("UPLOAD PREVIEW CHECKS: %d/%d passed" % [checks-failures,checks]);get_tree().quit(1 if failures else 0)
