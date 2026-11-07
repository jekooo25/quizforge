"""Laptop-only Quizforge sharing demo. No internet hosting or account authentication.
Run: python server/sharing_server.py
Bound to loopback only. QF_SHARING_DB overrides persistent SQLite storage for tests.
"""
import json, os, secrets, sqlite3, uuid
from contextlib import contextmanager
from pathlib import Path
from fractions import Fraction
from flask import Flask, request, jsonify
app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 2 * 1024 * 1024
DB = os.environ.get("QF_SHARING_DB", str(Path(__file__).with_name("sharing_demo.sqlite3")))
@contextmanager
def connect():
 db = sqlite3.connect(DB)
 db.row_factory = sqlite3.Row
 db.executescript("""CREATE TABLE IF NOT EXISTS reviews(id TEXT PRIMARY KEY, author TEXT, source_id TEXT, title TEXT, questions TEXT, status TEXT, code TEXT UNIQUE);
 CREATE TABLE IF NOT EXISTS joins(id TEXT PRIMARY KEY, review_id TEXT, student TEXT);
 CREATE TABLE IF NOT EXISTS results(attempt_id TEXT PRIMARY KEY, join_id TEXT, correct INTEGER, answered INTEGER, score INTEGER, recall_correct INTEGER, recall_attempted INTEGER, won INTEGER, created TEXT DEFAULT CURRENT_TIMESTAMP);
 CREATE TABLE IF NOT EXISTS courses(id TEXT PRIMARY KEY, title TEXT NOT NULL, professor TEXT NOT NULL);
 CREATE TABLE IF NOT EXISTS enrollments(course_id TEXT, student TEXT, section TEXT NOT NULL DEFAULT 'A', PRIMARY KEY(course_id,student));
 CREATE TABLE IF NOT EXISTS syllabi(course_id TEXT PRIMARY KEY, text TEXT NOT NULL, updated TEXT DEFAULT CURRENT_TIMESTAMP);
 CREATE TABLE IF NOT EXISTS course_settings(course_id TEXT PRIMARY KEY, auto_publish INTEGER NOT NULL DEFAULT 0);
 CREATE TABLE IF NOT EXISTS validations(review_id TEXT PRIMARY KEY, course_id TEXT NOT NULL, verdict TEXT NOT NULL, reason TEXT NOT NULL);""")
 try:
  # Additive migration: retain all existing publications, joins and battle reports.
  with db:
   db.execute("BEGIN IMMEDIATE")
   review_columns={r[1] for r in db.execute("PRAGMA table_info(reviews)")}
   if "course_id" not in review_columns: db.execute("ALTER TABLE reviews ADD COLUMN course_id TEXT")
   if "visibility" not in review_columns:
    db.execute("ALTER TABLE reviews ADD COLUMN visibility TEXT NOT NULL DEFAULT 'private'")
    db.execute("UPDATE reviews SET visibility='code_only' WHERE status='shared'")
   for name,definition in [("parent_id","TEXT"),("root_id","TEXT"),("review_version","INTEGER NOT NULL DEFAULT 1"),("leaderboard_enabled","INTEGER NOT NULL DEFAULT 0")]:
    if name not in review_columns: db.execute(f"ALTER TABLE reviews ADD COLUMN {name} {definition}")
   db.execute("UPDATE reviews SET root_id=id WHERE root_id IS NULL")
   join_columns={r[1] for r in db.execute("PRAGMA table_info(joins)")}
   if "nickname" not in join_columns: db.execute("ALTER TABLE joins ADD COLUMN nickname TEXT NOT NULL DEFAULT 'Player'")
   columns={r[1] for r in db.execute("PRAGMA table_info(results)")}
   for name,definition in [("review_mode","TEXT NOT NULL DEFAULT 'battle'"),("revision","INTEGER NOT NULL DEFAULT 0"),("remaining","TEXT DEFAULT NULL"),("updated","TEXT"),("leaderboard_eligible","INTEGER NOT NULL DEFAULT 0")]:
    if name not in columns: db.execute(f"ALTER TABLE results ADD COLUMN {name} {definition}")
   db.execute("UPDATE results SET updated=created WHERE updated IS NULL")
   demo_courses=[
    ("BIO101","Biology 101","Demo Teacher","cells genetics ecosystems"),
    ("HIST201","World History","Demo Teacher","empires trade revolutions"),
    ("MATH120","College Algebra","Demo Teacher","functions equations polynomials"),
    ("CHEM110","General Chemistry","Demo Teacher","atoms bonding reactions"),
    ("PHYS130","Physics I","Demo Teacher","motion forces energy"),
    ("ENG105","Academic Writing","Demo Teacher","thesis evidence citations"),
    ("CS115","Programming Fundamentals","Demo Teacher","variables loops functions"),
    ("PSY101","Introduction to Psychology","Demo Teacher","memory learning behavior"),
   ]
   for course_id,title,professor,syllabus in demo_courses:
    db.execute("INSERT OR IGNORE INTO courses(id,title,professor) VALUES(?,?,?)", (course_id,title,professor))
    db.execute("INSERT OR IGNORE INTO syllabi(course_id,text) VALUES(?,?)", (course_id,syllabus))
    db.execute("INSERT OR IGNORE INTO course_settings(course_id,auto_publish) VALUES(?,0)", (course_id,))
   for course_id,_,_,_ in demo_courses[:4]:
    db.execute("INSERT OR IGNORE INTO enrollments(course_id,student,section) VALUES(?,?,?)", (course_id,"Demo Student","A"))
  with db:
   yield db
 finally:
  db.close()
