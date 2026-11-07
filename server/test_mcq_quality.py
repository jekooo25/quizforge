import sys, unittest, io
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import qfgen
class GenerationQuality(unittest.TestCase):
 def item(self,**changes):
  row={"question":"Which term matches this description: a number that makes an equation true?", "choices":["Variable","Coefficient","Solution","Expression"],"answer":2,"explanation":"A solution makes the equation true when substituted.","source_quote":"A solution makes an equation true.","page":6}
  row.update(changes); return row
 def test_good_mcq(self):
  self.assertEqual(len(qfgen._clean_questions({"questions":[self.item()]})),1)
 def test_reject_broken_questions(self):
  for changes in [
   {"question":"Fill in the blank: _____: a number that makes an equation true is a solution."},
   {"question":"What is the ----- of this equation?"},
   {"question":"Which term describes a solution that makes an equation true?"},
   {"choices":["Solution"," solution ","Expression","Variable"]},
   {"choices":["A","B","C","All of the above"]},
   {"choices":["A","B",3,"D"]},{"answer":True},{"explanation":""},
   {"source_quote":""},{"page":None},{"page":0}]:
   with self.subTest(changes=changes):
    self.assertEqual(qfgen._clean_questions({"questions":[self.item(**changes)]}),[])
 def test_math_not_overfiltered(self):
  self.assertEqual(len(qfgen._clean_questions({"questions":[self.item(question="What is 2 + 2?",choices=["1","2","3","4"],answer=3)]})),1)
 def test_source_checks(self):
  question=self.item()
  self.assertEqual(qfgen._ground_questions([question],[{"page":6,"text":question["source_quote"]}]),[question])
  self.assertEqual(qfgen._ground_questions([question],[{"page":6,"text":"Unrelated source."}]),[])
  self.assertEqual(qfgen._ground_questions([question],[{"page":7,"text":question["source_quote"]}]),[])
 def test_offline_is_direct_and_supported(self):
  text="""Solution: A number that makes an equation true.
Variable: A letter used to represent an unknown number.
Coefficient: A number multiplied by a variable in an algebraic term.
Expression: A combination of numbers and operations without an equality sign.
Equation: A statement that two mathematical expressions are equal.
Solution: A number that makes an equation true is a solution to that equation."""
  pages=[{"page":6,"text":text}]
  questions=qfgen.offline_questions(pages,10)
  self.assertGreaterEqual(len(questions),4)
  self.assertLessEqual(len(questions),5)
  for question in questions:
   self.assertNotIn("_____",question["question"])
   self.assertNotIn(question["choices"][question["answer"]].casefold(),question["question"].casefold())
   self.assertIn(question["source_quote"],text)
   self.assertEqual(len(set(question["choices"])),4)
  self.assertEqual(qfgen.offline_questions([{ "page":1,"text":"Not enough material."}],10),[])
 def test_upload_endpoint(self):
  from app import app
  text = """Solution: A number that makes an equation true.
Variable: A letter used to represent an unknown number.
Coefficient: A number multiplied by a variable in an algebraic term.
Expression: A combination of numbers and operations without an equality sign.
Equation: A statement that two mathematical expressions are equal."""
  reply = app.test_client().post("/generate",data={"provider":"offline","count":"5","file":(io.BytesIO(text.encode()),"algebra.txt")},content_type="multipart/form-data")
  self.assertEqual(reply.status_code,200)
  questions=reply.json["questions"]
  self.assertGreaterEqual(len(questions),4)
  self.assertEqual(reply.json["source"]["provider"],"offline")
  for q in questions:
   self.assertTrue(q["question"].startswith("Which term"))
   self.assertIn(q["source_quote"],text)
   self.assertEqual(q["page"],1)
   self.assertEqual(len(q["choices"]),4)
 def test_prompt(self):
  prompt=qfgen.build_prompt([{"page":6,"text":"A solution makes an equation true."}],5)
  self.assertIn("not fill-in-the-blank",prompt)
  self.assertIn("Do not reveal",prompt)
if __name__=="__main__": unittest.main()
