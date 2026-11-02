class_name Mascot
extends Control
## The mascot: the pixel-art sprite when it exists, the code-drawn cat if not.
## Screens call Mascot.create() so the art can be swapped without touching them.

const IMAGE_PATH := "res://assets/sprites/mascot_cat.png"


static func create() -> Control:
	if ResourceLoader.exists(IMAGE_PATH):
		var tex: Texture2D = load(IMAGE_PATH)
		if tex != null:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return rect
	return load("res://scripts/ui/cat_mascot.gd").new()
