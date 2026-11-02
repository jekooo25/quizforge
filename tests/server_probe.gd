extends Node
## Manual probe: sends one file to the question server and prints the sentence a
## student would read. Useful with the server stopped as well as running.
##
##   godot --headless --path . res://tests/server_probe.tscn -- "C:/path/file.pdf"
##   godot --headless --path . res://tests/server_probe.tscn -- "C:/path/file.pdf" "900-950"

const TIMEOUT := 100.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else ""
	var pages := args[1] if args.size() > 1 else ""
	var url := args[2] if args.size() > 2 else ""

	# "-" stands in for an empty argument: PowerShell drops real empty strings
	if pages == "-":
		pages = ""

	# a third argument overrides the address, so a closed port can stand in for
	# "the server is not running" without touching the real one
	if url != "":
		Nav.user["server_url"] = url

	print("[probe] server: ", QuizClient.base_url())
	print("[probe] file:   ", path, "   pages: '", pages, "'")

	var client := QuizClient.new()
	add_child(client)

	client.generated.connect(func(result: Dictionary) -> void:
		print("[probe] RESULT: %d questions, provider %s" % [
			result.get("questions", []).size(),
			str(result.get("source", {}).get("provider", "?"))])
		get_tree().quit(0))

	client.failed.connect(func(message: String) -> void:
		print("[probe] STUDENT SEES: ", message)
		get_tree().quit(0))

	var accepted := client.generate_file(path, 5, pages)
	if not accepted:
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0)
		return

	await get_tree().create_timer(TIMEOUT).timeout
	print("[probe] TIMEOUT waiting for the server")
	get_tree().quit(2)
