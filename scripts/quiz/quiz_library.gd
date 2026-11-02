class_name QuizLibrary
extends RefCounted
## The student's shelf of quizzes: one JSON file per quiz plus a small index, so
## the list can be drawn without loading every question set.
##
## The battle still reads the single-quiz save through QuizData; `play()` hands a
## library quiz to it, which keeps one playable-quiz path instead of two.

const DIR := "user://quizzes"
const INDEX_PATH := "user://quizzes/index.json"


static func all() -> Array:
	if not FileAccess.file_exists(INDEX_PATH):
		return []
	var f := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_ARRAY:
		return []

	var out: Array = []
	for item in parsed:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(item)
	# newest first, the order a student expects to see their work
	out.sort_custom(func(a, b) -> bool:
		return str(a.get("created_at", "")) > str(b.get("created_at", "")))
	return out


## Stores a quiz and returns its id, or "" if it could not be written.
static func add(title: String, questions: Array, source := "generated") -> String:
	_ensure_dir()

	var clean: Array = []
	for q in questions:
		var choices: Array = []
		for c in q.get("choices", []):
			choices.append(str(c).strip_edges())
		clean.append({
			"q": str(q.get("q", "")).strip_edges(),
			"choices": choices,
			"correct": int(q.get("correct", -1)),
		})

	var id := _new_id()
	var record := {
		"version": 1,
		"title": title,
		"source": source,
		"created_at": Time.get_datetime_string_from_system(),
		"questions": clean,
	}
	var f := FileAccess.open(_path_for(id), FileAccess.WRITE)
	if f == null:
		push_warning("could not write quiz %s" % _path_for(id))
		return ""
	f.store_string(JSON.stringify(record, "\t"))
	f.close()

	var entries := all()
	entries.append({
		"id": id,
		"title": title,
		"count": clean.size(),
		"source": source,
		"created_at": record["created_at"],
		"code": "",
	})
	_write_index(entries)
	return id


static func get_quiz(id: String) -> Dictionary:
	if not FileAccess.file_exists(_path_for(id)):
		return {}
	var f := FileAccess.open(_path_for(id), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func remove(id: String) -> bool:
	var kept: Array = []
	for item in all():
		if str(item.get("id", "")) != id:
			kept.append(item)
	_write_index(kept)

	var path := _path_for(id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return true


static func set_code(id: String, code: String) -> void:
	var entries := all()
	for item in entries:
		if str(item.get("id", "")) == id:
			item["code"] = code
	_write_index(entries)


## Makes a library quiz the one the battle plays.
static func play(id: String) -> bool:
	var quiz := get_quiz(id)
	if quiz.is_empty():
		return false
	return QuizData.save(str(quiz.get("title", "")), quiz.get("questions", []))


static func count() -> int:
	return all().size()


# ------------------------------------------------------------------ internals

static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)


static func _path_for(id: String) -> String:
	return "%s/%s.json" % [DIR, id]


static func _write_index(entries: Array) -> void:
	_ensure_dir()
	var f := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("could not write the quiz index")
		return
	f.store_string(JSON.stringify(entries, "\t"))
	f.close()


## Time-stamped so the sort is stable, with a short random tail so two quizzes
## saved in the same second don't collide.
static func _new_id() -> String:
	var chars := "abcdefghijkmnpqrstuvwxyz23456789"
	var tail := ""
	for i in 4:
		tail += chars.substr(randi() % chars.length(), 1)
	return "q%d%s" % [int(Time.get_unix_time_from_system()), tail]