def payload():
 value = request.get_json(silent=True)
 return value if isinstance(value, dict) else {}
def error(message, status=400): return jsonify(ok=False,error=message),status
def teacher(): return request.headers.get("X-Demo-Role") == "teacher"
def rowdict(row):
 result = dict(row); result["questions"] = json.loads(result["questions"]); return result
def question_error(questions):
 if not isinstance(questions,list) or not 1<=len(questions)<=200: return "Quiz must have 1 to 200 questions."
 for q in questions:
  if not isinstance(q,dict) or not isinstance(q.get("q"),str) or not q["q"].strip(): return "Invalid question."
  choices=q.get("choices")
  if not isinstance(choices,list) or len(choices)!=4 or any(not isinstance(c,str) or not c.strip() for c in choices): return "Each question needs four answers."
  if len({c.strip().casefold() for c in choices})!=4: return "Answer choices must be distinct."
  if type(q.get("correct")) is not int or not 0<=q["correct"]<4: return "Invalid correct answer."
 return None

def nickname(data, token):
 value=" ".join(str(data.get("nickname","")).split())[:24]
 return value if len(value)>=2 else "Player-"+token[:4]

def content_key(questions):
 # IDs and titles can change when a student saves a copy. Compare actual content.
 def text(value): return " ".join(str(value or "").split())
 return json.dumps([{"q":text(q.get("q")),"choices":[text(c) for c in q.get("choices",[])],"correct":int(q.get("correct",-1)),"explanation":text(q.get("explanation")),"source_quote":text(q.get("source_quote")),"page":str(q.get("page",0) or 0)} for q in questions],sort_keys=True,ensure_ascii=False)

def same_student(a,b): return str(a).strip().casefold()==str(b).strip().casefold()

def course_professor(db, course_id):
 return db.execute("SELECT * FROM courses WHERE id=?", (course_id,)).fetchone()

def enrolled(db, course_id, student):
 return db.execute("SELECT 1 FROM enrollments WHERE course_id=? AND lower(student)=lower(?)", (course_id, student)).fetchone() is not None

def semantic_validate(db, course_id, questions):
 syllabus=db.execute("SELECT text FROM syllabi WHERE course_id=?", (course_id,)).fetchone()
 if not syllabus or not str(syllabus[0]).strip(): return False, "This course has no syllabus yet."
 source_words={w for w in str(syllabus[0]).lower().split() if len(w)>=5}
 content=" ".join(str(q.get("q", "")) + " " + " ".join(q.get("choices", [])) for q in questions).lower()
 overlap=sum(1 for word in source_words if word in content)
 if overlap < 2: return False, "This material does not match the selected course syllabus."
 return True, "Course-aligned material."

