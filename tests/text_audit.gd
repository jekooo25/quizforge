extends Node
## Dumps every piece of text in the app with its font and size.
##
##   godot --headless --path . res://tests/text_audit.tscn
##
## Sizes are reported twice: as authored in the 1280x562 design, and scaled to a
## 720-wide design frame (x0.5625), which is the frame the readability brief uses.

const DESIGN := 1280.0
const MOBILE := 720.0

const SCREENS := [
	["title", "res://scripts/screens/title_screen.gd"],
	["login", "res://scripts/screens/login_screen.gd"],
	["signup name", "res://scripts/screens/signup_name_screen.gd"],
	["signup school", "res://scripts/screens/signup_school_screen.gd"],
	["loading", "res://scripts/screens/loading_screen.gd"],
	["menu", "res://scripts/screens/menu_screen.gd"],
	["upload", "res://scripts/screens/upload_screen.gd"],
	["generation", "res://scripts/screens/generation_screen.gd"],
	["review", "res://scripts/screens/review_screen.gd"],
	["battle", "res://scripts/battle.gd"],
	["my quizzes", "res://scripts/screens/my_quizzes_screen.gd"],
	["settings", "res://scripts/screens/settings_screen.gd"],
	["thank you", "res://scripts/screens/thank_you_screen.gd"],
]


func _ready() -> void:
	for entry in SCREENS:
		var screen: Control = load(entry[1]).new()
		if screen.has_method("setup"):
			screen.setup({
				"title": "Sample reviewer",
				"questions": QuizData.sample(),
				"pages": [{"page": 1, "text": "Sample source text."}],
			})
		Nav.show_screen(screen)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		print("### " + str(entry[0]))
		_dump(screen, 0)
	get_tree().quit(0)


func _dump(node: Node, depth: int) -> void:
	for child in node.get_children():
		if child is Control:
			_line(child as Control, depth)
		_dump(child, depth + 1)


func _line(c: Control, depth: int) -> void:
	var text := ""
	if c is Label or c is Button or c is LineEdit or c is RichTextLabel \
			or c is LinkButton or c is OptionButton:
		text = str(c.get("text"))
	if text.strip_edges() == "":
		return

	var font := c.get_theme_font("font")
	var font_name := font.get_font_name() if font != null else "(default)"
	var size := c.get_theme_font_size("font_size")
	var scaled := float(size) * (MOBILE / DESIGN)

	var clean := text.replace("\n", " ").strip_edges()
	var letters := clean.to_lower() != clean.to_upper()
	var caps := letters and clean == clean.to_upper()

	print("%s | %-11s | %-3d (%2d @720) | %-3s | %-7s | %s" % [
		"  ".repeat(depth),
		font_name.left(11),
		size,
		int(round(scaled)),
		"CAP" if caps else "sentence",
		"on " + _surface(c),
		"\"" + clean.left(52) + "\"",
	])


## Walks up to see whether the text sits on the art or inside a panel.
func _surface(c: Control) -> String:
	var node := c.get_parent()
	while node != null:
		if node is PanelContainer or node is BoardCard:
			return "panel"
		node = node.get_parent()
	return "art"
