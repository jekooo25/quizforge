extends Node
## Save-layer tests. Run with:
##   godot --headless --path . res://tests/save.tscn
##
## Covers what the old code got wrong: a write that lands half-finished, a file
## repaired from its backup, two damaged files at once, version migration, and
## re-saving the same reviewer.

const TMP := "user://_save_tests"

## Every check this run must reach; a skipped assertion means a script error.
const EXPECTED_CHECKS := 65

var failures: int = 0
var checks_run: int = 0


func _ready() -> void:
	_run()


func _check(condition: bool, message: String) -> void:
	checks_run += 1
	if condition:
		print("  ok   ", message)
	else:
		failures += 1
		printerr("  FAIL ", message)


## Depth-first search for a Button whose text matches.
func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text.contains(text):
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _run() -> void:
	# A broken autoload makes every check below error out without counting as a
	# failure, which reads as a pass. Assert it loaded before trusting anything.
	if SaveManager == null or Nav == null:
		printerr("  FAIL an autoload did not load (SaveManager / Nav)")
		printerr("SAVE CHECKS FAILED")
		get_tree().quit(1)
		return

	_wipe(TMP)
	DirAccess.make_dir_recursive_absolute(TMP)

	var profile_snapshot := _snapshot_file(Nav.SAVE_PATH)

	_test_atomic_roundtrip()
	_test_corrupt_main_recovers()
	_test_both_corrupt()
	_test_migration()
	_test_quiz_status()
	_test_library_dedupe()
	_test_index_legacy_array()
	await _test_settings_persist()
	await _test_battle_refuses_sample()

	_restore_file(Nav.SAVE_PATH, profile_snapshot)
	_wipe(TMP)

	if checks_run != EXPECTED_CHECKS:
		failures += 1
		printerr("  FAIL ran %d checks, expected %d — an assertion errored and was skipped" % [
			checks_run, EXPECTED_CHECKS])

	print("")
	if failures == 0:
		print("ALL SAVE CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("%d SAVE CHECK(S) FAILED" % failures)
		get_tree().quit(1)


# ------------------------------------------------------------------- cases

func _test_atomic_roundtrip() -> void:
	print("-- a write survives being read back from disk --")
	var p := _path("roundtrip.json")
	SaveManager.forget(p)

	var data := {"version": 1, "value": 41, "nested": {"name": "quiz"}}
	_check(SaveManager.write_json(p, data, "quiz"), "write_json reports success")
	_check(FileAccess.file_exists(p), "the real file is on disk")
	_check(not FileAccess.file_exists(p + SaveManager.TEMP_SUFFIX),
		"the temp file is gone, not left beside it")

	# A fresh read is exactly what a restart does.
	var back := SaveManager.read_json(p, "quiz")
	_check(back["ok"], "the file reads back")
	_check(int(back["data"]["value"]) == 41, "the stored value survived")
	_check(str(back["data"]["nested"]["name"]) == "quiz", "nested data survived")
	_check(back["status"] == SaveManager.STATUS_OK, "a clean read reports OK")


func _test_corrupt_main_recovers() -> void:
	print("-- a damaged main file falls back to its backup --")
	var p := _path("recover.json")
	SaveManager.forget(p)

	SaveManager.write_json(p, {"version": 1, "value": 1}, "quiz")
	# a second write pushes the first one into the .bak slot
	SaveManager.write_json(p, {"version": 1, "value": 2}, "quiz")
	_check(SaveManager.has_backup(p), "a backup is kept beside the file")

	_write_raw(p, "{ this is not json at all")
	var r := SaveManager.read_json(p, "quiz")
	_check(r["ok"], "the read still succeeds")
	_check(r["status"] == SaveManager.STATUS_RECOVERED, "it reports that it used the backup")
	_check(int(r["data"]["value"]) == 1, "the backup's value is the one handed back")

	var repaired := SaveManager.read_json(p, "quiz")
	_check(repaired["status"] == SaveManager.STATUS_OK, "the main file was repaired from the backup")
	_check(int(repaired["data"]["value"]) == 1, "the repaired file holds the backup's value")


func _test_both_corrupt() -> void:
	print("-- both the file and its backup damaged --")
	var p := _path("hopeless.json")
	SaveManager.forget(p)

	SaveManager.write_json(p, {"version": 1, "value": 1}, "quiz")
	SaveManager.write_json(p, {"version": 1, "value": 2}, "quiz")
	_write_raw(p, "garbage")
	_write_raw(p + SaveManager.BACKUP_SUFFIX, "also garbage")

	var r := SaveManager.read_json(p, "quiz")
	_check(not r["ok"], "the read reports failure instead of crashing")
	_check(r["status"] == SaveManager.STATUS_CORRUPT, "status is CORRUPT")
	_check(r["data"] == null, "no data is invented")


func _test_migration() -> void:
	print("-- version is read and migrated --")

	var q := _path("legacy_quiz.json")
	SaveManager.forget(q)
	_write_raw(q, JSON.stringify({
		"title": "old",
		"questions": [{"q": "a", "choices": ["1", "2", "3", "4"], "correct": 0}],
	}))
	var r := SaveManager.read_json(q, "quiz")
	_check(r["ok"], "an unversioned quiz loads")
	_check(r["migrated"], "the load reports that it migrated")
	_check(int(r["version"]) == int(SaveManager.VERSIONS["quiz"]),
		"it is stamped with the current quiz version")
	_check(int(SaveManager.VERSIONS["quiz"]) == 2,
		"quiz schema version was bumped for question source metadata")

	var again := SaveManager.read_json(q, "quiz")
	_check(not again["migrated"], "the migrated shape is written back, so it runs once")
	var old_v1 := _path("v1_quiz.json")
	_write_raw(old_v1, JSON.stringify({"version": 1, "title": "v1", "questions": [
		{"q": "old question", "choices": ["a", "b", "c", "d"], "correct": 1}
	]}))
	var upgraded_v1 := SaveManager.read_json(old_v1, "quiz")
	_check(upgraded_v1["migrated"] and int(upgraded_v1["version"]) == 2,
		"a version 1 quiz upgrades through SaveManager")
	var normalized: Dictionary = QuizData.from_server({"questions": [{
		"question": "new question", "choices": ["a", "b", "c", "d"], "answer": 2,
		"explanation": "server explanation", "page": 5, "source_quote": "server source"
	}]})[0]
	_check(str(normalized["explanation"]) == "server explanation" and int(normalized["page"]) == 5
		and str(normalized["source_quote"]) == "server source",
		"server normalization preserves explanation, page, and source quote")

	var prof := _path("legacy_profile.json")
	SaveManager.forget(prof)
	_write_raw(prof, JSON.stringify({"user": {"username": "old"}}))
	var pr := SaveManager.read_json(prof, "profile")
	_check(pr["ok"] and int(pr["version"]) == int(SaveManager.VERSIONS["profile"]),
		"an unversioned profile comes up to the current profile version")


func _test_quiz_status() -> void:
	print("-- a damaged current quiz is reported, not replaced --")
	var saved := _snapshot_file(QuizData.SAVE_PATH)
	SaveManager.forget(QuizData.SAVE_PATH)

	var missing := QuizData.load_saved()
	_check(missing["status"] == SaveManager.STATUS_MISSING, "no quiz reports MISSING")
	_check(missing["questions"].is_empty(), "and hands back no questions")
	_write_raw(QuizData.SAVE_PATH, JSON.stringify({"version": 1, "title": "old quiz", "questions": [
		{"q": "An old question?", "choices": ["a", "b", "c", "d"], "correct": 0}
	]}))
	var legacy_quiz := QuizData.load_saved()
	_check(legacy_quiz["status"] == SaveManager.STATUS_OK
		and QuizData.validate(legacy_quiz["questions"]).is_empty()
		and str(legacy_quiz["questions"][0].get("explanation", "")) == "",
		"an old quiz without explanation/page/source fields still loads and plays")

	_check(QuizData.save("reviewer", QuizData.sample()), "a quiz saves")
	var good := QuizData.load_saved()
	_check(good["status"] == SaveManager.STATUS_OK, "a healthy quiz reports OK")
	_check(good["questions"].size() == QuizData.sample().size(), "all questions read back")
	var enriched := QuizData.sample()
	enriched[0]["explanation"] = "Because this is the explanation."
	enriched[0]["page"] = 7
	enriched[0]["source_quote"] = "The source sentence."
	_check(QuizData.save("enriched", enriched), "a question with source metadata saves")
	var enriched_loaded: Dictionary = QuizData.load_saved()["questions"][0]
	_check(str(enriched_loaded["explanation"]) == "Because this is the explanation.", "explanation survives save/load")
	_check(int(enriched_loaded["page"]) == 7 and str(enriched_loaded["source_quote"]) == "The source sentence.",
		"page and source quote survive save/load")

	_write_raw(QuizData.SAVE_PATH, "broken beyond repair")
	_write_raw(QuizData.SAVE_PATH + SaveManager.BACKUP_SUFFIX, "also broken")
	var bad := QuizData.load_saved()
	_check(bad["status"] == SaveManager.STATUS_CORRUPT, "a damaged quiz reports CORRUPT")
	_check(bad["questions"].is_empty(), "it does not hand back sample questions")
	_check(str(bad["title"]) == "", "it does not claim a title")

	_restore_file(QuizData.SAVE_PATH, saved)


func _test_library_dedupe() -> void:
	print("-- re-saving the same reviewer updates one entry --")
	var saved := _snapshot_library()
	_clear_library()

	var questions := QuizData.sample()
	questions[0]["explanation"] = "library explanation"
	questions[0]["page"] = 12
	questions[0]["source_quote"] = "library source"
	var first := QuizLibrary.add("reviewer", questions, "generated", "C:/x/UPPER_20LIMB.pdf")
	_check(first != "", "the first save gets an id")
	_check(QuizLibrary.all().size() == 1, "one entry on the shelf")

	var second := QuizLibrary.add("reviewer", questions.slice(0, 3), "generated", "C:/x/UPPER_20LIMB.pdf")
	_check(second == first, "re-saving reuses the same id")
	_check(QuizLibrary.all().size() == 1, "still one entry, not a duplicate")

	var entry: Dictionary = QuizLibrary.all()[0]
	_check(int(entry.get("count", 0)) == 3, "the entry knows the new question count")
	_check(QuizLibrary.get_quiz(first).get("questions", []).size() == 3,
		"the quiz body was rewritten in place")
	var library_question: Dictionary = QuizLibrary.get_quiz(first)["questions"][0]
	_check(str(library_question.get("explanation", "")) == "library explanation"
		and int(library_question.get("page", 0)) == 12
		and str(library_question.get("source_quote", "")) == "library source",
		"library save/load preserves explanation, page, and source quote")

	var other := QuizLibrary.add("another", questions, "generated", "C:/x/OTHER.pdf")
	_check(other != first, "a different reviewer gets its own entry")
	_check(QuizLibrary.all().size() == 2, "two reviewers, two entries")

	_restore_library(saved)


func _test_index_legacy_array() -> void:
	print("-- an old bare-array index still loads --")
	var saved := _snapshot_library()
	_clear_library()
	DirAccess.make_dir_recursive_absolute(QuizLibrary.DIR)

	_write_raw(QuizLibrary.INDEX_PATH, JSON.stringify([
		{"id": "q1", "title": "old", "count": 2, "created_at": "2020-01-01T00:00:00"},
	]))
	var entries := QuizLibrary.all()
	_check(entries.size() == 1, "the legacy entry is read")
	_check(str(entries[0].get("title", "")) == "old", "its fields survive")
	_check(int(entries[0].get("count", 0)) == 2, "its count survives")

	_restore_library(saved)


## Volume settings live in the profile, so they must reload after a restart and
## must actually reach the audio buses rather than just a label.
func _test_settings_persist() -> void:
	print("-- volume settings save, reload and reach the buses --")
	var profile_snapshot := _snapshot_file(Nav.SAVE_PATH)
	var before := AudioMixer.volume_of(Nav.user, "volume_music")

	var screen: Control = load("res://scripts/screens/settings_screen.gd").new()
	add_child(screen)
	await get_tree().process_frame

	var music: Variant = screen._sliders.get("volume_music")
	var sfx: Variant = screen._sliders.get("volume_sfx")
	_check(music != null and sfx != null, "the screen has a music and an SFX slider")
	if music == null or sfx == null:
		screen.queue_free()
		_restore_file(Nav.SAVE_PATH, profile_snapshot)
		return

	_check(int(music.value) == before, "the music slider opens at the saved value")

	music.value = 25
	music.value_changed.emit(25.0)
	music.drag_ended.emit(true)
	await get_tree().process_frame

	_check(int(Nav.user.get("volume_music", -1)) == 25, "the drag is held in the session")

	var music_bus := AudioServer.get_bus_index(AudioMixer.MUSIC)
	_check(music_bus != -1, "a Music bus exists")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.25)),
		"the level reaches the Music bus")
	_check(not AudioServer.is_bus_mute(music_bus), "a live level is not muted")

	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(Nav.SAVE_PATH))
	var saved_music := -1
	if typeof(saved) == TYPE_DICTIONARY:
		var saved_dict: Dictionary = saved
		var saved_user: Variant = saved_dict.get("user", {})
		if typeof(saved_user) == TYPE_DICTIONARY:
			var user_dict: Dictionary = saved_user
			saved_music = int(user_dict.get("volume_music", -1))
	_check(saved_music == 25, "the value is written into the profile file")

	sfx.value = 0
	sfx.value_changed.emit(0.0)
	sfx.drag_ended.emit(true)
	var sfx_bus := AudioServer.get_bus_index(AudioMixer.SFX)
	_check(sfx_bus != -1 and AudioServer.is_bus_mute(sfx_bus), "zero mutes the SFX bus")

	# a restart: drop the session copy and read the file back
	Nav.user["volume_music"] = 0
	Nav.load_profile()
	_check(int(Nav.user.get("volume_music", -1)) == 25, "the volume survives a restart")

	screen.queue_free()
	await get_tree().process_frame

	_restore_file(Nav.SAVE_PATH, profile_snapshot)
	if FileAccess.file_exists(Nav.SAVE_PATH):
		Nav.load_profile()
	else:
		Nav.user["volume_music"] = before
	AudioMixer.apply(Nav.user)


