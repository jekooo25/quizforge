class_name BoardDialog
extends Control
## A confirmation drawn on the bulletin board, matching the design's dialogs.

signal confirmed
signal cancelled

var _message: String = ""
var _ok_text: String = "OK"
var _cancel_text: String = "Cancel"


static func ask(message: String, ok_text := "OK", cancel_text := "Cancel") -> BoardDialog:
	var d := BoardDialog.new()
	d._message = message
	d._ok_text = ok_text
	d._cancel_text = cancel_text
	return d


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scrim := ColorRect.new()
	scrim.color = Color(0.05, 0.06, 0.08, 0.45)
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var board := BoardCard.new()
	board.custom_minimum_size = Vector2(600, 300)
	center.add_child(board)

	var text := UITheme.sans(_message, 19, UITheme.INK)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(420, 90)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board.content.add_child(text)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	board.content.add_child(spacer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 60)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	board.content.add_child(row)

	var ok := UITheme.script_button(_ok_text, 24)
	ok.pressed.connect(func() -> void:
		confirmed.emit()
		queue_free())
	row.add_child(ok)

	var cancel := UITheme.script_button(_cancel_text, 24)
	cancel.pressed.connect(func() -> void:
		cancelled.emit()
		queue_free())
	row.add_child(cancel)
