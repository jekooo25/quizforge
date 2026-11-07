extends Control
const Spells := preload("res://scripts/quiz/spell_questions.gd")
@export var imported_quiz: Dictionary = {}
@export var library_id := ""
@export var review_id := ""
var questions: Array = []
var current := 0
var correct := -1
var loading := true
var dirty := false
var saved_id := ""
var busy := false
var edit_generation:=0
@onready var choices: Array[LineEdit] = [%ChoiceA,%ChoiceB,%ChoiceC,%ChoiceD]
@onready var marks: Array[CheckBox] = [%CorrectA,%CorrectB,%CorrectC,%CorrectD]
func _ready() -> void:
 resized.connect(_apply_safe_area)
 _apply_safe_area.call_deferred()
 %Back.pressed.connect(request_back)
 %Save.pressed.connect(save_draft)
 %Submit.pressed.connect(submit)
 %Previous.pressed.connect(move.bind(-1))
 %Next.pressed.connect(move.bind(1))
 %Add.pressed.connect(add_question)
 %Remove.pressed.connect(remove_question)
 %Preview.pressed.connect(preview)
 %Discard.confirmed.connect(leave)
 for field in [%QuizTitle,%Question,%Explanation,%Quote]: field.text_changed.connect(mark_dirty)
 %Page.value_changed.connect(mark_dirty)
 for field in choices: field.text_changed.connect(mark_dirty)
 for i in marks.size(): marks[i].pressed.connect(select_correct.bind(i))
 %Submit.visible = review_id=="" and Nav.user.get("role","student")=="student"
 var quiz: Dictionary
 if review_id!="":
  busy = true
  var reply: Dictionary = await SharingService.api("/reviews")
  busy = false
  if not reply.get("ok",false): %Status.text = str(reply.get("error","Could not load reviewer."));return
  for row: Dictionary in reply.reviews:
   if row.id==review_id:quiz=row
 else:quiz=imported_quiz if not imported_quiz.is_empty() else QuizLibrary.get_quiz(library_id)
 if quiz.is_empty(): %Status.text="Quiz could not be opened.";return
 %QuizTitle.text = str(quiz.get("title",""))
 questions = quiz.get("questions",[]).duplicate(true)
 if questions.is_empty(): %Status.text="This quiz has no questions.";return
 show_question()
 dirty = false
 %Status.text = "Edits save as a new private draft; existing versions and results stay intact."
func mark_dirty(_value: Variant = null) -> void:
 if not loading:
  dirty=true
  edit_generation+=1
func select_correct(index: int) -> void:
 correct=index
 for i in marks.size():marks[i].set_pressed_no_signal(i==index)
 mark_dirty()
func pull() -> void:
 if questions.is_empty():return
 questions[current]={"q":%Question.text.strip_edges(),"choices":choices.map(func(f: LineEdit)->String:return f.text.strip_edges()),"correct":correct,"explanation":%Explanation.text.strip_edges(),"source_quote":%Quote.text.strip_edges(),"page":int(%Page.value)}
func show_question() -> void:
 loading=true
 var question: Dictionary=questions[current]
 %Question.text=str(question.get("q",""))
 var bank: Array=question.get("choices",[])
 for i in 4:choices[i].text=str(bank[i]) if i<bank.size() else ""
 correct=int(question.get("correct",-1))
 for i in 4:marks[i].set_pressed_no_signal(i==correct)
 %Explanation.text=str(question.get("explanation",""))
 %Quote.text=str(question.get("source_quote",""))
 %Page.value=int(question.get("page",0))
 %Counter.text="Question %d / %d" % [current+1,questions.size()]
 %Previous.disabled=current==0
 %Next.disabled=current>=questions.size()-1
 loading=false
func move(delta: int) -> void:
 pull();current=clampi(current+delta,0,questions.size()-1);show_question()
func add_question() -> void:
 if busy:return
 pull();questions.append({"q":"","choices":["","","",""],"correct":-1});current=questions.size()-1;show_question();mark_dirty()
