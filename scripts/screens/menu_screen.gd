extends Control
## Main menu on the bulletin board, mascot peeking over the top edge.

const Cat := preload("res://scripts/ui/cat_mascot.gd")


func _ready() -> void:
	var bg: Control = PhotoBackdrop.create()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# mascot sits behind the board, head above the frame
	var cat: Control = Cat.new()
	cat.anchor_left = 0.5
	cat.anchor_right = 0.5
	cat.anchor_top = 0.0
	cat.anchor_bottom = 0.0
	cat.offset_left = -80.0
	cat.offset_right = 80.0
	cat.offset_top = -36.0
	cat.offset_bottom = 148.0
	add_child(cat)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var board := BoardCard.new()
	board.custom_minimum_size = Vector2(800, 380)
	center.add_child(board)

	var title := UITheme.script("Main menu", 34, UITheme.WOOD_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.content.add_child(title)

	var items := [
		{"text": "Upload your reviewer", "action": "upload"},
		{"text": "View progress", "action": "progress"},
		{"text": "Settings", "action": "settings"},
		{"text": "Exit", "action": "exit"},
	]
	for item in items:
		var b := UITheme.script_button(str(item["text"]), 26)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(_on_item.bind(str(item["action"])))
		board.content.add_child(b)

	var footer := UITheme.small(_footer_text(), 11, UITheme.MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board.content.add_child(footer)


func _footer_text() -> String:
	var who := Nav.display_name()
	var school := str(Nav.user.get("school", ""))
	if school == "":
		return "Signed in as " + who
	return "%s  ·  %s" % [who, school]


func _on_item(action: String) -> void:
	match action:
		"upload":
			Nav.show_screen(load("res://scripts/screens/upload_screen.gd").new())
		"progress":
			Nav.show_screen(load("res://scripts/screens/progress_screen.gd").new())
		"settings":
			Nav.show_screen(load("res://scripts/screens/settings_screen.gd").new())
		"exit":
			var dialog := BoardDialog.ask("Are you sure you want to exit the game?", "Yes", "No")
			add_child(dialog)
			dialog.confirmed.connect(func() -> void:
				get_tree().quit())
