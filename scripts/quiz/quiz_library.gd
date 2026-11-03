class_name QuizLibrary
extends RefCounted
## The student's shelf of quizzes: one JSON file per quiz plus a small index, so
## the list can be drawn without loading every question set.
##
## The battle still reads the single-quiz save through QuizData; `play()` hands a
## library quiz to it, which keeps one playable-quiz path instead of two.
##
## Every read and write goes through SaveManager, which keeps a .bak beside each
## file and repairs a damaged one from it.

const DIR := "user://quizzes"
const INDEX_PATH := "user://quizzes/index.json"


static func all() -> Array:
	var result := SaveManager.read_json(INDEX_PATH, "library")
	if not result["ok"]:
		return []

	var parsed: Variant = result["data"]
	var raw: Array = []
	if typeof(parsed) == TYPE_DICTIONARY:
		# v1 stores {"version", "quizzes"}; v0 was a bare array (migrated on read)
		var dict: Dictionary = parsed
		var maybe: Variant = dict.get("quizzes", [])
		if typeof(maybe) == TYPE_ARRAY:
			raw.assign(maybe)
	elif typeof(parsed) == TYPE_ARRAY:
		raw.assign(parsed)

	var out: Array = []
	for item in raw:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(item)
	# newest first, the order a student expects to see their work
	out.sort_custom(func(a, b) -> bool:
		return str(a.get("created_at", "")) > str(b.get("created_at", "")))
	return out


## Stores a quiz and returns its id, or "" if it could not be written.
##
## `dedupe_key` identifies the reviewer a set came from. Re-saving the same
## reviewer (same upload, same title run again) rewrites that entry instead of
## stacking a second copy of it on the shelf.
static func add(title: String, questions: Array, source := "generated", dedupe_key := "") -> String:
	_ensure_dir()

	var clean := _clean_questions(questions)
	var entries := all()

	var existing_at := -1
	var id := ""
	if dedupe_key != "":
		for i in entries.size():
			if str(entries[i].get("key", "")) == dedupe_key:
				existing_at = i
				id = str(entries[i].get("id", ""))
				break
	if id == "":
		id = _new_id()

	var now := Time.get_datetime_string_from_system()
	var created_at := now
	var code := ""
	if existing_at >= 0:
		created_at = str(entries[existing_at].get("created_at", now))
		code = str(entries[existing_at].get("code", ""))

	var record := {
		"version": int(SaveManager.VERSIONS["library_quiz"]),
		"title": title,
		"source": source,
		"key": dedupe_key,
		"created_at": created_at,
		"updated_at": now,
		"questions": clean,
	}
	if not SaveManager.write_json(_path_for(id), record, "library_quiz"):
		push_warning("could not write quiz %s" % _path_for(id))
		return ""

	var entry := {
		"id": id,
		"title": title,
		"count": clean.size(),
		"source": source,
		"key": dedupe_key,
		"created_at": created_at,
		"updated_at": now,
		"code": code,
	}
	if existing_at >= 0:
		entries[existing_at] = entry
	else:
		entries.append(entry)
	_write_index(entries)
	return id


static func get_quiz(id: String) -> Dictionary:
	var result := SaveManager.read_json(_path_for(id), "library_quiz")
	if not result["ok"]:
		return {}
	var parsed = result["data"]
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func remove(id: String) -> bool:
	var kept: Array = []
	for item in all():
		if str(item.get("id", "")) != id:
			kept.append(item)
	_write_index(kept)
	SaveManager.forget(_path_for(id))
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


static func _clean_questions(questions: Array) -> Array:
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
	return clean


static func _write_index(entries: Array) -> void:
	_ensure_dir()
	var data := {
		"version": int(SaveManager.VERSIONS["library"]),
		"quizzes": entries,
	}
	if not SaveManager.write_json(INDEX_PATH, data, "library"):
		push_warning("could not write the quiz index")


## Time-stamped so the sort is stable, with a short random tail so two quizzes
## saved in the same second don't collide.
static func _new_id() -> String:
	var chars := "abcdefghijkmnpqrstuvwxyz23456789"
	var tail := ""
	for i in 4:
		tail += chars.substr(randi() % chars.length(), 1)
	return "q%d%s" % [int(Time.get_unix_time_from_system()), tail]
