extends Control
const Card := preload("res://scenes/TeacherResultCard.tscn")
@export var review_id := ""
@export var return_filter := "shared"
var reports: Array = []
var selected := "all"
var busy := false
func _ready() -> void:
 resized.connect(_apply_safe_area)
 _apply_safe_area.call_deferred()
 %Back.pressed.connect(back)
 %Refresh.pressed.connect(refresh)
 %AllFilter.pressed.connect(set_filter.bind("all"))
 %BattleFilter.pressed.connect(set_filter.bind("battle"))
 %SpellFilter.pressed.connect(set_filter.bind("word_bank"))
 refresh()
func refresh() -> void:
 if busy: return
 if Nav.user.get("role","student")!="teacher":
  %Status.text = "Choose the Teacher role to view student reports."
  %Refresh.disabled = true
  return
 if review_id=="":
  %Status.text = "Choose a reviewer, then select View student results."
  return
 busy = true
 %Refresh.disabled = true
 %Status.text = "Loading student reports..."
 var reply: Dictionary = await SharingService.api("/reviews/"+review_id+"/results")
 busy = false
 if not is_inside_tree(): return
 %Refresh.disabled = false
 if not reply.get("ok",false):
  %Status.text = str(reply.get("error","Could not load reports. Refresh to retry."))
  return
 reports = reply.get("results",[])
 %QuizTitle.text = "%s · v%d" % [reply.get("title","Reviewer results"),int(reply.get("review_version",1))]
 %Status.text = "%d completed rounds · first attempts and practice recall are separate" % reports.size()
 render()
func set_filter(value: String) -> void:
 selected = value
 render()
func render() -> void:
 for list: VBoxContainer in [%BattleList,%SpellList]:
  for child in list.get_children():
   list.remove_child(child)
   child.queue_free()
 var battle_count := 0
 var spell_count := 0
 for report: Dictionary in reports:
  var card := Card.instantiate()
  var spell: bool = report.get("review_mode","battle")=="word_bank"
  if spell:
   %SpellList.add_child(card)
   spell_count += 1
  else:
   %BattleList.add_child(card)
   battle_count += 1
  card.configure(report)
 %BattleHeading.text = "QUIZ BATTLE · %d reports" % battle_count
 %SpellHeading.text = "COMPLETE THE SPELL · %d reports" % spell_count
 %BattleSection.visible = selected in ["all","battle"] and battle_count>0
 %SpellSection.visible = selected in ["all","word_bank"] and spell_count>0
 %Empty.visible = (battle_count if selected=="battle" else spell_count if selected=="word_bank" else reports.size())==0
 %AllFilter.set_pressed_no_signal(selected=="all")
 %BattleFilter.set_pressed_no_signal(selected=="battle")
 %SpellFilter.set_pressed_no_signal(selected=="word_bank")
func back() -> void:
 var panel: Control = load("res://scenes/TeacherReviewers.tscn").instantiate()
 panel.filter = return_filter
 Nav.show_screen(panel)
func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  back()
func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready(): back()

func _apply_safe_area() -> void:
 if OS.get_name()!="Android": return
 var safe := DisplayServer.get_display_safe_area()
 var dimensions := Vector2(DisplayServer.window_get_size())
 if not safe.has_area() or dimensions.x<=0 or dimensions.y<=0: return
 var ratio := size/dimensions
 var margin: MarginContainer = $Margin
 margin.offset_left = 24+maxf(0,safe.position.x)*ratio.x
 margin.offset_right = -24-maxf(0,dimensions.x-safe.end.x)*ratio.x
 margin.offset_top = 12+maxf(0,safe.position.y)*ratio.y
 margin.offset_bottom = -12-maxf(0,dimensions.y-safe.end.y)*ratio.y
