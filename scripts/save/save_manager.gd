extends Node
## One gate for every JSON file the game writes under user://.
##
## A student's tablet can lose power mid-write. Writing straight at the real file
## leaves half a JSON document behind, and the old code then quietly played
## something else. So every write lands in a temp file and is renamed over the
## target, and the previous readable file is kept as a single .bak. On read, a
## damaged main file falls back to that backup and is repaired from it.
##
## Callers get a result dictionary, never an exception:
##     {"ok", "data", "status", "kind", "version", "migrated", "error"}
##
## status is one of STATUS_OK / STATUS_MISSING / STATUS_RECOVERED / STATUS_CORRUPT.
## (The constants are prefixed because bare OK is Godot's Error.OK.)

const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"

## Bump a kind's number when its stored shape changes, then add a branch to
## _migrate(). Loading runs the migration before handing data back.
const VERSIONS := {
	"profile": 2,
	"quiz": 2,
	"library": 1,
	"library_quiz": 2,
}

const STATUS_OK := "ok"
const STATUS_MISSING := "missing"
const STATUS_RECOVERED := "recovered"
const STATUS_CORRUPT := "corrupt"


# ------------------------------------------------------------------ writing

## Writes `data` to `path` atomically and returns false only if it could not.
func write_json(path: String, data: Variant, kind := "") -> bool:
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var tmp_path := path + TEMP_SUFFIX
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: cannot open %s for writing (%s)" % [
			tmp_path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	f.close()

	# Only shadow a file we can still read, so one damaged write can't destroy
	# the last good copy.
	if FileAccess.file_exists(path) and _is_readable(path):
		DirAccess.copy_absolute(path, path + BACKUP_SUFFIX)

	var err: Error = DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		# Some platforms refuse to rename onto an existing file; drop and retry.
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		err = DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_warning("SaveManager: cannot replace %s (%s)" % [path, error_string(err)])
		return false
	return true


# ------------------------------------------------------------------ reading

## Reads `path`, falling back to its .bak. Never crashes on bad JSON.
func read_json(path: String, kind := "") -> Dictionary:
	var main := _parse_file(path)
	if main["ok"]:
		return _accept(path, kind, main["data"], STATUS_OK)

	var main_exists := FileAccess.file_exists(path)
	var backup := _parse_file(path + BACKUP_SUFFIX)
	if backup["ok"]:
		_repair(path)
		if main_exists:
			push_warning("SaveManager: %s was damaged, restored it from the backup" % path)
		return _accept(path, kind, backup["data"], STATUS_RECOVERED)

	if main_exists:
		push_warning("SaveManager: %s and %s are both unreadable" % [
			path, path + BACKUP_SUFFIX])
		return _failure(STATUS_CORRUPT, kind, "unreadable")
	return _failure(STATUS_MISSING, kind, "missing")


## Removes a file and the copies SaveManager keeps beside it.
func forget(path: String) -> void:
	for p in [path, path + BACKUP_SUFFIX, path + TEMP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func has_backup(path: String) -> bool:
	return FileAccess.file_exists(path + BACKUP_SUFFIX)


# ---------------------------------------------------------------- internals

func _parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": null}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "data": null}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return {"ok": false, "data": null}
	return {"ok": true, "data": parsed}


func _is_readable(path: String) -> bool:
	return bool(_parse_file(path)["ok"])


## Copies the backup back over the main file so the next run starts clean.
func _repair(path: String) -> void:
	var backup := path + BACKUP_SUFFIX
	if not FileAccess.file_exists(backup):
		return
	DirAccess.copy_absolute(backup, path)


func _failure(status: String, kind: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"data": null,
		"status": status,
		"kind": kind,
		"version": 0,
		"from_version": 0,
		"migrated": false,
		"error": message,
	}


func _accept(path: String, kind: String, data: Variant, status: String) -> Dictionary:
	var from_version := _version_of(data)
	var target := _target_version(kind)
	var migrated := from_version < target
	var out: Variant = data if not migrated else _migrate(kind, data, from_version)

	if migrated:
		# Persist the upgraded shape so the migration runs once, not every load.
		if not write_json(path, out, kind):
			push_warning("SaveManager: could not rewrite %s after migrating" % path)

	return {
		"ok": true,
		"data": out,
		"status": status,
		"kind": kind,
		"version": _version_of(out),
		"from_version": from_version,
		"migrated": migrated,
		"error": "",
	}


func _target_version(kind: String) -> int:
	return int(VERSIONS.get(kind, 1))


func _version_of(data: Variant) -> int:
	if typeof(data) == TYPE_DICTIONARY:
		var dict: Dictionary = data
		if dict.has("version"):
			return int(dict["version"])
		if dict.has("profile_version"):
			return int(dict["profile_version"])
	# An unversioned shape is version 0.
	return 0


## Brings an older stored shape up to VERSIONS[kind].
##
## Today the only real case is the library index, which used to be a bare array.
## The point of the hook is that the next shape change has somewhere to live.
func _migrate(kind: String, data: Variant, from_version: int) -> Variant:
	var target := _target_version(kind)
	print("[save] %s: migrating v%d -> v%d" % [kind, from_version, target])

	if kind == "library" and typeof(data) == TYPE_ARRAY:
		# v0 was a bare array of entries.
		return {"version": target, "quizzes": data}

	_stamp(kind, data, target)
	return data


func _stamp(kind: String, data: Variant, version: int) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var dict: Dictionary = data
	if kind == "profile":
		dict["profile_version"] = version
	else:
		dict["version"] = version
