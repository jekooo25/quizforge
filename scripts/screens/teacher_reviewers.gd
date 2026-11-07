extends Control
var filter := "pending"
var status_label: Label
var code_field: LineEdit
var busy := false
var rows: Array = []
func _ready() -> void:
 if Nav.user.get("role","student")=="student":
  Nav.show_screen.call_deferred(load("res://scenes/SharedQuizzes.tscn").instantiate())
  return
 if OS.get_name()=="Android":get_tree().quit_on_go_back=false
 var teacher: bool=Nav.user.get("role","student")=="teacher"
 status_label=%Status
 code_field=%CodeField
 %Tabs.visible=teacher
 %Search.visible=teacher
 %StudentControls.visible=not teacher
 %StudentBrowse.visible=not teacher
 %Back.text="Dashboard" if teacher else "Main menu"
 %Nickname.text=str(Nav.user.get("leaderboard_nickname",""))
 %Nickname.text_changed.connect(func(value: String)->void:Nav.user["leaderboard_nickname"]=value)
 %BrowsePublic.pressed.connect(func()->void:Nav.show_screen(load("res://scenes/PublicQuizzes.tscn").instantiate()))
 %Back.pressed.connect(func()->void:Nav.call_deferred("show_screen",load("res://scenes/TeacherMenu.tscn").instantiate()) if teacher else Nav.call_deferred("show_screen",load("res://scenes/HomeScreen.tscn").instantiate()))
 %Refresh.pressed.connect(refresh)
 %PendingTab.pressed.connect(set_filter.bind("pending"))
 %LibraryTab.pressed.connect(set_filter.bind("list"))
 %PublishedTab.pressed.connect(set_filter.bind("shared"))
 %Search.text_changed.connect(func(_text: String)->void:render())
 %SearchButton.pressed.connect(render)
 %Course.item_selected.connect(_course_selected)
 %AutoApprove.toggled.connect(_set_auto_approve)
 %Join.pressed.connect(join_quiz)
 %Send.pressed.connect(send_results)
 %OpenQuizzes.pressed.connect(func()->void:Nav.show_screen(load("res://scenes/my_quizzes.tscn").instantiate()))
 resized.connect(_apply_safe_area)
 _apply_safe_area.call_deferred()
 refresh()
 _load_course_settings()

func _load_course_settings() -> void:
 var reply: Dictionary=await SharingService.api("/courses")
 if not is_inside_tree() or not reply.get("ok",false):
  %ApprovalSettings.visible=false
  return
 for course_value: Variant in reply.get("courses",[]):
  var course: Dictionary=course_value as Dictionary
  %Course.add_item("%s · %s" % [str(course.get("code","")),str(course.get("title","Course"))])
  %Course.set_item_metadata(%Course.item_count-1,str(course.get("id","")))
 %ApprovalSettings.visible=%Course.item_count>0
 if %Course.item_count>0: _course_selected(0)

func _course_selected(index: int) -> void:
 if index<=0 and %Course.item_count==0:return
 var course_id: String=str(%Course.get_item_metadata(index))
 var reply: Dictionary=await SharingService.api("/courses/%s" % course_id)
 if reply.get("ok",false):%AutoApprove.set_pressed_no_signal(bool(reply.get("auto_publish",false)))

func _set_auto_approve(enabled: bool) -> void:
 if %Course.selected<0:return
 var course_id: String=str(%Course.get_item_metadata(%Course.selected))
 await SharingService.api("/courses/%s/settings" % course_id,HTTPClient.METHOD_POST,{"auto_publish":enabled})
func set_filter(value: String) -> void:
 filter=value
 render()
func render() -> void:
 clear_items()
 %Title.text={"pending":"Review submissions","list":"Quiz library","shared":"Published quizzes"}.get(filter,"Quizzes")
 %Notice.text={"pending":"Read each quiz before approving it for publication.","list":"Approved quizzes are ready to publish. Edits create a new private revision.","shared":"Copy a join code, manage visibility or view student results."}.get(filter,"")
 var pending:=0
 var library:=0
 var shared:=0
 var shown:=0
 var last_course: String = ""
 for row: Dictionary in rows:
  if row.status=="pending" and row.get("duplicate_of","")!="":continue
  if row.status=="pending":pending+=1
  else:library+=1
  if row.status=="shared":shared+=1
  if filter=="pending" and row.status!="pending":continue
  if filter=="list" and row.status=="pending":continue
  if filter=="shared" and row.status!="shared":continue
  var query: String=%Search.text.strip_edges().to_lower()
  if query!="" and not (str(row.title)+" "+str(row.author)+" "+str(row.get("course_title",""))+" "+str(row.get("course_code",""))).to_lower().contains(query):continue
  var course_name: String = str(row.get("course_title", "Unassigned"))
  if course_name != last_course:
   var heading: Label = Label.new()
   heading.text = course_name + (" (" + str(row.get("course_code", "")) + ")" if str(row.get("course_code", "")) != "" else "")
   heading.add_theme_font_size_override("font_size", 26)
   heading.add_theme_color_override("font_color", Color(1.0, 0.80, 0.32, 1.0))
   %Items.add_child(heading)
   last_course = course_name
  add_review(row)
  shown+=1
 %PendingTab.text="Pending · %d" % pending
 %LibraryTab.text="Library · %d" % library
 %PublishedTab.text="Published · %d" % shared
 %PendingTab.set_pressed_no_signal(filter=="pending")
 %LibraryTab.set_pressed_no_signal(filter=="list")
 %PublishedTab.set_pressed_no_signal(filter=="shared")
 %Empty.visible=shown==0
 %Empty.text="No quizzes match your search." if %Search.text.strip_edges()!="" else {"pending":"All caught up. New student submissions will appear here.","list":"No quizzes in the library yet. Approve a student submission first.","shared":"No published quizzes yet. Open Library to publish an approved quiz."}.get(filter,"")
 %Scroll.visible=shown>0
 status_label.text="%d quizzes shown" % shown
