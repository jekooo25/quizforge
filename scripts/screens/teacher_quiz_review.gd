extends Control
signal action(id: String,value: String)
var data: Dictionary={}
var current:=0
func _ready() -> void:
 resized.connect(_apply_safe_area)
 _apply_safe_area.call_deferred()
 if OS.get_name()=="Android":get_tree().quit_on_go_back=false
 %Back.pressed.connect(queue_free)
 %Previous.pressed.connect(move.bind(-1))
 %Next.pressed.connect(move.bind(1))
 %Approve.pressed.connect(send.bind("approved"))
 %Changes.pressed.connect(send.bind("changes"))
 %Edit.pressed.connect(send.bind("edit"))
 %Publish.pressed.connect(send.bind("visibility"))
 %Approve.visible=data.get("status","")=="pending"
 %Changes.visible=%Approve.visible
 %Publish.visible=data.get("status","") in ["approved","shared"]
 %Title.text=str(data.get("title","Review quiz"))
 show_question()
func send(value: String) -> void:
 action.emit(str(data.id),value)
 queue_free()
func move(delta: int) -> void:
 current=clampi(current+delta,0,data.questions.size()-1)
 show_question()
func show_question() -> void:
 if data.get("questions",[]).is_empty():return
 var question: Dictionary=data.questions[current]
 %Counter.text="%d / %d" % [current+1,data.questions.size()]
 %Question.text=str(question.q)
 var fields: Array[Label]=[%ChoiceA,%ChoiceB,%ChoiceC,%ChoiceD]
 for i in 4:
  fields[i].text="%s. %s%s" % [char(65+i),str(question.choices[i]),"  · Correct answer" if i==int(question.correct) else ""]
  fields[i].modulate=Color(0.45,0.88,0.73) if i==int(question.correct) else Color.WHITE
 %Explanation.text="Explanation: "+str(question.get("explanation","No explanation provided."))
 %Source.text="Source · page %d: %s" % [int(question.get("page",0)),str(question.get("source_quote",""))]
 %Source.visible=str(question.get("source_quote","")).strip_edges()!=""
 %Previous.disabled=current==0
 %Next.disabled=current==data.questions.size()-1
func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  queue_free()
func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_GO_BACK_REQUEST:queue_free()

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