@app.get("/courses")
def courses():
 with connect() as db:
  role=request.headers.get("X-Demo-Role", "student"); name=request.headers.get("X-Demo-User", "")
  if role == "teacher": rows=db.execute("SELECT * FROM courses WHERE lower(professor)=lower(?)", (name,)).fetchall()
  else: rows=db.execute("SELECT c.* FROM courses c JOIN enrollments e ON e.course_id=c.id WHERE lower(e.student)=lower(?)", (name,)).fetchall()
  return jsonify(ok=True,courses=[dict(r) for r in rows])

@app.post("/courses")
def create_course():
 if not teacher(): return error("Teacher role required.",403)
 data=payload(); course_id=str(data.get("id", "")).strip()[:80]; title=str(data.get("title", "")).strip()[:160]
 if not course_id or not title: return error("Course ID and title are required.")
 with connect() as db:
  db.execute("INSERT OR REPLACE INTO courses(id,title,professor) VALUES(?,?,?)", (course_id,title,request.headers.get("X-Demo-User", "Teacher")))
  db.execute("INSERT OR IGNORE INTO course_settings(course_id,auto_publish) VALUES(?,0)", (course_id,))
  return jsonify(ok=True,course=dict(db.execute("SELECT * FROM courses WHERE id=?", (course_id,)).fetchone()))

@app.post("/courses/<course_id>/enroll")
def enroll_student(course_id):
 if not teacher(): return error("Teacher role required.",403)
 student=str(payload().get("student", "")).strip()[:80]
 with connect() as db:
  if not course_professor(db, course_id): return error("Course not found.",404)
  db.execute("INSERT OR REPLACE INTO enrollments(course_id,student,section) VALUES(?,?,?)", (course_id,student,str(payload().get("section", "A"))[:20]))
  return jsonify(ok=True)

@app.post("/courses/<course_id>/syllabus")
def save_syllabus(course_id):
 if not teacher(): return error("Teacher role required.",403)
 text=str(payload().get("text", "")).strip()
 with connect() as db:
  course=course_professor(db, course_id)
  if not course: return error("Course not found.",404)
  if str(course["professor"]).casefold()!=request.headers.get("X-Demo-User", "").casefold(): return error("Only the course professor can edit its syllabus.",403)
  db.execute("INSERT OR REPLACE INTO syllabi(course_id,text,updated) VALUES(?,?,CURRENT_TIMESTAMP)", (course_id,text))
  return jsonify(ok=True)

@app.post("/courses/<course_id>/settings")
def course_settings(course_id):
 if not teacher(): return error("Teacher role required.",403)
 with connect() as db:
  course=course_professor(db, course_id)
  if not course: return error("Course not found.",404)
  enabled=bool(payload().get("auto_publish", False))
  db.execute("INSERT OR REPLACE INTO course_settings(course_id,auto_publish) VALUES(?,?)", (course_id,int(enabled)))
  return jsonify(ok=True,auto_publish=enabled)

@app.post("/courses/<course_id>/validate")
def validate_course_content(course_id):
 data=payload(); student=str(data.get("student", "")).strip(); questions=data.get("questions", [])
 if request.headers.get("X-Demo-Role") != "student": return error("Submit from the Student role.",403)
 with connect() as db:
  if not enrolled(db, course_id, student): return error("You are not enrolled in this course.",403)
  valid,reason=semantic_validate(db, course_id, questions)
  return jsonify(ok=True,verdict="approved" if valid else "rejected",reason=reason)

def annotated_reviews(db):
 rows=[rowdict(r) for r in db.execute("SELECT * FROM reviews ORDER BY rowid DESC")]
 canonical={}
 # Prefer an existing publication/approval, then the earliest pending submission.
 for row in sorted(reversed(rows),key=lambda r:{"shared":0,"approved":1,"pending":2,"changes":3}.get(r["status"],4)):
  key=(row["author"].strip().casefold(),content_key(row["questions"]))
  if key in canonical:row["duplicate_of"]=canonical[key]
  else:canonical[key]=row["id"]
 return rows

