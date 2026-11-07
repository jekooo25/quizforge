extends PanelContainer
func local_date(value: String) -> String:
 if value.length()<19: return "Not recorded"
 var timestamp := int(Time.get_unix_time_from_datetime_string(value.replace("Z","")))
 return Time.get_datetime_string_from_unix_time(timestamp+8*3600).replace("T"," ")+" (UTC+8)"
func configure(report: Dictionary) -> void:
 var word_bank: bool = report.get("review_mode","battle")=="word_bank"
 var correct := int(report.get("correct",0))
 var answered := int(report.get("answered",0))
 %Student.text = str(report.get("student","Student"))
 %Mode.text = "COMPLETE THE SPELL" if word_bank else "QUIZ BATTLE"
 %FirstPass.text = "First attempt: %d/%d · %d%% accuracy" % [correct,answered,int(round(100.0*correct/maxi(1,answered)))]
 %Recall.text = "Practice recall: %d/%d checks" % [int(report.get("recall_correct",0)),int(report.get("recall_attempted",0))]
 %Score.text = "Word-bank practice · no battle points" if word_bank else "Battle score: %d · %s" % [int(report.get("score",0)),"Victory" if report.get("won",false) else "Defeat"]
 %Completed.text = "Completed: "+local_date(str(report.get("completed_at",report.get("created",""))))
 %Updated.visible = word_bank and int(report.get("revision",0))>0
 %Updated.text = "Practice updated: "+local_date(str(report.get("updated_at","")))
 var concepts: Variant = report.get("remaining_concepts",null)
 var lines: Array[String] = []
 if concepts==null:
  lines.append("Per-question review details were not recorded for this earlier attempt.")
 elif concepts is Array and concepts.is_empty():
  lines.append("None remaining in this round. Revisit the topic later to check retention.")
 elif concepts is Array:
  for concept: Dictionary in concepts:
   var page := int(concept.get("page",0))
   lines.append("• %s%s\n  %s" % [str(concept.get("answer",""))," · page %d" % page if page>0 else "",str(concept.get("question",""))])
 %Remaining.text = "Still needs review:\n"+"\n".join(lines)