## The battle must never paper over a damaged quiz with the built-in sample.
func _test_battle_refuses_sample() -> void:
	print("-- a damaged quiz shows a message instead of sample questions --")
	var saved_quiz := _snapshot_file(QuizData.SAVE_PATH)
	SaveManager.forget(QuizData.SAVE_PATH)

	var battle: Control = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)
	await get_tree().process_frame

	_check(battle.unavailable, "the battle refuses to start")
	_check(str(battle.unavailable_message).contains("couldn't open this quiz"),
		"it explains the problem to the student")
	_check(battle.player == null, "no fight was built")
	_check(battle.answer_buttons.is_empty(), "no sample answers are offered")
	_check(battle._questions.is_empty(), "no question set was invented")

	var back := _find_button(battle, "Back to menu")
	_check(back != null, "there is a way back to the menu")
	if back != null:
		back.pressed.emit()
		await get_tree().process_frame
		_check(Nav._current != null, "the menu opens")
		_check(str(Nav._current.get_script().resource_path).ends_with("menu_screen.gd"),
			"it really is the main menu")

	battle.queue_free()
	await get_tree().process_frame
	_restore_file(QuizData.SAVE_PATH, saved_quiz)


# ---------------------------------------------------------------- helpers

func _path(name: String) -> String:
	return "%s/%s" % [TMP, name]


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("  FAIL could not open %s for writing" % path)
		return
	f.store_string(text)
	f.close()


func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [dir, f]))
	var sub := DirAccess.open(dir)
	if sub != null:
		for d in sub.get_directories():
			_wipe("%s/%s" % [dir, d])


func _snapshot_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _restore_file(path: String, text: String) -> void:
	if text == "":
		SaveManager.forget(path)
		return
	_write_raw(path, text)


func _snapshot_library() -> Array:
	var saved: Array = []
	if not DirAccess.dir_exists_absolute(QuizLibrary.DIR):
		return saved
	for f in DirAccess.get_files_at(QuizLibrary.DIR):
		saved.append({
			"name": f,
			"text": FileAccess.get_file_as_string("%s/%s" % [QuizLibrary.DIR, f]),
		})
	return saved


func _restore_library(saved: Array) -> void:
	_clear_library()
	DirAccess.make_dir_recursive_absolute(QuizLibrary.DIR)
	for item in saved:
		_write_raw("%s/%s" % [QuizLibrary.DIR, item["name"]], item["text"])


func _clear_library() -> void:
	if not DirAccess.dir_exists_absolute(QuizLibrary.DIR):
		return
	for f in DirAccess.get_files_at(QuizLibrary.DIR):
		SaveManager.forget("%s/%s" % [QuizLibrary.DIR, f])
