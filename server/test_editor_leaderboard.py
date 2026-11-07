import os,tempfile,unittest,uuid
from pathlib import Path
_tmp=tempfile.TemporaryDirectory();os.environ['QF_SHARING_DB']=str(Path(_tmp.name)/'test.sqlite3')
import sharing_server as s
class EditorBoardTests(unittest.TestCase):
 def setUp(self):
  with s.connect() as db:
   for table in ["results","joins","reviews"]: db.execute("DELETE FROM "+table)
  self.c=s.app.test_client();self.t={'X-Demo-Role':'teacher'};self.student={'X-Demo-Role':'student'}
  self.questions=[{'q':f'Question {i}?','choices':['A','B','C','D'],'correct':0} for i in range(5)]
  self.source=uuid.uuid4().hex
  self.body={'author':'Creator','source_id':self.source,'title':'Versioned quiz','questions':self.questions}
  self.original=self.c.post('/reviews',json=self.body,headers=self.student).json['review'];self.id=self.original['id']
  self.c.post(f'/reviews/{self.id}/status',json={'status':'approved'},headers=self.t)
  self.public=self.publish(self.id,True).json['review']
 def publish(self,id,enabled):return self.c.post(f'/reviews/{id}/publish',json={'visibility':'public','leaderboard_enabled':enabled},headers=self.t)
 def join(self,student,nickname):return self.c.post(f'/public/{self.id}/join',json={'student':student,'nickname':nickname},headers=self.student).json['join_id']
 def result(self,token,correct,total=5,**extra):
  data={'join_id':token,'attempt_id':uuid.uuid4().hex,'correct':correct,'answered':total,'score':correct*100,'recall_correct':0,'recall_attempted':0,'won':True}
  data.update(extra);reply=self.c.post('/results',json=data);self.assertEqual(reply.status_code,200,reply.json);return data
 def board(self):return self.c.get(f'/public/{self.id}/leaderboard').json['entries']
 def test_student_revision_needs_reapproval(self):
  changed=[dict(q) for q in self.questions];changed[0]['q']='Revised question?'
  body=dict(self.body,source_id=uuid.uuid4().hex,parent_source_id=self.source,questions=changed)
  revision=self.c.post('/reviews',json=body,headers=self.student).json['review']
  self.assertEqual((revision['status'],revision['visibility'],revision['review_version']),('pending','private',2))
  self.assertIsNone(revision['code']);self.assertEqual(revision['parent_id'],self.id)
  self.assertEqual(self.publish(revision['id'],True).status_code,409)
  self.assertEqual(self.c.post(f"/reviews/{revision['id']}/publish",json={'visibility':'public'},headers=self.student).status_code,403)
  self.c.post(f"/reviews/{revision['id']}/status",json={'status':'approved'},headers=self.t)
  self.assertTrue(self.publish(revision['id'],True).json['ok'])
  rows=self.c.get('/reviews',headers=self.t).json['reviews'];old=next(r for r in rows if r['id']==self.id)
  self.assertEqual(old['questions'],self.questions);self.assertEqual(old['code'],self.public['code'])
 def test_teacher_edit_creates_private_version(self):
  response=self.c.post(f'/reviews/{self.id}/draft',json={'title':'Teacher revision','questions':[dict(q,explanation='Added teacher explanation.') for q in self.questions]},headers=self.t)
  self.assertEqual(response.status_code,200,response.json)
  row=response.json['review'];self.assertEqual(row['review_version'],2);self.assertEqual(row['visibility'],'private');self.assertEqual(row['status'],'pending')
  self.assertEqual(self.publish(row['id'],True).status_code,409)
  self.assertEqual(self.c.post(f'/reviews/{self.id}/draft',json={'title':'No','questions':self.questions},headers=self.student).status_code,403)
 def test_best_scores_shared_ranks_and_nicknames(self):
  a=self.join('Student A full name','Falcon');b=self.join('Student B full name','Otter');c=self.join('Student C','Lynx')
  self.result(a,3);self.result(a,5);self.result(b,5);self.result(c,4)
  board=self.board();self.assertEqual([r['rank'] for r in board],[1,1,3]);self.assertEqual(len(board),3)
  self.assertEqual(board[0]['accuracy_percent'],100);self.assertEqual({r['nickname'] for r in board},{'Falcon','Otter','Lynx'})
  self.assertTrue(all(set(r)=={'rank','nickname','correct','answered','accuracy_percent'} for r in board))
 def test_tie_break_correct_count_not_time(self):
  a=self.join('A','One');b=self.join('B','Two')
  self.result(a,1,1);self.result(b,5,5)
  self.assertEqual([r['nickname'] for r in self.board()],['Two','One'])
 def test_excludes_wordbank_disabled_and_closed_rounds(self):
  token=self.join('A','Falcon')
  self.result(token,1,2,score=0,review_mode='word_bank',won=False,remaining_indices=[0])
  self.assertEqual(self.board(),[])
  self.result(token,3)
  self.publish(self.id,False)
  self.result(token,5)
  self.assertEqual(self.c.get(f'/public/{self.id}/leaderboard').status_code,404)
  self.publish(self.id,True);self.assertEqual(self.board()[0]['correct'],3)
  self.c.post(f'/reviews/{self.id}/status',json={'status':'approved'},headers=self.t)
  self.result(token,5)
  self.assertEqual(self.c.get(f'/public/{self.id}/leaderboard').status_code,404)
  self.publish(self.id,True);self.assertEqual(self.board()[0]['correct'],3)
 def test_versions_have_separate_boards(self):
  self.result(self.join('A','Falcon'),5)
  revision=self.c.post(f'/reviews/{self.id}/draft',json={'title':'New','questions':[dict(q,explanation='New explanation.') for q in self.questions]},headers=self.t).json['review']
  self.c.post(f"/reviews/{revision['id']}/status",json={'status':'approved'},headers=self.t);self.publish(revision['id'],True)
  self.assertEqual(self.c.get(f"/public/{revision['id']}/leaderboard").json['entries'],[])
  self.assertEqual(len(self.board()),1)
if __name__=='__main__':unittest.main()
