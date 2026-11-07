extends Control

@onready var ember_a: ColorRect = %EmberA
@onready var ember_b: ColorRect = %EmberB
@onready var ember_c: ColorRect = %EmberC
var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	ember_a.modulate.a = 0.45 + 0.45 * (0.5 + 0.5 * sin(_time * 3.1))
	ember_b.modulate.a = 0.35 + 0.55 * (0.5 + 0.5 * sin(_time * 4.2 + 1.7))
	ember_c.modulate.a = 0.40 + 0.50 * (0.5 + 0.5 * sin(_time * 2.6 + 3.0))