func remove_question() -> void:
 if busy:return
 if questions.size()<=1:%Status.text="Keep at least one question.";return
 questions.remove_at(current);current=mini(current,questions.size()-1);show_question();mark_dirty()
func validate() -> Array[String]:
 pull()
 var issues: Array[String]=QuizData.validate(questions)
 if %QuizTitle.text.strip_edges()=="":issues.append("Enter a quiz title.")
 for i in questions.size():
  var bank: Array=questions[i].get("choices",[])
  var seen: Dictionary={}
  for value: Variant in bank:seen[str(value).strip_edges().to_lower()]=true
  if seen.size()!=4:issues.append("Question %d needs four distinct choices." % (i+1))
 return issues
func preview() -> void:
 var issues:=validate()
 if not issues.is_empty():%Status.text="\n".join(issues);return
 var view: Control=load("res://scenes/QuizPreview.tscn").instantiate()
 view.question=questions[current].duplicate(true)
 view.battle_count=questions.size()
 view.spell_count=Spells.build(questions).size()
 add_child(view)
func save_draft() -> void:
 if busy:return
 var saved_generation:=edit_generation
 var issues:=validate()
 if not issues.is_empty():%Status.text="\n".join(issues);return
 if review_id!="":
  busy=true
  var reply: Dictionary=await SharingService.api("/reviews/"+review_id+"/draft",HTTPClient.METHOD_POST,{"title":%QuizTitle.text.strip_edges(),"questions":SharingService.questions_payload(questions)})
  busy=false
  if not is_inside_tree():return
  if not reply.get("ok",false):%Status.text=str(reply.get("error","Could not save."));return
  review_id=str(reply.review.id)
  %Status.text="Saved private revision v%d. Approve it in Pending Reviewers before publishing." % int(reply.review.review_version)
 else:
  var id:=QuizLibrary.create_draft(%QuizTitle.text,questions,library_id)
  if id=="":%Status.text="Could not save draft. Try again.";return
  library_id=id;saved_id=id
  %Status.text="Saved a new private draft. Submit it for teacher approval when ready."
 dirty=edit_generation!=saved_generation
 if dirty:%Status.text += " Unsaved edits remain."
func submit() -> void:
 if busy:return
 if dirty or saved_id=="":await save_draft()
 if dirty or saved_id=="":return
 busy=true
 var reply: Dictionary=await SharingService.submit_quiz(saved_id)
 busy=false
 if not is_inside_tree():return
 %Status.text=str(reply.get("message","This quiz was already submitted. No duplicate was created.")) if reply.get("duplicate",false) else "Submitted · "+str(reply.review.status)+" · teacher approval is required before publishing." if reply.get("ok",false) else str(reply.get("error","Could not submit."))
func request_back() -> void:
 if busy:return
 if dirty:%Discard.popup_centered()
 else:leave()
func leave() -> void:
 if review_id!="":
  var panel: Control=load("res://scenes/TeacherReviewers.tscn").instantiate();panel.filter="pending";Nav.call_deferred("show_screen",panel)
 else:Nav.call_deferred("show_screen",load("res://scenes/my_quizzes.tscn").instantiate())

func _apply_safe_area() -> void:
 if OS.get_name()!="Android":return
 var safe:=DisplayServer.get_display_safe_area()
 var dimensions:=Vector2(DisplayServer.window_get_size())
 if not safe.has_area() or dimensions.x<=0 or dimensions.y<=0:return
 var ratio:=size/dimensions
 var margin: MarginContainer=$Margin
 margin.offset_left=24+maxf(0,safe.position.x)*ratio.x
 margin.offset_right=-24-maxf(0,dimensions.x-safe.end.x)*ratio.x
 margin.offset_top=12+maxf(0,safe.position.y)*ratio.y
 margin.offset_bottom=-12-maxf(0,dimensions.y-safe.end.y)*ratio.y

func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  request_back()
func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():request_back()
