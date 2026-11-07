extends "res://scripts/screens/menu_screen.gd"
var busy:=false
func _ready() -> void:
 if OS.get_name()=="Android":get_tree().quit_on_go_back=false
 _content=%Margin
 %Greeting.text=str(Nav.user.get("username","")).strip_edges()
 %Pending.pressed.connect(open_panel.bind("pending"))
 %Library.pressed.connect(open_panel.bind("list"))
 %Published.pressed.connect(open_panel.bind("shared"))
 %Refresh.pressed.connect(refresh)
 %Settings.pressed.connect(_open_teacher_settings)
 %Profile.pressed.connect(_on_profile)
 %CoursePanel.add_theme_stylebox_override("panel", UITheme.box(Color(0.05,0.12,0.2,0.96), Color(0.2,0.45,0.7,1.0), 2, 12))
 resized.connect(_apply_safe_area)
 _apply_safe_area()
 refresh()
 refresh_courses()

func refresh_courses() -> void:
 var reply: Dictionary=await SharingService.api("/courses")
 if not is_inside_tree():return
 for child: Node in %CourseList.get_children():
  %CourseList.remove_child(child)
  child.queue_free()
 if not reply.get("ok",false):
  %CourseList.add_child(UITheme.sans("Courses unavailable right now",20,UITheme.CREAM))
  return
 var courses: Array=reply.get("courses",[])
 for course_value: Variant in courses:
  var course: Dictionary=course_value as Dictionary
  var label: Label=UITheme.sans("%s · %s" % [str(course.get("code","")),str(course.get("title","Course"))],20,UITheme.CREAM)
  %CourseList.add_child(label)
func refresh() -> void:
 if busy:return
 busy=true
 %Refresh.disabled=true
 %Connection.text=""
 var reply: Dictionary=await SharingService.api("/reviews")
 busy=false
 if not is_inside_tree():return
 %Refresh.disabled=false
 if not reply.get("ok",false):
  %Connection.text="Courses and quizzes are temporarily unavailable."
  for field in [%PendingCount,%LibraryCount,%PublishedCount]:field.text="—"
  return
 var pending:=0
 var library:=0
 var shared:=0
 for row: Dictionary in reply.reviews:
  if row.status=="pending" and row.get("duplicate_of","")!="":continue
  if row.status=="pending":pending+=1
  else:library+=1
  if row.status=="shared":shared+=1
 %PendingCount.text=str(pending)+" pending"
 %LibraryCount.text=str(library)+" in library"
 %PublishedCount.text=str(shared)+" published"
 %Connection.text=""

func _open_teacher_settings() -> void:
 Nav.show_screen(load("res://scripts/screens/settings_screen.gd").new())
func open_panel(value: String) -> void:
 var panel: Control=load("res://scenes/TeacherReviewers.tscn").instantiate()
 panel.filter=value
 Nav.show_screen(panel)
