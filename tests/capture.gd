extends Node
## Screenshot harness for the whole app.
## godot --path . res://tests/capture.tscn -- --screen res://scripts/screens/menu_screen.gd --out shot.png --delay 1.0

var _out_path := "user://shot.png"
var _delay := 1.0
var _screen := ""
var _payload := ""
var _tab := ""
var _call := ""
var _size := Vector2i.ZERO
var _no_stretch := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--out":
				if i + 1 < args.size():
					_out_path = args[i + 1]
			"--delay":
				if i + 1 < args.size():
					_delay = float(args[i + 1])
			"--screen":
				if i + 1 < args.size():
					_screen = args[i + 1]
			"--payload":
				if i + 1 < args.size():
					_payload = args[i + 1]
			"--tab":
				if i + 1 < args.size():
					_tab = args[i + 1]
			"--call":
				if i + 1 < args.size():
					_call = args[i + 1]
			"--size":
				if i + 1 < args.size():
					var parts := args[i + 1].split("x")
					if parts.size() == 2:
						_size = Vector2i(int(parts[0]), int(parts[1]))
			"--no-stretch":
				_no_stretch = true

	# A real phone width, laid out instead of scaled down. Without --no-stretch
	# the project's canvas_items stretch shrinks the 1280x562 design instead.
	if _size != Vector2i.ZERO:
		if _no_stretch:
			get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		get_window().size = _size
		await get_tree().process_frame

	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main_scene)

	if _screen != "":
		await get_tree().process_frame
		var script: GDScript = load(_screen)
		if script == null:
			printerr("could not load screen: ", _screen)
			get_tree().quit(1)
			return
		var screen: Control = script.new()
		if _payload != "" and screen.has_method("setup"):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(_payload))
			if typeof(parsed) == TYPE_DICTIONARY:
				screen = screen.setup(parsed)
			else:
				printerr("could not read payload: ", _payload)
		Nav.show_screen(screen)
		if _tab != "" and screen.has_method("_select_tab"):
			screen._select_tab(_tab)
		if _call != "" and screen.has_method(_call):
			screen.call(_call)

	await get_tree().create_timer(_delay).timeout
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_out_path)
	if err != OK:
		printerr("capture failed: ", err)
	else:
		print("captured ", _out_path, " ", image.get_size())
	get_tree().quit()
