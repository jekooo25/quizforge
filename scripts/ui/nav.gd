extends CanvasLayer
## Screen router. Holds the signed-up profile and swaps screens.

signal screen_changed(screen_name: String)

const SAVE_PATH := "user://quizforge_save.json"

var user := {
	"username": "",
	"first_name": "",
	"middle_initial": "",
	"last_name": "",
	"suffix": "",
	"student_id": "",
	"email": "",
	"school": "",
	"password": "",
}

var encounter_ready := false
var encounter_title := ""
var encounter_questions: Array = []

var _host: Control
var _current: Control


func _ready() -> void:
	layer = 0
	_host = Control.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_host)


func start() -> void:
	show_screen(preload("res://scripts/screens/title_screen.gd").new())


func show_screen(screen: Control) -> void:
	if _current != null and is_instance_valid(_current):
		if _current.get_parent() == _host:
			_host.remove_child(_current)
		_current.queue_free()
	_current = screen
	_host.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_changed.emit(screen.scene_file_path if screen.scene_file_path != "" else screen.get_script().resource_path)


# ------------------------------------------------------------------ profile

func display_name() -> String:
	var parts: Array[String] = []
	for key in ["first_name", "middle_initial", "last_name"]:
		var v: String = str(user.get(key, "")).strip_edges()
		if v != "":
			parts.append(v if key != "middle_initial" else v.substr(0, 1).to_upper() + ".")
	var suffix: String = str(user.get("suffix", "")).strip_edges()
	if suffix != "":
		parts.append(suffix)
	if parts.is_empty():
		return "Student"
	return " ".join(parts)


func save_profile() -> void:
	var data := {
		"user": user,
		"encounter_ready": encounter_ready,
		"encounter_title": encounter_title,
		"saved_at": Time.get_datetime_string_from_system(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("could not write save file")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
