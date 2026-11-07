import os,tempfile,sqlite3,unittest
from pathlib import Path
_folder=tempfile.TemporaryDirectory()
os.environ['QF_SHARING_DB']=str(Path(_folder.name)/'visibility.sqlite3')
import sharing_server as s
class VisibilityTests(unittest.TestCase):
 def setUp(self):
  with s.connect() as db:
   for table in ["results","joins","reviews"]: db.execute("DELETE FROM "+table)
  import uuid
  self.c=s.app.test_client();self.t={'X-Demo-Role':'teacher'};self.student={'X-Demo-Role':'student'}
  body={'author':'Demo Student','source_id':uuid.uuid4().hex,'title':'Visibility test','questions':[{'q':'What is 2+2?','choices':['1','2','3','4'],'correct':3}],'visibility':'public'}
  self.row=self.c.post('/reviews',json=body,headers=self.student).json['review'];self.id=self.row['id']
 def publish(self,visibility):return self.c.post(f'/reviews/{self.id}/publish',json={'visibility':visibility},headers=self.t)
 def approve(self):return self.c.post(f'/reviews/{self.id}/status',json={'status':'approved'},headers=self.t)
 def catalog(self):return self.c.get('/public').json['quizzes']
 def test_private_default_and_approval(self):
  self.assertEqual(self.row['visibility'],'private');self.assertIsNone(self.row['code'])
  self.assertNotIn(self.id,[r['id'] for r in self.catalog()])
  self.assertEqual(self.publish('public').status_code,409)
  self.assertEqual(self.c.post(f'/reviews/{self.id}/publish',json={'visibility':'public'},headers=self.student).status_code,403)
  self.approve();self.assertEqual(self.publish('unknown').status_code,400)
 def test_code_only_and_public(self):
  self.approve();row=self.publish('code_only').json['review']
  self.assertEqual(row['status'],'shared');self.assertEqual(len(row['code']),6)
  self.assertNotIn(self.id,[r['id'] for r in self.catalog()])
  self.assertEqual(self.c.post(f'/public/{self.id}/join',json={'student':'Other'},headers=self.student).status_code,404)
  self.assertTrue(self.c.post('/join',json={'student':'Other','code':row['code']}).json['ok'])
  self.publish('public');public=next(r for r in self.catalog() if r['id']==self.id)
  self.assertEqual(set(public),{'id','title','author','count','review_version','leaderboard_enabled'})
  self.assertTrue(self.c.post(f'/public/{self.id}/join',json={'student':'Other'},headers=self.student).json['ok'])
  self.publish('code_only')
  self.assertNotIn(self.id,[r['id'] for r in self.catalog()])
  self.assertEqual(self.c.post(f'/public/{self.id}/join',json={'student':'Other'},headers=self.student).status_code,404)
 def test_private_and_close_preserve_results(self):
  self.approve();row=self.publish('public').json['review']
  token=self.c.post('/join',json={'student':'Other','code':row['code']}).json['join_id']
  self.publish('private')
  self.assertNotIn(self.id,[r['id'] for r in self.catalog()])
  self.assertEqual(self.c.post('/join',json={'student':'New','code':row['code']}).status_code,404)
  data={'join_id':token,'attempt_id':self.id,'correct':1,'answered':1,'score':100,'recall_correct':0,'recall_attempted':0,'won':True}
  self.assertTrue(self.c.post('/results',json=data).json['ok'])
  self.publish('public')
  self.c.post(f'/reviews/{self.id}/status',json={'status':'approved'},headers=self.t)
  self.assertNotIn(self.id,[r['id'] for r in self.catalog()])
  self.assertEqual(self.c.post('/join',json={'student':'New','code':row['code']}).status_code,404)
  self.assertEqual(len(self.c.get(f'/reviews/{self.id}/results',headers=self.t).json['results']),1)
 def test_legacy_migration_never_makes_quizzes_public(self):
  original=s.DB;legacy=str(Path(_folder.name)/'legacy.sqlite3')
  db=sqlite3.connect(legacy)
  db.execute('CREATE TABLE reviews(id TEXT PRIMARY KEY, author TEXT, source_id TEXT, title TEXT, questions TEXT,status TEXT,code TEXT UNIQUE)')
  db.execute("INSERT INTO reviews VALUES('old','A','one','Old','[]','shared','ABC123')")
  db.execute("INSERT INTO reviews VALUES('draft','A','two','Draft','[]','approved',NULL)")
  db.commit();db.close()
  try:
   s.DB=legacy
   with s.connect() as migrated:
    self.assertEqual(migrated.execute("SELECT visibility FROM reviews WHERE id='old'").fetchone()[0],'code_only')
    self.assertEqual(migrated.execute("SELECT visibility FROM reviews WHERE id='draft'").fetchone()[0],'private')
   self.assertEqual(self.catalog(),[])
  finally:s.DB=original
if __name__=='__main__':unittest.main()
