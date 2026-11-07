extends Control
const Card := preload("res://scenes/PublicQuizCard.tscn")
var busy := false
func _ready() -> void:
 resized.connect(_apply_safe_area)
 _apply_safe_area.call_deferred()
 %Nickname.text = str(Nav.user.get("leaderboard_nickname",""))
 %Nickname.text_changed.connect(func(value: String) -> void: Nav.user["leaderboard_nickname"] = value)
 %Back.pressed.connect(back)
 %Refresh.pressed.connect(refresh)
 refresh()
func refresh() -> void:
 if busy: return
 busy = true
 %Refresh.disabled = true
 %Status.text = "Loading approved public quizzes..."
 var reply: Dictionary = await SharingService.api("/public")
 busy = false
 if not is_inside_tree(): return
 %Refresh.disabled = false
 for child in %Items.get_children():
  %Items.remove_child(child)
  child.queue_free()
 if not reply.get("ok",false):
  %Status.text = str(reply.get("error","Could not load public quizzes."))
  return
 var quizzes: Array = reply.get("quizzes",[])
 %Status.text = "%d public %s available" % [quizzes.size(),"quiz" if quizzes.size()==1 else "quizzes"] if not quizzes.is_empty() else "No public quizzes yet. Teachers can publish an approved reviewer as Public."
 for quiz: Dictionary in quizzes:
  var card := Card.instantiate()
  %Items.add_child(card)
  card.configure(quiz)
  card.join_requested.connect(join_quiz)
  card.leaderboard_requested.connect(open_leaderboard)
func join_quiz(id: String) -> void:
 if busy: return
 busy = true
 %Status.text = "Adding this public quiz..."
 var reply: Dictionary = await SharingService.join_public(id)
 busy = false
 if not is_inside_tree(): return
 if not reply.get("ok",false):
  %Status.text = str(reply.get("error","Could not join. Refresh and retry."))
  return
 var picker: Control = load("res://scenes/ReviewModeSelect.tscn").instantiate()
 picker.library_id = str(reply.library_id)
 Nav.show_screen(picker)
func back() -> void:
 Nav.show_screen(load("res://scenes/SharedQuizzes.tscn").instantiate())
func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  back()

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

func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready(): back()

func open_leaderboard(id: String) -> void:
 var view: Control = load("res://scenes/PublicLeaderboard.tscn").instantiate()
 view.review_id = id
 Nav.show_screen(view)