@app.get("/health")
def health(): return jsonify(ok=True,mode="laptop demo",authentication=False)
@app.route("/reviews",methods=["GET","POST"])
def reviews():
 with connect() as db:
  if request.method == "GET":
   if not teacher(): return error("Choose Teacher to view submissions.",403)
   return jsonify(ok=True,reviews=annotated_reviews(db))
  data = payload(); questions=data.get("questions",[])
  if request.headers.get("X-Demo-Role") != "student": return error("Submit from the Student role.",403)
  issue=question_error(questions)
  if issue: return error(issue)
  author=str(data.get("author","")).strip()[:80]; source=str(data.get("source_id",""))[:200]
  if not author or not source: return error("Student name and quiz ID are required.")
  course_id=str(data.get("course_id", "")).strip()[:80]
  if course_id:
   if not enrolled(db, course_id, author): return error("You are not enrolled in this course.",403)
   valid,reason=semantic_validate(db, course_id, questions)
   if not valid: return error(reason,422)
  db.execute("BEGIN IMMEDIATE")
  candidates=[r for r in db.execute("SELECT * FROM reviews ORDER BY rowid DESC") if same_student(r["author"],author)]
  key=content_key(questions)
  matches=[r for r in candidates if content_key(json.loads(r["questions"]))==key]
  if matches:
   existing=min(matches,key=lambda r:{"shared":0,"approved":1,"pending":2,"changes":3}.get(r["status"],4))
   message="This quiz was already submitted. No duplicate was created."
   if existing["status"]=="changes":message="This quiz was returned for changes. Edit the questions before submitting again."
   return jsonify(ok=True,review=rowdict(existing),duplicate=True,message=message)
  existing=next((r for r in candidates if r["source_id"]==source),None)
  parent=None
  if data.get("parent_review_id"):
   parent=db.execute("SELECT * FROM reviews WHERE id=? AND author=?",(str(data["parent_review_id"]),author)).fetchone()
   if not parent: return error("That parent revision does not belong to this student.",403)
  elif data.get("parent_source_id"):
   parent=db.execute("SELECT * FROM reviews WHERE source_id=? AND author=? ORDER BY rowid DESC LIMIT 1",(str(data["parent_source_id"]),author)).fetchone()
  if parent is None and existing is not None:parent=existing
  id=uuid.uuid4().hex
  root=parent["root_id"] if parent else id
  version=db.execute("SELECT COALESCE(MAX(review_version),0)+1 FROM reviews WHERE root_id=?",(root,)).fetchone()[0]
  status="pending"
  if course_id and db.execute("SELECT auto_publish FROM course_settings WHERE course_id=?", (course_id,)).fetchone()[0]: status="shared"
  db.execute("INSERT INTO reviews(id,author,source_id,title,questions,status,code,parent_id,root_id,review_version,course_id) VALUES(?,?,?,?,? ,?,NULL,?,?,?,?)",(id,author,source,str(data.get("title","Untitled"))[:200],json.dumps(questions),status,parent["id"] if parent else None,root,version,course_id or None))
  if course_id: db.execute("INSERT OR REPLACE INTO validations(review_id,course_id,verdict,reason) VALUES(?,?,?,?)", (id,course_id,"approved","Course-aligned material."))
  return jsonify(ok=True,review=rowdict(db.execute("SELECT * FROM reviews WHERE id=?",(id,)).fetchone()))
