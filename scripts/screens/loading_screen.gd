extends Control
## The editable branded wait screen shown after a successful login.

var _mode := "login"

func setup(mode: String) -> Control:
	_mode = mode
	return self

func _ready() -> void:
	# Legacy callers that create the script directly still receive the scene-tree
	# version, so there is only one loading-screen layout to maintain.
	if scene_file_path == "":
		var screen: Control = load("res://scenes/LoadingScreen.tscn").instantiate()
		screen.setup(_mode)
		Nav.show_screen.call_deferred(screen)
		return
	%Heading.text = "Login successful!"
	%Summary.text = "Preparing your Quizforge experience..."
	Nav.save_profile()
	await get_tree().create_timer(2.6).timeout
	if is_inside_tree():
		Nav.show_screen(load("res://scripts/screens/menu_screen.gd").new())
