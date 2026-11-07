extends Control
const Cards := preload("res://scripts/quiz/spell_questions.gd")
const Sounds := preload("res://scripts/ui/battle_audio.gd")
@export var library_id := ""
@export_range(1,20) var round_size := 5
@export var auto_advance_delay := 0.8
var eligible: Array = []
var deck: Array = []
var missed: Array = []
var bank: Array = []
var current: Dictionary = {}
var index := -1
var selected := -1
var first_correct := 0
var first_total := 0
var practice_correct := 0
var practice_attempted := 0
var spells := 0
var practice := false
var state := "idle"
var auto_left := 0.0
var sequence := 0
var paused_here := false
var sounds: Node
var report_attempt := ""
var report_revision := 0
@onready var words: Array[Button] = [%WordA,%WordB,%WordC,%WordD]
func _ready() -> void:
 resized.connect(_apply_safe_area)
 _apply_safe_area.call_deferred()
 sounds = Sounds.new()
 add_child(sounds)
 %BackButton.pressed.connect(open_quizzes)
 %UnavailableBack.pressed.connect(open_quizzes)
 %CastButton.pressed.connect(submit)
 %ContinueButton.pressed.connect(advance)
 %Results.replay.connect(start_round)
 %Results.practise.connect(practise_missed)
 %Results.quizzes.connect(open_quizzes)
 %Results.retry_report.connect(queue_report)
 %PauseButton.pressed.connect(pause)
 %PauseMenu.resume_requested.connect(resume)
 %PauseMenu.get_node("%ResumeButton").pressed.connect(resume)
 %PauseMenu.get_node("%ReturnButton").pressed.connect(func() -> void: %PauseMenu.get_node("%LeaveConfirmation").popup_centered())
 %PauseMenu.get_node("%LeaveConfirmation").confirmed.connect(open_quizzes)
 var slider: HSlider = %PauseMenu.get_node("%SoundSlider")
 slider.value = AudioMixer.volume_of(Nav.user,"volume_sfx")
 slider.value_changed.connect(func(value: float) -> void:
  Nav.user.volume_sfx = int(value)
  AudioMixer.set_volume_percent(AudioMixer.SFX,int(value))
  Nav.save_profile())
 for i in words.size(): words[i].pressed.connect(select_word.bind(i))
 var creature := Creature.new("Emberpup",3,1,ShopManager.equipped_body_color(),ShopManager.has_equipped_horns())
 %Emberpup.set_creature(creature)
 var quiz := QuizLibrary.get_quiz(library_id)
 eligible = Cards.build(quiz.get("questions",[]))
 if eligible.is_empty():
  state = "unavailable"
  %Layout.visible = false
  %Unavailable.visible = true
  return
 %QuizTitle.text = str(quiz.get("title","Complete the Spell"))
 start_round()
func start_round() -> void:
 report_attempt = "spell_"+Crypto.new().generate_random_bytes(16).hex_encode()
 report_revision = 0
 sequence += 1
 practice = false
 first_correct = 0
 practice_correct = 0
 practice_attempted = 0
 spells = 0
 deck = eligible.duplicate(true)
 deck.shuffle()
 deck = deck.slice(0,round_size)
 first_total = deck.size()
 begin_deck()
func practise_missed() -> void:
 if missed.is_empty(): return
 sequence += 1
 practice = true
 deck = missed.duplicate(true)
 begin_deck()
func begin_deck() -> void:
 state = "starting"
 missed.clear()
 index = -1
 %Results.visible = false
 %Layout.visible = true
 advance()
func advance() -> void:
 if state not in ["starting","advancing","review"]: return
 index += 1
 if index>=deck.size():
  state = "results"
  %Layout.visible = false
  %Results.visible = true
  if practice: report_revision += 1
  %Results.configure(first_correct,first_total,practice_correct,practice_attempted,missed.size(),eligible.size())
  queue_report()
  return
 current = deck[index]
 bank = current.bank.duplicate()
 bank.shuffle()
 # A practice answer must move from its previous displayed position.
 if practice and current.has("last_position"):
  var previous: int = current.last_position
  var correct := bank.find(current.answer)
  if correct==previous:
   var other := (previous+1)%bank.size()
   var saved: Variant = bank[other]
   bank[other] = bank[correct]
   bank[correct] = saved
 selected = -1
 state = "answering"
 %Progress.text = ("Practice %d/%d" if practice else "%d/%d") % [index+1,deck.size()]
 %ModeLabel.text = "Practice recall · no timer or HP loss" if practice else "Word bank review · no battle rewards"
 %Prompt.text = "Complete the sentence:\n"+str(current.prompt)
 %SourceReview.visible = false
 %Prompt.visible = true
 %WordBank.visible = true
 %CastButton.visible = true
 %CastButton.disabled = true
 %ContinueButton.visible = false
 %Feedback.text = "Tap a word, then cast your spell."
 %Feedback.modulate = Color.WHITE
 %AutoBar.visible = false
 %PowerBar.max_value = max(1,deck.size())
 %PowerBar.value = 0 if index==0 else %PowerBar.value
 %SpellEffect.visible = false
 %BoardScroll.scroll_vertical = 0
 for i in words.size():
  words[i].text = str(bank[i])
  words[i].disabled = false
  words[i].set_pressed_no_signal(false)
  words[i].remove_theme_color_override("font_disabled_color")
  words[i].modulate = Color.WHITE
 words[0].grab_focus()
