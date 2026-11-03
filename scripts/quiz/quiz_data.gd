class_name QuizData
extends RefCounted
## The quiz set the battle plays, and the rules it has to satisfy.
##
## Shape is exactly what scripts/battle.gd already consumes:
##     {"q": "question text", "choices": ["a", "b", "c", "d"], "correct": 2}
##
## Everything that converts, validates or stores a quiz goes through here, so
## the review screen and the battle can't drift apart.

const SAVE_PATH := "user://quizforge_quiz.json"

## Used when no reviewer has been generated yet, and as the fallback when the
## question server can't be reached. Clearly labelled as a sample in the UI —
## it is not pretending to be the student's material.
const SAMPLE := [
	{"q": "Which planet is known as the Red Planet?", "choices": ["Venus", "Mars", "Jupiter", "Mercury"], "correct": 1},
	{"q": "What is the only mammal capable of true flight?", "choices": ["Flying squirrel", "Bat", "Sugar glider", "Colugo"], "correct": 1},
	{"q": "How many degrees are in a right angle?", "choices": ["45", "90", "180", "360"], "correct": 1},
	{"q": "Which gas do plants mainly absorb for photosynthesis?", "choices": ["Oxygen", "Nitrogen", "Carbon dioxide", "Hydrogen"], "correct": 2},
	{"q": "Who painted the Mona Lisa?", "choices": ["Michelangelo", "Raphael", "Donatello", "Leonardo da Vinci"], "correct": 3},
]


static func sample() -> Array:
	return SAMPLE.duplicate(true)


## Server questions mixed-case keys; the battle uses short ones. Normalise here.
static func from_server(payload: Dictionary) -> Array:
	var out: Array = []
	for item in payload.get("questions", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var choices: Array = []
		for c in item.get("choices", []):
			choices.append(str(c))
		while choices.size() < 4:
			choices.append("")
		out.append({
			"q": str(item.get("question", item.get("q", ""))),
			"choices": choices.slice(0, 4),
			"correct": int(item.get("answer", item.get("correct", -1))),
		})
	return out


## Returns a list of human-readable problems. Empty means the set is playable.
static func validate(questions: Array) -> Array[String]:
	var problems: Array[String] = []

	if questions.is_empty():
		problems.append("There are no questions yet — regenerate to get some.")
		return problems

	for i in questions.size():
		var q: Dictionary = questions[i]
		var n := i + 1
		var text := str(q.get("q", "")).strip_edges()
		var choices: Array = q.get("choices", [])
		var correct := int(q.get("correct", -1))

		if text == "":
			problems.append("Question %d has no text." % n)

		if choices.size() != 4:
			problems.append("Question %d needs exactly 4 choices." % n)
		else:
			for j in choices.size():
				if str(choices[j]).strip_edges() == "":
					problems.append("Question %d, choice %s is empty." % [n, char(65 + j)])

		if correct < 0 or correct > 3:
			problems.append("Question %d needs one correct answer marked." % n)

	return problems


## Saves in the battle's shape. Returns false if the file can't be written.
static func save(title: String, questions: Array) -> bool:
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

	var data := {
		"version": int(SaveManager.VERSIONS["quiz"]),
		"title": title,
		"saved_at": Time.get_datetime_string_from_system(),
		"questions": clean,
	}
	return SaveManager.write_json(SAVE_PATH, data, "quiz")


static func exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or SaveManager.has_backup(SAVE_PATH)


## Returns {"title": String, "questions": Array, "status": String}.
##
## status is SaveManager.STATUS_MISSING when nothing was ever saved, STATUS_CORRUPT
## when the file *and* its backup are unreadable, and STATUS_OK/STATUS_RECOVERED
## otherwise. A caller must never paper over STATUS_CORRUPT with sample questions:
## the student would be answering a set they did not choose.
static func load_saved() -> Dictionary:
	var result := SaveManager.read_json(SAVE_PATH, "quiz")
	if not result["ok"]:
		return {"title": "", "questions": [], "status": result["status"]}

	var parsed: Variant = result["data"]
	var raw: Array = []
	var title := ""
	if typeof(parsed) == TYPE_DICTIONARY:
		var dict: Dictionary = parsed
		title = str(dict.get("title", ""))
		var maybe: Variant = dict.get("questions", [])
		if typeof(maybe) == TYPE_ARRAY:
			raw.assign(maybe)
	elif typeof(parsed) == TYPE_ARRAY:
		# accept a bare array too, so a hand-written set still loads
		raw.assign(parsed)
	else:
		return {"title": "", "questions": [], "status": SaveManager.STATUS_CORRUPT}

	var out: Array = []
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		out.append({
			"q": str(item.get("q", item.get("question", ""))),
			"choices": item.get("choices", []),
			"correct": int(item.get("correct", item.get("answer", -1))),
		})
	return {"title": title, "questions": out, "status": result["status"]}
