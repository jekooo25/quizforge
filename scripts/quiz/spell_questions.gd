class_name SpellQuestions
extends RefCounted
## Build cloze cards only from a cited quote containing the answer exactly once.
## The MCQ library and its saved answer order are never modified.
static func escaped(text: String) -> String:
 var result := ""
 for character in text:
  if character in "\\.^$|?*+()[]{}": result += "\\"
  result += character
 return result
static func build(questions: Array) -> Array:
 var cards: Array = []
 var seen: Dictionary = {}
 for source_index in questions.size():
  var value: Variant = questions[source_index]
  if not value is Dictionary: continue
  var question: Dictionary = value
  var choices: Variant = question.get("choices",[])
  var correct: Variant = question.get("correct",-1)
  if not choices is Array or choices.size()!=4 or typeof(correct) not in [TYPE_INT,TYPE_FLOAT]: continue
  if int(correct)!=correct or correct<0 or correct>=4: continue
  correct = int(correct)
  var unique: Dictionary = {}
  var valid := true
  for word: Variant in choices:
   if not word is String or word.strip_edges()=="" or word.length()>60 or word.split(" ",false).size()>6:
    valid = false
    break
   var key: String = word.strip_edges().to_lower()
   if unique.has(key): valid = false
   unique[key] = true
  if not valid: continue
  var answer: String = str(choices[correct]).strip_edges()
  var quote := str(question.get("source_quote","")).strip_edges()
  var page := int(question.get("page",0))
  if quote=="" or page<1 or quote.contains("_____"): continue
  var pattern := RegEx.new()
  if pattern.compile("(?i)(?<![\\p{L}\\p{N}_])"+escaped(answer)+"(?![\\p{L}\\p{N}_])")!=OK: continue
  var matches := pattern.search_all(quote)
  if matches.size()!=1: continue
  var found: RegExMatch = matches[0]
  var prompt := quote.substr(0,found.get_start())+"_____"+quote.substr(found.get_end())
  var key := prompt.to_lower()+"|"+answer.to_lower()
  if seen.has(key): continue
  seen[key] = true
  var bank: Array = []
  for word: String in choices: bank.append(word.strip_edges())
  cards.append({"source_index":source_index,"prompt":prompt,"answer":answer,"bank":bank,"quote":quote,"page":page,"explanation":str(question.get("explanation","")).strip_edges()})
 return cards
