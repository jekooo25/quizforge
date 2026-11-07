extends Control
signal resume_requested
func _unhandled_key_input(event: InputEvent) -> void:
 if visible and event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  if %LeaveConfirmation.visible:
   %LeaveConfirmation.hide()
  else:
   resume_requested.emit()
