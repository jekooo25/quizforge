extends Control
@export var review_id:=""
const Entry:=preload("res://scenes/LeaderboardEntry.tscn")
var busy:=false
func _ready() -> void:
 resized.connect(_apply_safe_area)
 _apply_safe_area.call_deferred()
	%Back.pressed.connect(func()->void:Nav.call_deferred("show_screen",load("res://scenes/PublicQuizzes.tscn").instantiate()))
 %Refresh.pressed.connect(refresh)
 refresh()
func refresh() -> void:
 if busy:return
 busy=true
 %Status.text="Loading leaderboard..."
 var reply: Dictionary=await SharingService.api("/public/"+review_id+"/leaderboard")
 busy=false
 if not is_inside_tree():return
 for child in %Entries.get_children():%Entries.remove_child(child);child.queue_free()
 if not reply.get("ok",false):%Status.text=str(reply.get("error","Could not load."));return
 %QuizTitle.text="%s · v%d" % [reply.title,int(reply.review_version)]
 %Status.text="%d ranked students · equal results share a rank" % reply.entries.size() if not reply.entries.is_empty() else "No eligible completed Quiz Battle rounds yet."
 for row: Dictionary in reply.entries:
  var entry:=Entry.instantiate();%Entries.add_child(entry);entry.configure(row)

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

func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():Nav.show_screen(load("res://scenes/PublicQuizzes.tscn").instantiate())
