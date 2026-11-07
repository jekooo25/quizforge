extends Control
signal saved
@export var review_id := ""
@export var initial_visibility := "private"
@export var initial_leaderboard := false
var selected := "private"
func _ready() -> void:
 resized.connect(_apply_safe_area)
 _apply_safe_area.call_deferred()
 %Private.pressed.connect(select.bind("private"))
 %CodeOnly.pressed.connect(select.bind("code_only"))
 %Public.pressed.connect(select.bind("public"))
 %Cancel.pressed.connect(queue_free)
 %Apply.pressed.connect(apply)
 %Leaderboard.button_pressed = initial_leaderboard
 select(initial_visibility)
func select(value: String) -> void:
 %Leaderboard.disabled = value!="public"
 selected = value if value in ["private","code_only","public"] else "private"
 %Private.set_pressed_no_signal(selected=="private")
 %CodeOnly.set_pressed_no_signal(selected=="code_only")
 %Public.set_pressed_no_signal(selected=="public")
 %Explanation.text = {"private":"Private draft: no new joins and no public listing.","code_only":"Code-only: students need your code. Hidden from the public browser.","public":"Public: discoverable by student sessions connected to this laptop server."}[selected]
func apply() -> void:
 %Apply.disabled = true
 %Cancel.disabled = true
 var reply: Dictionary = await SharingService.api("/reviews/"+review_id+"/publish",HTTPClient.METHOD_POST,{"visibility":selected,"leaderboard_enabled":%Leaderboard.button_pressed})
 if not is_inside_tree(): return
 if reply.get("ok",false):
  saved.emit()
  queue_free()
 else:
  %Explanation.text = str(reply.get("error","Could not save visibility."))
  %Apply.disabled = false
  %Cancel.disabled = false

func _apply_safe_area() -> void:
 if OS.get_name()!="Android": return
 var safe := DisplayServer.get_display_safe_area()
 var dimensions := Vector2(DisplayServer.window_get_size())
 if not safe.has_area() or dimensions.x<=0 or dimensions.y<=0: return
 var ratio := size/dimensions
 var margin: MarginContainer = $Margin
 margin.offset_left = 40+maxf(0,safe.position.x)*ratio.x
 margin.offset_right = -40-maxf(0,dimensions.x-safe.end.x)*ratio.x
 margin.offset_top = 24+maxf(0,safe.position.y)*ratio.y
 margin.offset_bottom = -24-maxf(0,dimensions.y-safe.end.y)*ratio.y