@app.post("/reviews/<id>/status")
def transition(id):
 if not teacher(): return error("Teacher role required.",403)
 with connect() as db:
  db.execute("BEGIN IMMEDIATE")
  row=db.execute("SELECT * FROM reviews WHERE id=?",(id,)).fetchone()
  if not row: return error("Reviewer not found.",404)
  status=payload().get("status")
  allowed={"pending":["approved","changes"],"approved":["shared"],"shared":["approved"]}
  if status not in allowed.get(row["status"],[]): return error("This change is not available.",409)
  if status=="approved" and row["status"]=="pending":
   key=content_key(json.loads(row["questions"]))
   for other in db.execute("SELECT * FROM reviews WHERE id!=? AND status IN ('approved','shared')",(id,)):
    if same_student(other["author"],row["author"]) and content_key(json.loads(other["questions"]))==key:
     return error("This student's identical quiz has already been approved. Open the existing quiz instead.",409)
  code=row["code"]
  if status == "shared" and not code:
   while True:
    code="".join(secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(6))
    if not db.execute("SELECT 1 FROM reviews WHERE code=?",(code,)).fetchone(): break
  db.execute("UPDATE reviews SET status=?,code=?,visibility=CASE WHEN ?='shared' THEN 'code_only' ELSE visibility END,leaderboard_enabled=0 WHERE id=?",(status,code,status,id))
  return jsonify(ok=True,review=rowdict(db.execute("SELECT * FROM reviews WHERE id=?",(id,)).fetchone()))
@app.post("/reviews/<id>/publish")
def publish(id):
 if not teacher(): return error("Teacher role required.",403)
 visibility=payload().get("visibility")
 if visibility not in ("private","code_only","public"): return error("Choose Private draft, Code-only or Public.")
 with connect() as db:
  row=db.execute("SELECT * FROM reviews WHERE id=?",(id,)).fetchone()
  if not row: return error("Reviewer not found.",404)
  if row["status"] not in ("approved","shared"): return error("Approve this submission before publishing.",409)
  code=row["code"]
  if visibility!="private" and not code:
   while True:
    code="".join(secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(6))
    if not db.execute("SELECT 1 FROM reviews WHERE code=?",(code,)).fetchone(): break
  enabled=payload().get("leaderboard_enabled",False)
  if type(enabled) is not bool: return error("Invalid leaderboard option.")
  enabled=int(enabled and visibility=="public")
  status="approved" if visibility=="private" else "shared"
  db.execute("UPDATE reviews SET status=?,visibility=?,code=?,leaderboard_enabled=? WHERE id=?",(status,visibility,code,enabled,id))
  return jsonify(ok=True,review=rowdict(db.execute("SELECT * FROM reviews WHERE id=?",(id,)).fetchone()))
@app.get("/public")
def public_catalog():
 with connect() as db:
  # Catalog metadata deliberately excludes join tokens, codes, answers and reports.
  rows=db.execute("SELECT * FROM reviews WHERE status='shared' AND visibility='public' ORDER BY rowid DESC")
  return jsonify(ok=True,quizzes=[{"id":r["id"],"title":r["title"],"author":r["author"],"count":len(json.loads(r["questions"])),"review_version":r["review_version"],"leaderboard_enabled":bool(r["leaderboard_enabled"])} for r in rows])
@app.post("/public/<id>/join")
def public_join(id):
 if request.headers.get("X-Demo-Role")!="student": return error("Choose Student to join a quiz.",403)
 name=str(payload().get("student","")).strip()[:80]
 if not name: return error("Enter a student name first.")
 with connect() as db:
  row=db.execute("SELECT * FROM reviews WHERE id=? AND status='shared' AND visibility='public'",(id,)).fetchone()
  if not row: return error("This quiz is no longer public or open. Refresh the list.",404)
  token=uuid.uuid4().hex
  db.execute("INSERT INTO joins(id,review_id,student,nickname) VALUES(?,?,?,?)",(token,id,name,nickname(payload(),token)))
  return jsonify(ok=True,join_id=token,review=rowdict(row))
@app.post("/join")
def join():
 data=payload(); code=str(data.get("code","")).strip().upper(); name=str(data.get("student","")).strip()[:80]
 if not name: return error("Enter a student name first.")
 with connect() as db:
  row=db.execute("SELECT * FROM reviews WHERE code=? AND status='shared' AND visibility IN ('code_only','public')",(code,)).fetchone()
  if not row: return error("Code not found, or this quiz is closed.",404)
  token=uuid.uuid4().hex
  db.execute("INSERT INTO joins(id,review_id,student,nickname) VALUES(?,?,?,?)",(token,row["id"],name,nickname(data,token)))
  return jsonify(ok=True,join_id=token,review=rowdict(row))
