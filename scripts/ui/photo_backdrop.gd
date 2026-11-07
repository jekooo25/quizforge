class_name PhotoBackdrop
extends Control
## The pixel-art campus photo, used behind the login flow.
##
## The photo is 2752x1536 (1.79:1) and the game frame is 1280x562 (2.28:1), so
## it can't be stretched without squashing the building. It's scaled to cover
## and cropped instead, biased toward the top so the bell tower stays in frame
## and the road falls off the bottom edge.

const IMAGE_PATH := "res://assets/backgrounds/LoginBackground.jpg"

## How much of the vertical overflow comes off the top. 0.12 keeps almost all
## of the sky and drops the foreground road.
const TOP_BIAS := 0.12

var texture: Texture2D


## Returns the photo, or the code-drawn campus if the photo is missing.
## Screens call this instead of Backdrop.new(), so dropping the file in is the
## only step needed to switch art.
static func create() -> Control:
	var tex: Texture2D = null
	if ResourceLoader.exists(IMAGE_PATH):
		tex = load(IMAGE_PATH)
	if tex == null:
		return load("res://scripts/ui/backdrop.gd").new()
	var node := PhotoBackdrop.new()
	node.texture = tex
	return node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if texture == null:
		return

	var tex_size := Vector2(texture.get_width(), texture.get_height())
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	# cover: scale until both dimensions are filled
	var cover_scale: float = maxf(size.x / tex_size.x, size.y / tex_size.y)
	var drawn := tex_size * cover_scale

	# centre horizontally, bias the vertical overflow toward the top
	var offset := Vector2(
		(size.x - drawn.x) * 0.5,
		(size.y - drawn.y) * TOP_BIAS
	)
	draw_texture_rect(texture, Rect2(offset, drawn), false)
