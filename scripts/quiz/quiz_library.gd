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


## Records battle statistics in both the quiz file and the lightweight shelf index.
static func record_result(id: String, score: String, won: bool, played_at: String) -> bool:
    if id.is_empty():
        return false
    var quiz := get_quiz(id)
    if quiz.is_empty():
        return false
    var entries := all()
    var found := false
    for entry in entries:
        if str(entry.get("id", "")) == id:
            entry["last_score"] = score
            entry["won"] = won
            entry["last_played_at"] = played_at
            entry["play_count"] = int(entry.get("play_count", 0)) + 1
            found = true
            break
    if not found:
        return false
    var original_quiz := quiz.duplicate(true)
    quiz["last_score"] = score
    quiz["won"] = won
    quiz["last_played_at"] = played_at
    quiz["play_count"] = int(quiz.get("play_count", 0)) + 1
    if not SaveManager.write_json(_path_for(id), quiz, "library_quiz"):
        return false
    _ensure_dir()
    var index_data := {
        "version": int(SaveManager.VERSIONS["library"]),
        "quizzes": entries,
    }
    if not SaveManager.write_json(INDEX_PATH, index_data, "library"):
        SaveManager.write_json(_path_for(id), original_quiz, "library_quiz")
        return false
    return true


static func remove(id: String) -> bool:
    var kept: Array = []
    for item in all():
        if str(item.get("id", "")) != id:
            kept.append(item)
    _write_index(kept)
    SaveManager.forget(_path_for(id))
    return true


## --- THIS IS THE MISSING FUNCTION ---
static func rename(id: String, new_title: String) -> bool:
    var entries := all()
    var changed := false
    for item in entries:
        if str(item.get("id", "")) == id:
            item["title"] = new_title
            changed = true
            # Also update the individual quiz file
            var quiz := get_quiz(id)
            if not quiz.is_empty():
                quiz["title"] = new_title
                SaveManager.write_json(_path_for(id), quiz, "library_quiz")
            break

    if changed:
        _write_index(entries)
    return changed
## ------------------------------------


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
    return QuizData.save(str(quiz.get("title", "")), quiz.get("questions", []), id)


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
            "explanation": str(q.get("explanation", "")),
            "page": int(q.get("page", 0)),
            "source_quote": str(q.get("source_quote", "")),
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


## Save edits as an independent private copy; never overwrite published content or scores.
static func create_draft(title: String, questions: Array, parent_id: String) -> String:
 if not QuizData.validate(questions).is_empty() or title.strip_edges()=="": return ""
 var parent := get_quiz(parent_id)
 var id := add(title.strip_edges(),questions,"draft")
 if id=="": return ""
 var draft := get_quiz(id)
 draft["parent_library_id"] = parent_id
 var review_id := str(SharingService.state.get("submissions",{}).get(parent_id,parent.get("parent_review_id","")))
 var joined: Dictionary = SharingService.state.joins.get(parent_id,{})
 if review_id=="" and joined.get("author","")==Nav.user.get("username",""):
  review_id = str(joined.get("review_id",""))
 draft["parent_review_id"] = review_id
 if not SaveManager.write_json(_path_for(id),draft,"library_quiz"): return ""
 return id

## Old downloads are classified on read, so existing saves need no migration.
static func is_shared(entry: Dictionary) -> bool:
 return str(entry.get("source",""))=="received" or str(entry.get("key","")).begins_with("laptop-") or SharingService.state.joins.has(str(entry.get("id","")))
