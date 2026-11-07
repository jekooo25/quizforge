extends Control
## Small, scene-based confirmation for a claimed Daily Tasks reward.

@onready var popup_panel: PanelContainer = %PopupPanel
@onready var reward_icon: Control = %RewardIcon
@onready var title_label: Label = %Title
@onready var reward_text: Label = %RewardText
@onready var ok_button: Button = %OKButton

var _stars_awarded := 0
var _new_balance := 0
var _notice_title := ""
var _notice_message := ""
var _closing := false


func configure(stars_awarded: int, new_balance: int) -> void:
	_stars_awarded = stars_awarded
	_new_balance = new_balance


func configure_notice(title: String, message: String) -> void:
	_notice_title = title
	_notice_message = message


func _ready() -> void:
	visible = true
	if _notice_title.is_empty():
		title_label.text = "REWARD CLAIMED!"
		reward_text.text = "You received %d Stars!  Balance: %d" % [
			_stars_awarded, _new_balance]
	else:
		title_label.text = _notice_title
		reward_text.text = _notice_message
	ok_button.pressed.connect(close)
	popup_panel.pivot_offset = popup_panel.size * 0.5
	popup_panel.scale = Vector2(0.72, 0.72)
	modulate = Color(1, 1, 1, 0)
	var entrance := create_tween()
	entrance.set_parallel(true)
	entrance.tween_property(self, "modulate", Color.WHITE, 0.18)
	entrance.tween_property(popup_panel, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var icon_bounce := create_tween()
	icon_bounce.tween_property(reward_icon, "scale", Vector2(1.22, 1.22), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	icon_bounce.tween_property(reward_icon, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_close_after_delay()


func _close_after_delay() -> void:
	await get_tree().create_timer(3.5).timeout
	close()


func close() -> void:
	if _closing or not is_inside_tree():
		return
	_closing = true
	var exit_tween := create_tween()
	exit_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.16)
	exit_tween.tween_callback(queue_free)
