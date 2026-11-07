extends Control
signal replay
signal practise
signal quizzes
signal retry_report
func _ready() -> void:
 %Replay.pressed.connect(func() -> void: replay.emit())
 %Practise.pressed.connect(func() -> void: practise.emit())
 %RetryDelivery.pressed.connect(func() -> void: retry_report.emit())
 %Quizzes.pressed.connect(func() -> void: quizzes.emit())
func configure(correct: int,total: int,recalled: int,checks: int,remaining: int,available: int) -> void:
 %Summary.text = "First pass: %d/%d · %d%% accuracy" % [correct,total,int(round(100.0*correct/maxi(1,total))) ]
 %Recall.text = "Practice recall: %d/%d checks · %d still to review" % [recalled,checks,remaining]
 %Tip.text = "%d source-supported sentences available. Replay starts a new short round.\nThis is word-bank practice; battle scores and Stars are unchanged. Shared-quiz practice is reported separately to the teacher." % available
 %Practise.disabled = remaining==0
 %Title.text = "ROUND COMPLETE" if remaining>0 else "SPELLS COMPLETE!"
 if remaining>0: %Practise.grab_focus()
 else: %Replay.grab_focus()

func set_delivery(shared: bool, queued: bool) -> void:
 %Delivery.visible = shared
 %RetryDelivery.visible = shared and not queued
 %Delivery.text = "Report saved for delivery. If offline, use Shared quizzes → Send saved results." if queued else "Report could not be saved for delivery. Keep this round open and try again."