@app.post("/results")
def result():
 data=payload(); token=str(data.get("join_id","")); attempt=str(data.get("attempt_id",""))[:120]
 mode=data.get("review_mode","battle"); revision=data.get("revision",0)
 if mode not in ("battle","word_bank") or type(revision) is not int or revision<0: return error("Invalid review mode or revision.")
 with connect() as db:
  joined=db.execute("SELECT j.*,r.questions,r.status,r.visibility,r.leaderboard_enabled FROM joins j JOIN reviews r ON r.id=j.review_id WHERE j.id=?",(token,)).fetchone()
  if not joined or not attempt: return error("Join this quiz again before sending results.",403)
  questions=json.loads(joined["questions"])
  names=["correct","answered","score","recall_correct","recall_attempted"]
  fields=[data.get(k) for k in names]
  if any(type(v) is not int or v<0 for v in fields): return error("Invalid result counts.")
  correct,answered,score,rc,ra=fields
  if not 0<=correct<=answered<=len(questions) or answered<1 or rc>ra or ra>10000: return error("Result counts do not match the quiz.")
  if mode=="battle" and (ra>answered or score!=correct*100 or revision!=0): return error("Battle counts do not match the quiz.")
  if mode=="word_bank" and (score!=0 or data.get("won",False)): return error("Word-bank practice does not award battle points or victories.")
  remaining=data.get("remaining_indices")
  if remaining is not None:
   if not isinstance(remaining,list) or any(type(i) is not int or not 0<=i<len(questions) for i in remaining) or len(set(remaining))!=len(remaining) or len(remaining)>answered-correct: return error("Invalid remaining review items.")
  if mode=="word_bank" and remaining is None: return error("Word-bank reports need remaining review items.")
  won=int(bool(data.get("won",False)))
  encoded=json.dumps(remaining)
  old=db.execute("SELECT * FROM results WHERE attempt_id=?",(attempt,)).fetchone()
  if old:
   if old["join_id"]!=token or old["review_mode"]!=mode or any(old[k]!=data[k] for k in ["correct","answered","score"]) or old["won"]!=won: return error("Attempt already exists with a different first-pass result.",409)
   if revision<old["revision"]: return jsonify(ok=True,stale=True)
   if revision==old["revision"]:
    # Legacy battle rows store SQL NULL rather than a JSON null.
    old_remaining=json.loads(old["remaining"]) if old["remaining"] else None
    if old_remaining!=remaining or old["recall_correct"]!=rc or old["recall_attempted"]!=ra: return error("Attempt revision already has different practice results.",409)
    return jsonify(ok=True,duplicate=True)
   old_remaining=json.loads(old["remaining"]) if old["remaining"] else []
   if mode!="word_bank" or rc<old["recall_correct"] or ra<old["recall_attempted"] or not set(remaining).issubset(set(old_remaining)): return error("Practice update is inconsistent.",409)
   db.execute("UPDATE results SET revision=?,recall_correct=?,recall_attempted=?,remaining=?,updated=CURRENT_TIMESTAMP WHERE attempt_id=?",(revision,rc,ra,encoded,attempt))
   return jsonify(ok=True,updated=True)
  db.execute("INSERT INTO results(attempt_id,join_id,correct,answered,score,recall_correct,recall_attempted,won,review_mode,revision,remaining,updated,leaderboard_eligible) VALUES(?,?,?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP,?)",(attempt,token,*fields,won,mode,revision,encoded,int(mode=="battle" and joined["status"]=="shared" and joined["visibility"]=="public" and joined["leaderboard_enabled"])))
  return jsonify(ok=True)
