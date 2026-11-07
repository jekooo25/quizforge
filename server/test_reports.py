import os, tempfile, sqlite3, unittest
from pathlib import Path
_folder=tempfile.TemporaryDirectory()
os.environ['QF_SHARING_DB']=str(Path(_folder.name)/'reports.sqlite3')
import sharing_server as server
class ReportTests(unittest.TestCase):
 def setUp(self):
  with server.connect() as db:
   for table in ["results","joins","reviews"]: db.execute("DELETE FROM "+table)
  self.client=server.app.test_client(); self.teacher={'X-Demo-Role':'teacher'}
  questions=[{'q':'Which term makes an equation true?','choices':['Solution','Variable','Coefficient','Equation'],'correct':0,'source_quote':'Solution: a number that makes an equation true.','page':6}, {'q':'Which term represents an unknown number?','choices':['Solution','Variable','Coefficient','Equation'],'correct':1,'source_quote':'Variable: a letter representing an unknown number.','page':6}]
  import uuid
  body={'author':'Report Student','source_id':uuid.uuid4().hex,'title':'Algebra review','questions':questions}
  self.id=self.client.post('/reviews',json=body,headers={'X-Demo-Role':'student'}).json['review']['id']
  self.client.post(f'/reviews/{self.id}/status',json={'status':'approved'},headers=self.teacher)
  code=self.client.post(f'/reviews/{self.id}/status',json={'status':'shared'},headers=self.teacher).json['review']['code']
  self.join=self.client.post('/join',json={'code':code,'student':'Report Student'}).json['join_id']
 def report(self,**changes):
  result={'join_id':self.join,'attempt_id':self.id,'review_mode':'word_bank','revision':0,'correct':1,'answered':2,'score':0,'recall_correct':0,'recall_attempted':0,'won':False,'remaining_indices':[0]}
  result.update(changes); return result
 def test_wordbank_revision(self):
  first=self.report()
  self.assertTrue(self.client.post('/results',json=first).json['ok'])
  self.assertTrue(self.client.post('/results',json=first).json['duplicate'])
  updated=self.report(revision=1,recall_correct=1,recall_attempted=1,remaining_indices=[])
  self.assertTrue(self.client.post('/results',json=updated).json['updated'])
  self.assertTrue(self.client.post('/results',json=first).json['stale'])
  rows=self.client.get(f'/reviews/{self.id}/results',headers=self.teacher).json['results']
  self.assertEqual(len(rows),1)
  self.assertEqual((rows[0]['correct'],rows[0]['answered'],rows[0]['recall_correct']),(1,2,1))
  self.assertEqual(rows[0]['remaining_concepts'],[])
  self.assertEqual(rows[0]['review_mode'],'word_bank')
  self.assertTrue(rows[0]['completed_at'].endswith('Z'))
 def test_details_and_separate_modes(self):
  self.client.post('/results',json=self.report())
  battle=self.report(attempt_id=self.id+'-battle',review_mode='battle',correct=1,answered=1,score=100,won=True,remaining_indices=[])
  self.assertTrue(self.client.post('/results',json=battle).json['ok'])
  rows=self.client.get(f'/reviews/{self.id}/results',headers=self.teacher).json['results']
  self.assertEqual(len(rows),2)
  word=next(r for r in rows if r['review_mode']=='word_bank')
  self.assertEqual(word['remaining_concepts'][0]['answer'],'Solution')
  self.assertEqual(word['remaining_concepts'][0]['page'],6)
  self.assertEqual(self.client.get(f'/reviews/{self.id}/results').status_code,403)
 def test_validation(self):
  for changes in [{'review_mode':'unknown'},{'remaining_indices':[9]},{'remaining_indices':[0,0]},{'score':100},{'recall_correct':2,'recall_attempted':1},{'remaining_indices':None},{'revision':True}]:
   with self.subTest(changes=changes): self.assertEqual(self.client.post('/results',json=self.report(**changes)).status_code,400)
  self.client.post('/results',json=self.report())
  self.assertEqual(self.client.post('/results',json=self.report(correct=2,remaining_indices=[])).status_code,409)
  self.assertEqual(self.client.post('/results',json=self.report(recall_attempted=1)).status_code,409)
 def test_repeated_practice_can_exceed_first_attempt_count(self):
  self.assertTrue(self.client.post('/results',json=self.report(revision=4,recall_correct=1,recall_attempted=4,remaining_indices=[])).json['ok'])
 def test_additive_legacy_migration(self):
  original=server.DB
  legacy=str(Path(_folder.name)/'legacy.sqlite3')
  db=sqlite3.connect(legacy)
  db.executescript("CREATE TABLE results(attempt_id TEXT PRIMARY KEY, join_id TEXT, correct INTEGER, answered INTEGER, score INTEGER, recall_correct INTEGER, recall_attempted INTEGER, won INTEGER, created TEXT DEFAULT CURRENT_TIMESTAMP); INSERT INTO results(attempt_id,join_id,correct,answered,score,recall_correct,recall_attempted,won) VALUES('legacy','join',1,1,100,0,0,1);")
  db.commit(); db.close()
  try:
   server.DB=legacy
   with server.connect() as migrated:
    row=migrated.execute("SELECT * FROM results WHERE attempt_id='legacy'").fetchone()
    self.assertEqual(row['score'],100)
    self.assertEqual(row['review_mode'],'battle')
    self.assertEqual(row['revision'],0)
    self.assertIsNone(row['remaining'])
   with server.connect() as reopened: self.assertEqual(reopened.execute('SELECT COUNT(*) FROM results').fetchone()[0],1)
  finally: server.DB=original
if __name__=='__main__': unittest.main()
