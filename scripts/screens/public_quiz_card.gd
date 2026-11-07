extends PanelContainer
signal join_requested(id: String)
signal leaderboard_requested(id: String)
var quiz_id := ""
func _ready() -> void:
 %Leaderboard.pressed.connect(func() -> void: leaderboard_requested.emit(quiz_id))
 %Join.pressed.connect(func() -> void: join_requested.emit(quiz_id))
func configure(quiz: Dictionary) -> void:
 quiz_id = str(quiz.id)
 %Title.text = "%s · v%d" % [quiz.title,int(quiz.get("review_version",1))]
 %Leaderboard.visible = bool(quiz.get("leaderboard_enabled",false))
 var count := int(quiz.count)
 %Details.text = "%s · %d %s · Public" % [quiz.author,count,"question" if count==1 else "questions"]
