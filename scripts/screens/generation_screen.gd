extends Control
const Spells:=preload("res://scripts/quiz/spell_questions.gd")
var _client: QuizClient
var _payload: Dictionary={}
var _failure:=""
var _finished:=false
var _using_sample:=false
var elapsed:=0.0
var busy:=false
func _ready() -> void:
 if scene_file_path=="":Nav.show_screen.call_deferred(load("res://scenes/GenerateQuiz.tscn").instantiate());return
 %Back.pressed.connect(choose_file)
 %Choose.pressed.connect(choose_file)
 %Retry.pressed.connect(_start_generation)
 %Preview.pressed.connect(_review_questions)
 resized.connect(_safe_area)
 _safe_area.call_deferred()
 _client=QuizClient.new();add_child(_client)
 _client.generated.connect(_on_generated)
 _client.failed.connect(_fail)
 _start_generation()
func _process(delta: float) -> void:
 if busy:
  elapsed+=delta
  %Elapsed.text="Time elapsed: %d seconds" % int(elapsed)
  var displayed_progress:=minf(90.0,8.0+elapsed*9.0)
  %Progress.value=displayed_progress
  %ProgressPercent.text="%d%%" % int(displayed_progress)
  %StageLabel.text="Writing questions" if elapsed<6.0 else "Checking questions"
func _start_generation() -> void:
 if busy:return
 _finished=false;_payload={};_failure="";elapsed=0
 %File.text=str(Nav.user.get("reviewer_file","")).get_file()
 %Mode.text="Word Bank · source-supported sentences" if Nav.user.get("generation_mode","battle")=="word_bank" else "Quiz Battle · multiple-choice questions"
 %Retry.hide();%Choose.hide();%Preview.hide();%Progress.indeterminate=false;%Progress.value=5
 %ProgressPercent.text="5%";%StageLabel.text="Writing questions"
 %Status.text="●  GENERATING"
 %Heading.text="Your Encounter is Ready"
 %Summary.text="Questions are checked and saved for offline play"
 var path:=str(Nav.user.get("reviewer_file",""))
 if path=="" or not FileAccess.file_exists(path):_fail("The selected file is missing. Choose it again.");return
 busy=true
 _client.generate_file(path,int(Nav.user.get("generation_count",10)),str(Nav.user.get("page_range","")),Time.get_ticks_msec())
func _on_generated(data: Dictionary) -> void:
 if not is_inside_tree():return
 var questions:=QuizData.from_server(data)
 var issues:=QuizData.validate(questions)
 if not issues.is_empty():_fail("Some generated questions are incomplete. Try again or choose different material.");return
 if Nav.user.get("generation_mode","battle")=="word_bank" and Spells.build(questions).is_empty():
  _fail("This material did not produce suitable Word Bank sentences. Choose clearer definitions, or switch to Quiz Battle.");return
 if Nav.user.get("generation_mode","battle")=="word_bank":
  var supported: Array=[]
  for card: Dictionary in Spells.build(questions):supported.append(questions[int(card.source_index)])
  questions=supported
 _payload=data.duplicate(true);_payload["questions"]=questions
 busy=false;_finished=true
 %Progress.indeterminate=false;%Progress.value=100
 %ProgressPercent.text="100%";%StageLabel.text="Questions ready to review"
 %Status.text="●  READY"
 %Heading.text="Your quiz is ready"
 var provider: String=str(data.get("source",{}).get("provider",""))
 var count:=int(Nav.user.get("generation_count",10))
 %Summary.text="Created %d of %d requested questions. Review the wording, correct answers and source before saving." % [questions.size(),count]
 if questions.size()<count:%Summary.text+=" Fewer questions were kept to avoid weak or repeated questions."
 if provider=="offline":%Summary.text+=" Created from the source text on this laptop."
 %Preview.disabled=false;%Preview.show();%Choose.show()
func _fail(message: String) -> void:
 if not is_inside_tree():return
 busy=false;_finished=true;_failure=message;_payload={}
 %Progress.indeterminate=false;%Progress.value=0
 %ProgressPercent.text="0%";%StageLabel.text="Generation stopped"
 %Status.text="●  TRY AGAIN"
 %Heading.text="Could not generate this quiz"
 %Summary.text=message
 %Preview.disabled=true;%Retry.show();%Choose.show()
func _review_questions() -> void:
 if busy or _payload.is_empty():return
 var preview: Control=load("res://scenes/GeneratedQuizPreview.tscn").instantiate()
 preview.imported_quiz=_payload.duplicate(true)
 preview.pages=_payload.get("pages",[])
 preview.review_mode=str(Nav.user.get("generation_mode","battle"))
 Nav.show_screen(preview)
func choose_file() -> void:
 Nav.show_screen(load("res://scenes/UploadReviewer.tscn").instantiate())
func _safe_area() -> void:
 if OS.get_name()!="Android":return
 var safe:=DisplayServer.get_display_safe_area();var window:=Vector2(DisplayServer.window_get_size())
 if not safe.has_area() or window.x<=0 or window.y<=0:return
 var ratio:=size/window
 $Margin.offset_left=32+maxf(0,safe.position.x)*ratio.x
 $Margin.offset_right=-32-maxf(0,window.x-safe.end.x)*ratio.x
 $Margin.offset_top=16+maxf(0,safe.position.y)*ratio.y
 $Margin.offset_bottom=-16-maxf(0,window.y-safe.end.y)*ratio.y
func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled();choose_file()
