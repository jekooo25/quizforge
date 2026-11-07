import json, tempfile, unittest, uuid
from pathlib import Path
import sharing_server as s
class DuplicateTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.old=s.DB;s.DB=str(Path(self.tmp.name)/'isolated.sqlite3')
  self.c=s.app.test_client();self.student={'X-Demo-Role':'student'};self.teacher={'X-Demo-Role':'teacher'}
  self.body={'author':'Same Student','source_id':'original','title':'Space','questions':[{'q':'Which planet is red?','choices':['Mars','Venus','Earth','Saturn'],'correct':0}]}
 def tearDown(self):s.DB=self.old;self.tmp.cleanup()
 def submit(self,**kwargs):return self.c.post('/reviews',json=dict(self.body,**kwargs),headers=self.student).json
 def approve(self,id):return self.c.post('/reviews/'+id+'/status',json={'status':'approved'},headers=self.teacher)
 def test_new_id_identical_content_returns_original(self):
  first=self.submit()['review'];again=self.submit(source_id='copied',title='Renamed copy')
  self.assertTrue(again['duplicate']);self.assertEqual(first['id'],again['review']['id'])
  self.assertEqual(len(self.c.get('/reviews',headers=self.teacher).json['reviews']),1)
 def test_repeated_approval_rejected(self):
  id=self.submit()['review']['id'];self.assertEqual(self.approve(id).status_code,200);self.assertEqual(self.approve(id).status_code,409)
 def test_returned_unchanged_not_resubmitted(self):
  id=self.submit()['review']['id'];self.c.post('/reviews/'+id+'/status',json={'status':'changes'},headers=self.teacher)
  again=self.submit();self.assertTrue(again['duplicate']);self.assertEqual(again['review']['status'],'changes')
 def test_real_revision_and_other_student_allowed(self):
  id=self.submit()['review']['id'];self.approve(id)
  changed=[dict(self.body['questions'][0],explanation='Mars has iron oxide.')]
  revision=self.submit(source_id='edited',parent_review_id=id,questions=changed)['review']
  self.assertNotEqual(id,revision['id']);self.assertEqual(revision['review_version'],2);self.assertEqual(self.approve(revision['id']).status_code,200)
  other=self.submit(author='Another Student')['review'];self.assertNotEqual(id,other['id'])
 def test_legacy_duplicates_are_preserved_but_not_approved_twice(self):
  id=self.submit()['review']['id'];duplicate=uuid.uuid4().hex
  with s.connect() as db:
   db.execute("INSERT INTO reviews(id,author,source_id,title,questions,status,root_id) VALUES(?,?,?,?,?,'pending',?)",(duplicate,'Same Student','old-copy','Copy',json.dumps(self.body['questions']),duplicate))
  self.assertEqual(self.approve(id).status_code,200);self.assertEqual(self.approve(duplicate).status_code,409)
  rows=self.c.get('/reviews',headers=self.teacher).json['reviews'];self.assertEqual(len(rows),2)
  self.assertEqual(next(r for r in rows if r['id']==duplicate)['duplicate_of'],id)
 def test_teacher_cannot_make_unchanged_revision(self):
  id=self.submit()['review']['id'];self.approve(id)
  response=self.c.post('/reviews/'+id+'/draft',json={'title':'Renamed','questions':self.body['questions']},headers=self.teacher)
  self.assertEqual(response.status_code,409)
if __name__=='__main__':unittest.main()
