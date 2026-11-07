extends Control

signal return_to_menu

@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(func() -> void: return_to_menu.emit())
