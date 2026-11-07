extends "res://scripts/screens/review_mode_select.gd"
var selected_mode:=""
func _ready() -> void:
 super._ready()
 %Start.pressed.connect(start_selected)
 var quiz:=QuizLibrary.get_quiz(library_id)
 var joined: Dictionary=SharingService.state.joins.get(library_id,{})
 %Meta.text="%d questions · %s" % [quiz.get("questions",[]).size(),str(joined.get("author",Nav.user.get("username","")))]
 if joined.has("review_version"):%Meta.text+=" · v%d" % int(joined.review_version)
 %Progress.text="Last score: "+str(quiz.last_score) if quiz.has("last_score") else "Not started"
 %Status.visible=not loaded
 %Status.text="Choose a review mode, then start when you're ready." if loaded else "This quiz is unavailable. Go back and choose another."
 %BattleReason.text="Answer multiple-choice questions in a creature battle." if not %BattleButton.disabled else "This quiz needs complete questions and answers."
 %SpellReason.text="Complete sentences using a word bank." if not %SpellButton.disabled else "No suitable source sentences in this quiz."
 %BackButton.text="Shared quizzes" if QuizLibrary.is_shared({"id":library_id,"source":quiz.get("source","")}) else "My quizzes"
 if not %BattleButton.disabled:select_mode("battle")
 elif not %SpellButton.disabled:select_mode("word_bank")
 else:%Start.disabled=true
func open_battle() -> void:
 select_mode("battle")
func open_spell() -> void:
 select_mode("word_bank")
func select_mode(mode: String) -> void:
 if mode=="battle" and %BattleButton.disabled:return
 if mode=="word_bank" and %SpellButton.disabled:return
 selected_mode=mode
 %BattleButton.theme_type_variation=&"MyQuizzesActiveTab" if mode=="battle" else &"MyQuizzesTab"
 %SpellButton.theme_type_variation=&"MyQuizzesActiveTab" if mode=="word_bank" else &"MyQuizzesTab"
 %BattleButton.set_pressed_no_signal(mode=="battle")
 %SpellButton.set_pressed_no_signal(mode=="word_bank")
 %Start.text="Start Quiz Battle" if mode=="battle" else "Start Word Bank"
 %Start.disabled=false
func start_selected() -> void:
 if %Start.disabled:return
 if selected_mode=="battle":super.open_battle()
 elif selected_mode=="word_bank":super.open_spell()
