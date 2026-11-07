extends Control
@export var question: Dictionary={}
@export var battle_count:=0
@export var spell_count:=0
func _ready() -> void:
 resized.connect(_apply_safe_area)
 _apply_safe_area.call_deferred()
 %Close.pressed.connect(queue_free)
 %Counts.text="Quiz Battle: %d questions · Word Bank: %d supported sentences" % [battle_count,spell_count]
 %Question.text=str(question.get("q",""))
 var choices: Array=question.get("choices",[])
 var buttons: Array[Button]=[%A,%B,%C,%D]
 for i in 4:
  buttons[i].text=str(choices[i])
  if i==int(question.get("correct",-1)):buttons[i].text="Correct: "+str(choices[i])
 var cards:=preload("res://scripts/quiz/spell_questions.gd").build([question])
 %Spell.text="Word Bank preview: "+str(cards[0].prompt) if not cards.is_empty() else "This question has no safe word-bank blank. Save a source quote and page with the answer appearing exactly once."

func _apply_safe_area() -> void:
 if OS.get_name()!="Android":return
 var safe:=DisplayServer.get_display_safe_area()
 var dimensions:=Vector2(DisplayServer.window_get_size())
 if not safe.has_area() or dimensions.x<=0 or dimensions.y<=0:return
 var ratio:=size/dimensions
 var margin: MarginContainer=$Margin
 margin.offset_left=24+maxf(0,safe.position.x)*ratio.x
 margin.offset_right=-24-maxf(0,dimensions.x-safe.end.x)*ratio.x
 margin.offset_top=12+maxf(0,safe.position.y)*ratio.y
 margin.offset_bottom=-12-maxf(0,dimensions.y-safe.end.y)*ratio.y

func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  queue_free()
