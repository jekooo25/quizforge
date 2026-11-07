extends VBoxContainer
signal action(id: String,status: String)
signal results_requested(id: String)
var data: Dictionary={}
func _ready() -> void:
 %Read.pressed.connect(read)
 %More.pressed.connect(func()->void:%Tools.visible=not %Tools.visible)
 %Copy.pressed.connect(func()->void:DisplayServer.clipboard_set(str(data.get("code","")));%Copy.text="Copied")
 %Edit.pressed.connect(func()->void:action.emit(data.id,"edit"))
 %Changes.pressed.connect(func()->void:action.emit(data.id,"changes"))
 %Publish.pressed.connect(func()->void:action.emit(data.id,"visibility"))
 %Close.pressed.connect(func()->void:action.emit(data.id,"approved"))
 %Results.pressed.connect(func()->void:results_requested.emit(data.id))
func configure(row: Dictionary) -> void:
 data=row
 var visibility:=str(row.get("visibility","private"))
 %Title.text=str(row.title)
 %Meta.text="%s · %d questions · v%d" % [row.author,row.questions.size(),int(row.get("review_version",1))]
 %Course.text="Course: %s%s" % [str(row.get("course_title","Unassigned")), (" ("+str(row.get("course_code",""))+")") if str(row.get("course_code",""))!="" else ""]
 %Status.text={"pending":"Needs approval","approved":"Ready to publish","changes":"Changes requested","shared":"Published"}.get(row.status,str(row.status).capitalize())
 if row.status=="shared":%Status.text+=" · "+("Public" if visibility=="public" else "Code-only")
 %ShareRow.visible=row.status=="shared" and visibility!="private"
 %Code.text="Join code: "+str(row.get("code",""))
 %Approve.visible=false
 %Changes.visible=row.status=="pending"
 %Publish.visible=row.status in ["approved","shared"]
 %Publish.text="Publish quiz" if row.status=="approved" else "Visibility"
 %Close.visible=row.status=="shared"
 %Results.visible=row.get("code")!=null
 %Read.text="Review quiz" if row.status=="pending" else "View questions"
func read() -> void:
 var view: Control=load("res://scenes/TeacherQuizReview.tscn").instantiate()
 view.data=data
 view.action.connect(func(id: String,value: String)->void:action.emit(id,value))
 Nav._current.add_child(view)
