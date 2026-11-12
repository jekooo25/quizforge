extends Control
const ALLOWED:=["pdf","txt","md","csv","json","png","jpg","jpeg","webp","bmp","gif"]
const MAX_BYTES:=20*1024*1024
var _chosen_path:=""
var _continue: Button
var _range: LineEdit
var _file_label: Label
func _ready() -> void:
 if scene_file_path=="":
  Nav.show_screen.call_deferred(load("res://scenes/UploadReviewer.tscn").instantiate());return
 _continue=%Generate;_range=%Pages;_file_label=%File
 _continue.disabled=true
 %Count.get_line_edit().theme_type_variation=&"MyQuizzesSearch"
 %Count.get_line_edit().add_theme_font_size_override("font_size",26)
 %Heading.text="Create a quiz"
 %Mode.add_item("Quiz Battle · Multiple choice")
 %Mode.select(0)
 %Mode.item_selected.connect(update_mode)
 %Pick.pressed.connect(func()->void:%FileDialog.popup_centered_clamped(Vector2i(760,460),0.9))
 %FileDialog.file_selected.connect(_on_file_selected)
 %Generate.pressed.connect(_on_continue)
 %Back.pressed.connect(back)
 resized.connect(_safe_area)
 _safe_area.call_deferred()
 update_mode(%Mode.selected)
 _refresh_generate_state()

func _refresh_generate_state() -> void:
 _continue.disabled = _chosen_path.is_empty()
func update_mode(index: int) -> void:
 %ModeHint.text="Quiz Battle uses complete multiple-choice questions." if index==0 else "Word Bank uses source sentences with a missing answer. Only supported sentences are kept."
func _on_file_selected(path: String) -> void:
 _chosen_path="";_refresh_generate_state()
 %File.text=path.get_file()
 %FileInfo.text=""
 var extension:=path.get_extension().to_lower()
 %PdfOptions.visible=extension=="pdf"
 if extension not in ALLOWED:%Status.text="Unsupported file. Choose one of the formats listed above.";return
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:%Status.text="Could not open this file. Choose it again.";return
 var length:=file.get_length();file.close()
 if length==0:%Status.text="This file is empty. Choose a reviewer with study material.";return
 if length>MAX_BYTES:%Status.text="This file is over 20 MB. Choose a smaller file.";return
 _chosen_path=path
 %FileInfo.text="%s · %.1f KB" % [extension.to_upper(),length/1024.0]
 %Status.text="Ready to generate. You'll preview and edit before saving."
 _refresh_generate_state()
func _range_pair() -> Vector2i:
 var text := _range.text.strip_edges()
 if text == "":
  return Vector2i.ZERO
 var re := RegEx.new()
 var err := re.compile("(?i)^(?:pdf\\s+)?(?:pages?|pp?\\.?)?\\s*(\\d+)\\s*(?:(?:-|\\.\\.|to)\\s*(\\d+))?$")
 if err != OK:
  return Vector2i(-1, -1)
 var m := re.search(text)
 if m == null:
  return Vector2i(-1, -1)
 var low := int(m.get_string(1))
 var high := int(m.get_string(2)) if m.get_string(2) != "" else low
 if low < 1:
  return Vector2i(-1, -1)
 if high < low:
  var swap := low
  low = high
  high = swap
 return Vector2i(low, high)


func _on_continue() -> void:
 if _chosen_path=="":return
 var pair:=_range_pair() if _chosen_path.get_extension().to_lower()=="pdf" else Vector2i.ZERO
 if pair.x<0:%Status.text="Enter PDF pages like 4-10, or leave the field empty.";return
 Nav.user["reviewer_file"]=_chosen_path
 Nav.user["page_range"]="" if pair==Vector2i.ZERO else "%d-%d" % [pair.x,pair.y]
 Nav.user["generation_mode"]="battle"
 Nav.user["generation_count"]=int(%Count.value)
 Nav.show_screen(load("res://scenes/GenerateQuiz.tscn").instantiate())
func back() -> void:
 Nav.call_deferred("show_screen", load("res://scenes/HomeScreen.tscn").instantiate())
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
 if event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled();back()
