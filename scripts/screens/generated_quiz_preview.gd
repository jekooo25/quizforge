extends "res://scripts/screens/quiz_editor.gd"
var pages: Array=[]
var review_mode:="battle"
func _ready() -> void:
 super._ready()
 %Submit.hide()
 %Save.text="Save quiz"
 get_node("Margin/Column/Header/Title").text="3 / 3 · Preview & edit"
 %Status.text="Review the wording and correct answers. Nothing is saved yet."
 %Source.pressed.connect(show_source)
 dirty=true
func show_source() -> void:
 var lines: Array[String]=[]
 for page: Dictionary in pages:lines.append("Page %d\n%s" % [int(page.get("page",0)),str(page.get("text",""))])
 %Text.text="\n\n".join(lines) if not lines.is_empty() else "No extracted text available. Check the source quote for each question."
 %SourceDialog.popup_centered(Vector2i(mini(720,get_window().size.x-32),mini(360,get_window().size.y-32)))
func save_draft() -> void:
 if busy:return
 var issues:=validate()
 if review_mode=="word_bank" and Spells.build(questions).is_empty():issues.append("No suitable Word Bank sentences remain. Add an exact source quote containing the correct answer once.")
 if not issues.is_empty():%Status.text="\n".join(issues);return
 busy=true
 var id:=QuizLibrary.add(%QuizTitle.text.strip_edges(),questions,"generated")
 if id=="":busy=false;%Status.text="Could not save. Try again.";return
 saved_id=id;dirty=false
 var details: Control=load("res://scenes/QuizDetails.tscn").instantiate();details.library_id=id;Nav.show_screen(details);details.select_mode(review_mode)
func leave() -> void:
 Nav.show_screen(load("res://scenes/UploadReviewer.tscn").instantiate())

func show_question() -> void:
 super.show_question()
 update_style_preview()
func update_style_preview() -> void:
 %StylePreview.visible=review_mode=="word_bank"
 if review_mode=="word_bank":
  var cards:=Spells.build([questions[current]])
  %StylePreview.text="Word Bank: "+str(cards[0].prompt) if not cards.is_empty() else "No safe blank for this question yet. Check its source quote and correct answer."

func mark_dirty(value: Variant=null) -> void:
 super.mark_dirty(value)
 if not loading and not questions.is_empty() and review_mode=="word_bank":
  pull()
  update_style_preview()
