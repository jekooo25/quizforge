extends Node
const URL := "http://127.0.0.1:8766"
const PATH := "user://laptop_sharing.json"
var state: Dictionary = {"joins": {}, "outbox": []}
var sending := false
var base_url := URL
func _ready() -> void:
 var saved := SaveManager.read_json(PATH)
 if saved.get("ok",false) and saved.get("data") is Dictionary:
  state = saved.data
func api(path: String, method := HTTPClient.METHOD_GET, data: Dictionary = {}) -> Dictionary:
 var http := HTTPRequest.new()
 http.timeout = 5.0
 add_child(http)
 var role := str(Nav.user.get("role","student"))
 var error := http.request(base_url + path,["Content-Type: application/json","X-Demo-Role: " + role],method,JSON.stringify(data) if method != HTTPClient.METHOD_GET else "")
 if error != OK:
  http.queue_free()
  return {"ok":false,"error":"Start the laptop sharing server and try again."}
 var reply: Array = await http.request_completed
 http.queue_free()
 if reply[0] != HTTPRequest.RESULT_SUCCESS:
  return {"ok":false,"error":"Cannot reach laptop sharing. Start Start Sharing Server, then retry."}
 var parsed: Variant = JSON.parse_string(reply[3].get_string_from_utf8())
 if not parsed is Dictionary: return {"ok":false,"error":"The server returned an unreadable reply."}
 return parsed
func submit_quiz(id: String) -> Dictionary:
 var quiz := QuizLibrary.get_quiz(id)
 if quiz.is_empty(): return {"ok":false,"error":"Quiz could not be opened."}
 if QuizLibrary.is_shared({"id":id,"source":quiz.get("source","")}): return {"ok":false,"error":"This is a shared quiz. Edit a private draft to create your own revision."}
 var reply := await api("/reviews",HTTPClient.METHOD_POST,{"source_id":id,"author":Nav.user.get("username","Student"),"title":quiz.title,"questions":questions_payload(quiz.questions),"parent_review_id":quiz.get("parent_review_id",""),"parent_source_id":quiz.get("parent_library_id","")})
 if reply.get("ok",false):
  if not state.has("submissions"): state["submissions"] = {}
  state.submissions[id] = reply.review.id
  SaveManager.write_json(PATH,state)
 return reply
func join_quiz(code: String) -> Dictionary:
 var reply := await api("/join",HTTPClient.METHOD_POST,{"code":code,"student":Nav.user.get("username","Student"),"nickname":Nav.user.get("leaderboard_nickname","")})
 return _save_join(reply)
func join_public(id: String) -> Dictionary:
 var reply := await api("/public/"+id+"/join",HTTPClient.METHOD_POST,{"student":Nav.user.get("username","Student"),"nickname":Nav.user.get("leaderboard_nickname","")})
 return _save_join(reply)
func _save_join(reply: Dictionary) -> Dictionary:
 if not reply.get("ok",false): return reply
 var review: Dictionary = reply.review
 var id := ""
 for entry: Dictionary in QuizLibrary.all():
  if str(entry.get("key",""))=="laptop-"+str(review.id) and not QuizLibrary.get_quiz(str(entry.id)).is_empty():
   id = str(entry.id)
   break
 if id=="": id = QuizLibrary.add(review.title,review.questions,"received","laptop-"+review.id)
 if id == "": return {"ok":false,"error":"Could not save this quiz. Please retry."}
 state.joins[id] = {"join_id":reply.join_id,"code":review.code,"review_id":review.id,"review_version":review.get("review_version",1),"author":review.author}
 if not SaveManager.write_json(PATH,state): return {"ok":false,"error":"Could not save the join details. Please retry."}
 reply["library_id"] = id
 return reply
func queue_result(id: String, attempt: String, data: Dictionary) -> bool:
 if not state.joins.has(id): return false
 var result := data.duplicate(true)
 result["join_id"] = state.joins[id].join_id
 result["attempt_id"] = attempt
 var previous: Array = state.outbox.duplicate(true)
 var replaced := false
 for i in state.outbox.size():
  if state.outbox[i].get("attempt_id","")==attempt:
   if int(result.get("revision",0))<int(state.outbox[i].get("revision",0)): return true
   state.outbox[i] = result
   replaced = true
   break
 if not replaced: state.outbox.append(result)
 if not SaveManager.write_json(PATH,state):
  state.outbox = previous
  return false
 send_pending.call_deferred()
 return true
func send_pending() -> Dictionary:
 if sending: return {"ok":false,"error":"Results are already sending."}
 sending = true
 for result: Dictionary in state.outbox.duplicate(true):
  var payload := result.duplicate(true)
  # Godot JSON reads numeric counters as floats after an application restart.
  for key in ["correct","answered","score","recall_correct","recall_attempted","revision"]:
   if payload.has(key): payload[key] = int(payload[key])
  if payload.has("remaining_indices"):
   var indices: Array = []
   for value: Variant in payload.remaining_indices: indices.append(int(value))
   payload.remaining_indices = indices
  var reply := await api("/results",HTTPClient.METHOD_POST,payload)
  if not reply.get("ok",false):
   sending = false
   return reply
  state.outbox.erase(result)
  SaveManager.write_json(PATH,state)
 sending = false
 # A newer practice snapshot may have arrived while an older one was sending.
 if not state.outbox.is_empty(): send_pending.call_deferred()
 return {"ok":true}

func questions_payload(questions: Array) -> Array:
 var output:=questions.duplicate(true)
 for question: Dictionary in output:
  question["correct"]=int(question.get("correct",-1))
  if question.has("page"):question["page"]=int(question.page)
 return output
