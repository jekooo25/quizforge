import os, tempfile, unittest
from pathlib import Path
_temp = tempfile.TemporaryDirectory()
os.environ["QF_SHARING_DB"] = str(Path(_temp.name)/"test.sqlite")
from sharing_server import app
class SharingTest(unittest.TestCase):
 def test_workflow(self):
  client=app.test_client(); teacher={"X-Demo-Role":"teacher"}; student={"X-Demo-Role":"student"}
  questions=[{"q":"What is 2+2?","choices":["1","2","3","4"],"correct":3}]
  submission={"author":"Laptop Student","source_id":"fixture","title":"Math demo","questions":questions}
  self.assertEqual(client.get("/reviews").status_code,403)
  first=client.post("/reviews",json=submission,headers=student).json
  self.assertTrue(first["ok"]); id=first["review"]["id"]
  self.assertTrue(client.post("/reviews",json=submission,headers=student).json["duplicate"])
  self.assertEqual(client.post(f"/reviews/{id}/status",json={"status":"shared"},headers=teacher).status_code,409)
  self.assertEqual(client.post(f"/reviews/{id}/status",json={"status":"approved"},headers=student).status_code,403)
  self.assertTrue(client.post(f"/reviews/{id}/status",json={"status":"approved"},headers=teacher).json["ok"])
  published=client.post(f"/reviews/{id}/status",json={"status":"shared"},headers=teacher).json
  code=published["review"]["code"]; self.assertEqual(len(code),6)
  self.assertEqual(client.post("/join",json={"code":"BADBAD","student":"S"}).status_code,404)
  joined=client.post("/join",json={"code":code.lower(),"student":"Laptop Student"}).json
  self.assertEqual(joined["review"]["questions"],questions)
  result={"join_id":joined["join_id"],"attempt_id":"attempt-one","correct":1,"answered":1,"score":100,"recall_correct":0,"recall_attempted":0,"won":True}
  self.assertTrue(client.post("/results",json=result).json["ok"])
  self.assertTrue(client.post("/results",json=result).json["duplicate"])
  report=client.get(f"/reviews/{id}/results",headers=teacher).json["results"]
  self.assertEqual(len(report),1); self.assertEqual(report[0]["student"],"Laptop Student")
  bad=dict(result,score=900); self.assertEqual(client.post("/results",json=bad).status_code,400)
  self.assertTrue(client.post(f"/reviews/{id}/status",json={"status":"approved"},headers=teacher).json["ok"])
  self.assertEqual(client.post("/join",json={"code":code,"student":"S"}).status_code,404)
  # Data survives a new application client/connection.
  self.assertEqual(len(app.test_client().get(f"/reviews/{id}/results",headers=teacher).json["results"]),1)
  # Closing sharing does not discard a previously joined student's queued result.
  result["attempt_id"]="late-attempt"
  self.assertTrue(client.post("/results",json=result).json["ok"])
if __name__ == "__main__": unittest.main()
