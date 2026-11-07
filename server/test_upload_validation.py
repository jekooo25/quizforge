import io, unittest
from app import app
class UploadValidation(unittest.TestCase):
 def setUp(self):self.c=app.test_client()
 def send(self,name,content=b'Example',**fields):return self.c.post('/generate',data=dict(file=(io.BytesIO(content),name),provider='offline',**fields),content_type='multipart/form-data')
 def test_empty(self):self.assertEqual(self.send('a.txt',b'').json['code'],'empty')
 def test_short(self):self.assertEqual(self.send('a.txt',b'Short source.').json['code'],'insufficient')
 def test_unsupported(self):self.assertEqual(self.send('a.docx').json['code'],'unsupported')
 def test_bad_count(self):
  for count in ['bad','0','41']:
   self.assertEqual(self.send('a.txt',count=count).status_code,400)
 def test_large(self):self.assertEqual(self.send('a.txt',b'a'*(20*1024*1024+1)).status_code,413)
if __name__=='__main__':unittest.main()