func clear_items() -> void:
 for child in %Items.get_children():
  %Items.remove_child(child)
  child.queue_free()
func refresh() -> void:
 if busy:return
 if Nav.user.get("role","student")!="teacher":
  %Title.text="Join a quiz"
  %Notice.text="Enter your teacher's code or browse public quizzes."
  %Empty.visible=false
  status_label.text="Pending results: %d" % SharingService.state.outbox.size()
  return
 busy=true
 %Refresh.disabled=true
 status_label.text="Refreshing quizzes..."
 var reply: Dictionary=await SharingService.api("/reviews")
 busy=false
 if not is_inside_tree():return
 %Refresh.disabled=false
 if not reply.get("ok",false):
  status_label.text="Could not connect. Start the sharing server and refresh."
  return
 rows=reply.reviews
 render()
func add_review(row: Dictionary) -> void:
 var card := preload("res://scenes/ReviewerCard.tscn").instantiate()
 %Items.add_child(card)
 card.configure(row)
 card.action.connect(change)
 card.results_requested.connect(func(id: String) -> void: show_results(id,card))
func change(id: String, status: String) -> void:
 if status=="edit":
  var editor: Control = load("res://scenes/QuizEditor.tscn").instantiate()
  editor.review_id = id
  Nav.show_screen(editor)
  return
 if status=="visibility":
  var dialog: Control = preload("res://scenes/PublishReview.tscn").instantiate()
  dialog.review_id = id
  for row: Dictionary in rows:
   if row.id==id: dialog.initial_visibility = str(row.get("visibility","private")); dialog.initial_leaderboard = bool(row.get("leaderboard_enabled",false))
  dialog.saved.connect(refresh)
  add_child(dialog)
  return
 if busy: return
 busy = true
 var reply: Dictionary = await SharingService.api("/reviews/"+id+"/status",HTTPClient.METHOD_POST,{"status":status})
 busy = false
 if not is_inside_tree(): return
 if reply.get("ok",false): refresh()
 else: status_label.text = str(reply.get("error","Could not save."))
func join_quiz() -> void:
 if busy: return
 busy = true
 status_label.text = "Joining..."
 var reply: Dictionary = await SharingService.join_quiz(code_field.text)
 busy = false
 if not is_inside_tree(): return
 status_label.text = "Quiz saved! Open My Quizzes to play." if reply.get("ok",false) else str(reply.get("error","Could not join."))
 if reply.get("ok",false):
  clear_items()
  %OpenQuizzes.visible=true
func send_results() -> void:
 if busy: return
 busy = true
 var reply: Dictionary = await SharingService.send_pending()
 busy = false
 if is_inside_tree(): status_label.text = "All saved results sent." if reply.get("ok",false) else str(reply.get("error","Results remain saved for retry."))
func show_results(id: String, _card: VBoxContainer) -> void:
 var report: Control = load("res://scenes/TeacherResults.tscn").instantiate()
 report.review_id = id
 report.return_filter = filter
 Nav.show_screen(report)

func _apply_safe_area() -> void:
 if OS.get_name()!="Android":return
 var safe:=DisplayServer.get_display_safe_area()
 var dimensions:=Vector2(DisplayServer.window_get_size())
 if not safe.has_area() or dimensions.x<=0 or dimensions.y<=0:return
 var ratio:=size/dimensions
 $Margin.offset_left=36+maxf(0,safe.position.x)*ratio.x
 $Margin.offset_right=-36-maxf(0,dimensions.x-safe.end.x)*ratio.x
 $Margin.offset_top=20+maxf(0,safe.position.y)*ratio.y
 $Margin.offset_bottom=-20-maxf(0,dimensions.y-safe.end.y)*ratio.y
func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  Nav.show_screen(load("res://scenes/HomeScreen.tscn").instantiate())
func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
  Nav.show_screen(load("res://scenes/HomeScreen.tscn").instantiate())
