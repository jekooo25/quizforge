extends Node
## Debug harness: boots the battle scene, optionally answers a question, then
## saves a PNG of the viewport so the layout and feedback can be inspected.
## godot --path . res://tests/capture.tscn -- --out shot.png --delay 1.2 [--answer]

var _out_path: String = "user://shot.png"
var _delay: float = 1.2
var _answer: bool = false


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
			"--answer":
				_answer = true

	var battle: Node = load("res://scenes/battle.tscn").instantiate()
	add_child(battle)

	if _answer:
		await get_tree().create_timer(0.7).timeout
		battle._on_answer(battle._correct_index)
		await get_tree().create_timer(maxf(_delay - 0.7, 0.25)).timeout
	else:
		await get_tree().create_timer(_delay).timeout

	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_out_path)
	if err != OK:
		printerr("capture failed: ", err)
	else:
		print("captured ", _out_path, " ", image.get_size())
	get_tree().quit()
