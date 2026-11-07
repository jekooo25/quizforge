class_name TeacherReviews
extends RefCounted
const PATH := "user://teacher_reviews.json"
static func all() -> Array:
 var result := SaveManager.read_json(PATH)
 if not result.get("ok", false): return []
 var data: Variant = result.get("data", {})
 return data.get("reviews", []) if data is Dictionary else []
static func submit(id: String) -> bool:
 if Nav.user.get("role", "student") != "student": return false
 var quiz := QuizLibrary.get_quiz(id)
 if quiz.is_empty() or quiz.get("questions", []).is_empty(): return false
 var rows := all()
 var owner := str(Nav.user.get("username", ""))
 for row: Dictionary in rows:
  if row.quiz_id == id and row.author == owner and row.status != "changes": return false
 var row := {"id": str(Time.get_unix_time_from_system()) + "_" + str(Time.get_ticks_usec()), "quiz_id": id,
  "author": owner, "title": quiz.get("title", "Untitled"), "questions": quiz.questions.duplicate(true), "status": "pending"}
 rows.append(row)
 return SaveManager.write_json(PATH, {"version": 1, "reviews": rows})
static func transition(id: String, status: String) -> bool:
 if Nav.user.get("role", "student") != "teacher": return false
 var rows := all()
 for row: Dictionary in rows:
  if row.id != id: continue
  var allowed := {"pending": ["approved", "changes"], "approved": ["shared"], "shared": ["approved"]}
  if status not in allowed.get(row.status, []): return false
  row.status = status
  row["teacher"] = str(Nav.user.get("username", ""))
  return SaveManager.write_json(PATH, {"version": 1, "reviews": rows})
 return false
static func receive(id: String) -> bool:
 if Nav.user.get("role", "student") != "student": return false
 for row: Dictionary in all():
  if row.id == id and row.status == "shared":
   return QuizLibrary.add(row.title, row.questions, "received", "teacher-" + id) != ""
 return false
