class_name QuizClient
extends Node
## Talks to the question server (server/app.py).
##
## The phone cannot parse a PDF and must not hold an API key, so generation
## happens off-device. Everything is one POST and one JSON reply.

signal generated(result: Dictionary)
signal regenerated(result: Dictionary)
signal failed(message: String)

const TIMEOUT_SECONDS := 75.0
const BOUNDARY := "----QuizforgeFormBoundary"


## The saved address wins; otherwise the build-time default in ServerConfig.
## Returns "" when neither is set, which the caller must report rather than
## quietly trying the phone's own loopback.
static func base_url() -> String:
	var configured := str(Nav.user.get("server_url", "")).strip_edges()
	if configured == "":
		configured = ServerConfig.DEFAULT_URL.strip_edges()
	return configured.trim_suffix("/")


## Uploads the chosen reviewer and asks for questions.
func generate_file(path: String, count := 10) -> bool:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		failed.emit("That file could not be read.")
		return false

	var mime := "application/octet-stream"
	match path.get_extension().to_lower():
		"pdf":
			mime = "application/pdf"
		"png":
			mime = "image/png"
		"jpg", "jpeg":
			mime = "image/jpeg"
		"webp":
			mime = "image/webp"
		"txt", "md", "csv":
			mime = "text/plain"

	var head := "--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n"
	var tail := "\r\n--%s\r\nContent-Disposition: form-data; name=\"count\"\r\n\r\n%d\r\n--%s--\r\n"

	var body := PackedByteArray()
	body.append_array((head % [BOUNDARY, path.get_file(), mime]).to_utf8_buffer())
	body.append_array(bytes)
	body.append_array((tail % [BOUNDARY, count, BOUNDARY]).to_utf8_buffer())

	return _post("/generate", body, "multipart/form-data; boundary=" + BOUNDARY, true)


## Asks for a fresh set from text we already extracted.
func regenerate(pages: Array, count := 10) -> bool:
	var payload := {"pages": pages, "count": count}
	return _post("/regenerate", JSON.stringify(payload).to_utf8_buffer(), "application/json", false)


func _post(path: String, body: PackedByteArray, content_type: String, is_generate: bool) -> bool:
	var base := base_url()
	if base == "":
		failed.emit("No question server is set. Open Settings and enter its address.")
		return false

	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SECONDS
	add_child(http)

	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, data: PackedByteArray) -> void:
			_handle(result, code, data, is_generate)
			http.queue_free(),
		CONNECT_ONE_SHOT)

	var err := http.request_raw(base + path, ["Content-Type: " + content_type], HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		failed.emit("Could not reach the question server at %s." % base_url())
		return false
	return true


func _handle(result: int, code: int, body: PackedByteArray, is_generate: bool) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit("The question server didn't answer. Is it running at %s?" % base_url())
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if code != 200:
		var message := "The server returned %d." % code
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
			message = str(parsed["error"])
		failed.emit(message)
		return

	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("questions"):
		failed.emit("The server sent something unexpected.")
		return

	if is_generate:
		generated.emit(parsed)
	else:
		regenerated.emit(parsed)