func select_word(position: int) -> void:
 if state!="answering" or position<0 or position>=bank.size(): return
 selected = position
 %Prompt.text = "Complete the sentence:\n"+str(current.prompt).replace("_____","[ "+str(bank[position])+" ]")
 for i in words.size(): words[i].set_pressed_no_signal(i==position)
 %CastButton.disabled = false
func submit() -> void:
 if state!="answering" or selected<0: return
 state = "casting"
 var run := sequence
 for button in words: button.disabled = true
 %CastButton.disabled = true
 var correct: bool = str(bank[selected])==str(current.answer)
 current["last_position"] = bank.find(current.answer)
 if practice:
  practice_attempted += 1
  if correct: practice_correct += 1
 elif correct: first_correct += 1
 if correct:
  spells += 1
  %SpellCount.text = "Spells: %d" % spells
  %PowerBar.value += 1
  %Feedback.text = "Correct! Spell cast · Next sentence..."
  %Feedback.modulate = Color(0.5,0.95,0.68)
  words[selected].modulate = Color(0.55,1,0.7)
  words[selected].text = "Correct · "+str(bank[selected])
  %Emberpup.play_attack(1)
  %SpellEffect.visible = true
  %SpellEffect.modulate = Color.WHITE
  create_tween().tween_property(%SpellEffect,"modulate:a",0.0,0.55)
  sounds.play_cue("attack")
  await get_tree().create_timer(0.55,false).timeout
  if run!=sequence: return
  state = "auto_advancing"
  auto_left = auto_advance_delay
  %AutoBar.max_value = auto_advance_delay
  %AutoBar.value = auto_left
  %AutoBar.visible = true
  return
 missed.append(current.duplicate(true))
 %Feedback.text = "Not quite. Read the answer, then continue when ready."
 %Feedback.modulate = Color(1,0.72,0.55)
 sounds.play_cue("hit")
 %WordBank.visible = false
 %CastButton.visible = false
 %Prompt.visible = false
 %SourceReview.visible = true
 %CorrectAnswer.text = "Correct answer: "+str(current.answer)
 %FullSentence.text = str(current.quote)
 %Explanation.text = "Why: "+str(current.explanation) if str(current.explanation)!="" else "The saved reviewer gives the completed sentence above. No additional explanation was saved."
 %SourceLabel.text = "Reviewer source · page %d" % int(current.page)
 %BoardScroll.scroll_vertical = 0
 state = "review"
 %ContinueButton.visible = true
 %ContinueButton.grab_focus()
func _process(delta: float) -> void:
 if paused_here or state!="auto_advancing": return
 auto_left -= delta
 %AutoBar.value = auto_left
 if auto_left<=0:
  state = "advancing"
  advance()
func pause() -> void:
 if state in ["results","unavailable"]: return
 paused_here = true
 %PauseMenu.visible = true
 get_tree().paused = true
 %PauseMenu.get_node("%ResumeButton").grab_focus()
func resume() -> void:
 get_tree().paused = false
 paused_here = false
 %PauseMenu.visible = false
func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  pause()
func _notification(what: int) -> void:
 if what==NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
  if paused_here: resume()
  else: pause()
func open_quizzes() -> void:
 if paused_here: resume()
 Nav.show_screen(load("res://scenes/my_quizzes.tscn").instantiate())
func _exit_tree() -> void:
 if paused_here: get_tree().paused = false

func _apply_safe_area() -> void:
 if OS.get_name()!="Android": return
 var safe := DisplayServer.get_display_safe_area()
 var window_size := Vector2(DisplayServer.window_get_size())
 if not safe.has_area() or window_size.x<=0 or window_size.y<=0: return
 var ratio := size/window_size
 %Layout.offset_left = 24+maxf(0,safe.position.x)*ratio.x
 %Layout.offset_right = -24-maxf(0,window_size.x-safe.end.x)*ratio.x
 %Layout.offset_top = 8+maxf(0,safe.position.y)*ratio.y
 %Layout.offset_bottom = -8-maxf(0,window_size.y-safe.end.y)*ratio.y

func queue_report() -> void:
 if state!="results": return
 var indices: Array = []
 for card: Dictionary in missed: indices.append(int(card.source_index))
 var shared: bool = SharingService.state.joins.has(library_id)
 var queued := false
 if shared:
  queued = SharingService.queue_result(library_id,report_attempt,{"review_mode":"word_bank","revision":report_revision,"correct":first_correct,"answered":first_total,"score":0,"won":false,"recall_correct":practice_correct,"recall_attempted":practice_attempted,"remaining_indices":indices})
 %Results.set_delivery(shared,queued)
