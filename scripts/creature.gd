class_name Creature
extends RefCounted
## A battler: a name, some hit points, and the damage it deals on a clean hit.

var display_name: String
var max_hp: int
var hp: int
var atk: int
var color: Color
var horns: bool


func _init(p_name: String, p_hp: int, p_atk: int, p_color: Color, p_horns := false) -> void:
	display_name = p_name
	max_hp = p_hp
	hp = p_hp
	atk = p_atk
	color = p_color
	horns = p_horns


func is_down() -> bool:
	return hp <= 0


## Returns the damage actually dealt (clamped at 0 HP).
func take_damage(amount: int) -> int:
	var before := hp
	hp = maxi(0, hp - amount)
	return before - hp


func hp_ratio() -> float:
	return float(hp) / float(max_hp)
