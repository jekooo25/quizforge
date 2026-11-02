extends CanvasLayer
## Screen router. Holds the signed-up profile and swaps screens.

signal screen_changed(screen_name: String)

const SAVE_PATH := "user://quizforge_save.json"

## 2: the server address moved into a hidden developer menu, so an address a
## student typed under v1 is discarded on load instead of lingering in profiles.
const PROFILE_VERSION := 2

var user := {
	"username": "",
	"role": "student",
	"first_name": "",
	"middle_initial": "",
	"last_name": "",
	"suffix": "",
	"student_id": "",
	"email": "",
	"school": "",
	"password": "",
	"server_url": "",
}

var encounter_ready := false
var encounter_title := ""
var encounter_questions: Array = []

var _host: Control
var _current: Control


func _ready() -> void:
	load_profile()
	layer = 0
	_host = Control.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_host)


func load_profile() -> void:
	## Reads what save_profile() wrote, so a server address or a finished
	## account survives a restart. Missing or corrupt files are ignored.
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var saved = parsed.get("user", {})
	var saved_version := int(parsed.get("profile_version", 0))
	if typeof(saved) == TYPE_DICTIONARY:
		for key in saved:
			# never restore a password from disk, even an old save that had one
			if key != "password":
				user[key] = saved[key]
	user["profile_version"] = PROFILE_VERSION
	if saved_version < PROFILE_VERSION:
		# v1 let a student type a server address; that is not a preference worth
		# carrying forward, so the build default takes over from here on
		user["server_url"] = ""
	encounter_ready = bool(parsed.get("encounter_ready", false))
	encounter_title = str(parsed.get("encounter_title", ""))


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
	# The password stays in memory only; a profile file is not a safe place for it.
	var safe_user := user.duplicate()
	safe_user.erase("password")
	var data := {
		"profile_version": PROFILE_VERSION,
		"user": safe_user,
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