@app.get("/reviews/<id>/results")
def results(id):
 if not teacher(): return error("Teacher role required.",403)
 with connect() as db:
  review=db.execute("SELECT * FROM reviews WHERE id=?",(id,)).fetchone()
  if not review: return error("Reviewer not found.",404)
  questions=json.loads(review["questions"])
  reports=[]
  for raw in db.execute("SELECT results.*,joins.student FROM results JOIN joins ON joins.id=results.join_id WHERE joins.review_id=? ORDER BY results.created DESC, results.rowid DESC",(id,)):
   row=dict(raw)
   indices=json.loads(row.pop("remaining")) if row["remaining"] else None
   row["remaining_concepts"]=None if indices is None else [{"question":questions[i].get("q",""),"answer":questions[i]["choices"][int(questions[i]["correct"])],"page":questions[i].get("page",0)} for i in indices]
   row["completed_at"]=str(row["created"]).replace(" ","T")+"Z"
   row["updated_at"]=str(row["updated"]).replace(" ","T")+"Z"
   reports.append(row)
  return jsonify(ok=True,title=review["title"],review_version=review["review_version"],results=reports)
@app.post("/reviews/<id>/draft")
def teacher_draft(id):
 if not teacher(): return error("Teacher role required.",403)
 data=payload();questions=data.get("questions")
 issue=question_error(questions)
 if issue: return error(issue)
 title=str(data.get("title","")).strip()[:200]
 if not title: return error("A quiz title is required.")
 with connect() as db:
  db.execute("BEGIN IMMEDIATE")
  parent=db.execute("SELECT * FROM reviews WHERE id=?",(id,)).fetchone()
  if not parent:return error("Reviewer not found.",404)
  key=content_key(questions)
  for other in db.execute("SELECT * FROM reviews"):
   if same_student(other["author"],parent["author"]) and content_key(json.loads(other["questions"]))==key:
    return error("These questions were already saved. Change the quiz content before saving a new revision.",409)
  version=db.execute("SELECT MAX(review_version)+1 FROM reviews WHERE root_id=?",(parent["root_id"],)).fetchone()[0]
  new_id=uuid.uuid4().hex
  db.execute("INSERT INTO reviews(id,author,source_id,title,questions,status,visibility,parent_id,root_id,review_version) VALUES(?,?,?,?,?,'pending','private',?,?,?)",(new_id,parent["author"],"teacher-draft-"+new_id,title,json.dumps(questions),id,parent["root_id"],version))
  return jsonify(ok=True,review=rowdict(db.execute("SELECT * FROM reviews WHERE id=?",(new_id,)).fetchone()))
@app.get("/public/<id>/leaderboard")
def leaderboard(id):
 with connect() as db:
  review=db.execute("SELECT * FROM reviews WHERE id=? AND status='shared' AND visibility='public' AND leaderboard_enabled=1",(id,)).fetchone()
  if not review:return error("Leaderboard is disabled or this quiz is no longer public and open.",404)
  best={}
  for raw in db.execute("SELECT results.*,joins.student,joins.nickname FROM results JOIN joins ON results.join_id=joins.id WHERE joins.review_id=? AND results.review_mode='battle' AND results.leaderboard_eligible=1 ORDER BY results.created,results.rowid",(id,)):
   row=dict(raw);key=row["student"].strip().casefold()
   metric=(Fraction(row["correct"],max(1,row["answered"])),row["correct"])
   if key not in best or metric>best[key][0]:best[key]=(metric,row)
  ordered=sorted(best.values(),key=lambda item:(-item[0][0],-item[0][1],item[1]["nickname"].casefold()))
  entries=[];previous=None;rank=0
  for i,(metric,row) in enumerate(ordered):
   if metric!=previous:rank=i+1
   previous=metric
   entries.append({"rank":rank,"nickname":row["nickname"],"correct":row["correct"],"answered":row["answered"],"accuracy_percent":round(100*float(metric[0]),1)})
  return jsonify(ok=True,title=review["title"],review_version=review["review_version"],entries=entries,demo=True)
if __name__ == "__main__":
 print("Quizforge laptop sharing: http://127.0.0.1:"+os.environ.get("QF_SHARING_PORT","8766")+" (local demo roles; not production authentication)",flush=True)
 app.run(host="127.0.0.1",port=int(os.environ.get("QF_SHARING_PORT","8766")),debug=False)
