extends Control
## Pixel-art mascot used on the menu and branded screens.

const SPRITE := preload("res://assets/sprites/mascot_cat.png")

@export var scale_factor: float = 1.0
@export var mood: String = "happy"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var art := TextureRect.new()
	art.texture = SPRITE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
