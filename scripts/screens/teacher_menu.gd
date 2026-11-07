extends "res://scripts/screens/menu_screen.gd"
var busy:=false
func _ready() -> void:
 if OS.get_name()=="Android":get_tree().quit_on_go_back=false
 _make_mobile_scroll()
 _content=%Margin
 var teacher_name: String=str(Nav.user.get("username","")).strip_edges()
 %Greeting.text=teacher_name if teacher_name!="" else "Teacher dashboard"
 %CoursePanel.add_theme_stylebox_override("panel", UITheme.box(Color(0.05,0.12,0.2,0.96), Color(0.2,0.45,0.7,1.0), 2, 12))
 resized.connect(_apply_safe_area)
 _apply_safe_area()
 refresh()
 refresh_courses()

func _make_mobile_scroll() -> void:
 var margin: MarginContainer = get_node("Margin")
 var column: VBoxContainer = get_node("Margin/Column")
 var scroll: ScrollContainer = ScrollContainer.new()
 scroll.name = "MobileScroll"
 scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 margin.remove_child(column)
 margin.add_child(scroll)
 scroll.add_child(column)
 column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func refresh_courses() -> void:
 var reply: Dictionary=await SharingService.api("/courses")
 if not is_inside_tree():return
 for child: Node in %CourseList.get_children():
  %CourseList.remove_child(child)
  child.queue_free()
 if not reply.get("ok",false):
  _show_seeded_courses()
  return
 var courses: Array=reply.get("courses",[])
 if courses.is_empty():
  _show_seeded_courses()
  return
 _add_course_buttons(courses)

func _show_seeded_courses() -> void:
 var courses: Array=[{"id":"BIO101","code":"BIO101","title":"Biology 101"},{"id":"HIST201","code":"HIST201","title":"World History"},{"id":"MATH120","code":"MATH120","title":"College Algebra"},{"id":"CHEM110","code":"CHEM110","title":"General Chemistry"},{"id":"PHYS130","code":"PHYS130","title":"Physics I"},{"id":"ENG105","code":"ENG105","title":"Academic Writing"},{"id":"CS115","code":"CS115","title":"Programming Fundamentals"},{"id":"PSY101","code":"PSY101","title":"Introduction to Psychology"}]
 _add_course_buttons(courses)

func _add_course_buttons(courses: Array) -> void:
 for course_value: Variant in courses:
  var course: Dictionary=course_value as Dictionary
  var button: Button=Button.new()
  button.text="%s · %s" % [str(course.get("code","")),str(course.get("title","Course"))]
  button.custom_minimum_size=Vector2(0,48)
  button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  button.pressed.connect(open_panel.bind("list"))
  %CourseList.add_child(button)
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

func _on_pending_pressed() -> void:
 open_panel("pending")

func _on_library_pressed() -> void:
 open_panel("list")

func _on_published_pressed() -> void:
 open_panel("shared")
func open_panel(value: String) -> void:
 var panel: Control=load("res://scenes/TeacherReviewers.tscn").instantiate()
 panel.filter=value
 Nav.call_deferred("show_screen", panel)
