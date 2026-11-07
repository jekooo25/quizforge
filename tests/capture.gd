extends Node
## Screenshot harness for the whole app.
## godot --path . res://tests/capture.tscn -- --scene res://scenes/my_quizzes.tscn --out shot.png --size 1280x562

@export var output_path := "user://shot.png"
@export var delay := 1.0
var _screen := ""
@export var scene_path := ""
var _payload := ""
var _tab := ""
var _call := ""
@export var capture_size := Vector2i.ZERO
@export var no_stretch := false
var _battle_sample := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--out":
				if i + 1 < args.size():
					output_path = args[i + 1]
			"--delay":
				if i + 1 < args.size():
					delay = float(args[i + 1])
			"--screen":
				if i + 1 < args.size():
					_screen = args[i + 1]
			"--scene":
				if i + 1 < args.size():
					scene_path = args[i + 1]
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
						capture_size = Vector2i(int(parts[0]), int(parts[1]))
			"--no-stretch":
				no_stretch = true
			"--battle-sample":
				_battle_sample = true

	# A real phone width, laid out instead of scaled down. Without --no-stretch
	# the project's canvas_items stretch shrinks the 1280x562 design instead.
	if capture_size != Vector2i.ZERO:
		if no_stretch:
			get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		get_window().size = capture_size
		await get_tree().process_frame

	var main_scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main_scene)
	if _battle_sample:
		QuizData.save("Battle Preview", QuizData.sample())

	if scene_path != "":
		await get_tree().process_frame
		var packed_scene := load(scene_path) as PackedScene
		if packed_scene == null:
			printerr("could not load scene: ", scene_path)
			get_tree().quit(1)
			return
		var screen := packed_scene.instantiate() as Control
		if screen == null:
			printerr("scene root is not a Control: ", scene_path)
			get_tree().quit(1)
			return
		Nav.show_screen(screen)
		if _tab != "" and screen.has_method("show_tab"):
			screen.call("show_tab", _tab)
		if _call != "" and screen.has_method(_call):
			screen.call(_call)
	elif _screen != "":
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

	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(output_path)
	if err != OK:
		printerr("capture failed: ", err)
	else:
		print("captured ", output_path, " ", image.get_size())
	get_tree().quit()
