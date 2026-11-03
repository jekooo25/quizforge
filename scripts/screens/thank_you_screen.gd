extends Control
## The farewell: mascot on its book, one line of thanks, then the app closes.

const SPRITE := preload("res://assets/sprites/mascot_cat.png")

const BACKDROP := Color(0.502, 0.502, 0.502)
const GOLD := Color(0.890, 0.620, 0.160)

const HOLD_SECONDS := 2.2


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = BACKDROP
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)

	var art := TextureRect.new()
	art.texture = SPRITE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.custom_minimum_size = Vector2(330, 330)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(art)

	var thanks := UITheme.pixel("Thank you", 44, GOLD)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(thanks)

	await get_tree().create_timer(HOLD_SECONDS).timeout
	get_tree().quit()
