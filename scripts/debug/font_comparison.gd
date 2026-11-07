extends Control
## Debug-only typography comparison. This scene never appears in normal navigation.

const BODY_SIZE := 24
const SAMPLE := "Question: Which organ pumps blood through the body?"
const CMU := preload("res://assets/fonts/CMUTypewriter-Regular.ttf")
const NUNITO := preload("res://assets/fonts/debug/Nunito-Variable.ttf")

func _ready() -> void:
	_apply_panel($Margin/Layout/Panels/CMUPanel, CMU, "CMU Typewriter")
	_apply_panel($Margin/Layout/Panels/NunitoPanel, NUNITO, "Nunito")
	_capture_if_requested()

func _apply_panel(panel: Control, font: Font, name: String) -> void:
	_apply_font(panel, font)
	_apply_body_color(panel.get_node("Content"))
	panel.get_node("Content/Name/Label").add_theme_color_override("font_color", Color.WHITE)
	var width := roundi(font.get_string_size(SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, BODY_SIZE).x)
	var has_spanish := font.has_char("Ñ".unicode_at(0)) and font.has_char("ñ".unicode_at(0))
	panel.get_node("Content/Metrics").text = "%s · question width at 24 px: %d px · Ñ/ñ: %s" % [name, width, "yes" if has_spanish else "missing"]

func _apply_font(node: Node, font: Font) -> void:
	if node is Label:
		node.add_theme_font_override("font", font)
		if node.name != "Metrics": node.add_theme_font_size_override("font_size", BODY_SIZE)
	for child in node.get_children(): _apply_font(child, font)

func _apply_body_color(node: Node) -> void:
	if node is Label:
		node.add_theme_color_override("font_color", Color(0.08, 0.16, 0.28, 1))
	for child in node.get_children(): _apply_body_color(child)

func _capture_if_requested() -> void:
	var args := OS.get_cmdline_user_args()
	var marker := args.find("--font-capture")
	if marker == -1 or marker + 1 >= args.size(): return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[marker + 1])
	get_tree().quit()
