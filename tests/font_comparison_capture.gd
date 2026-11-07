extends Node
## Debug capture only. It never runs from the game.

func _ready() -> void:
	print("FONT CAPTURE READY")
	var size := Vector2i(1280, 562)
	var args := OS.get_cmdline_user_args()
	var marker := args.find("--size")
	if marker != -1 and marker + 1 < args.size():
		var parts := args[marker + 1].split("x")
		if parts.size() == 2:
			size = Vector2i(int(parts[0]), int(parts[1]))
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = size
	var screen: Control = load("res://scenes/debug/FontComparison.tscn").instantiate()
	add_child(screen)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var output := "user://font-comparison-%dx%d.png" % [size.x, size.y]
	var result := get_viewport().get_texture().get_image().save_png(output)
	print("FONT CAPTURE ", ProjectSettings.globalize_path(output), " result=", result)
	get_tree().quit(0 if result == OK else 1)
