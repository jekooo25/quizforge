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


## The developer override wins; otherwise the address baked into ServerConfig.
## Never returns "": the build always has somewhere to send the upload.
static func base_url() -> String:
	var configured := str(Nav.user.get("server_url", "")).strip_edges()
	if configured == "":
		configured = ServerConfig.DEFAULT_URL.strip_edges()
	return configured.trim_suffix("/")


## Uploads the chosen reviewer and asks for questions. `page_range` is the
## optional "40-65" the student typed; empty means let the server sample.
func generate_file(path: String, count := 10, page_range := "", seed := 0) -> bool:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		failed.emit("We couldn't open that file. Try choosing it again.")
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
	var tail := "\r\n--%s\r\nContent-Disposition: form-data; name=\"count\"\r\n\r\n%d" % [BOUNDARY, count]
	tail += "\r\n--%s\r\nContent-Disposition: form-data; name=\"seed\"\r\n\r\n%d" % [BOUNDARY, seed]
	var range := page_range.strip_edges()
	if range != "":
		tail += "\r\n--%s\r\nContent-Disposition: form-data; name=\"pages\"\r\n\r\n%s" % [BOUNDARY, range]
	tail += "\r\n--%s--\r\n" % BOUNDARY

	var body := PackedByteArray()
	body.append_array((head % [BOUNDARY, path.get_file(), mime]).to_utf8_buffer())
	body.append_array(bytes)
	body.append_array(tail.to_utf8_buffer())

	return _post("/generate", body, "multipart/form-data; boundary=" + BOUNDARY, true)


## Asks for a fresh set from text we already extracted. `avoid_pages` are the
## PDF pages the current set used, so the server can prefer a different slice.
func regenerate(pages: Array, count := 10, avoid_pages: Array = []) -> bool:
	var payload := {
		"pages": pages,
		"count": count,
		"avoid_pages": avoid_pages,
		"seed": Time.get_ticks_msec(),
	}
	return _post("/regenerate", JSON.stringify(payload).to_utf8_buffer(), "application/json", false)


func _post(path: String, body: PackedByteArray, content_type: String, is_generate: bool) -> bool:
	var base := base_url()
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SECONDS
	add_child(http)
	print("[quizclient] POST %s%s  (%d bytes, timeout %.0fs)" % [base, path, body.size(), TIMEOUT_SECONDS])

	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, data: PackedByteArray) -> void:
			_handle(result, code, data, is_generate)
			http.queue_free(),
		CONNECT_ONE_SHOT)

	var err := http.request_raw(base + path, ["Content-Type: " + content_type], HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		print("[quizclient] request_raw failed: %d" % err)
		failed.emit("No internet, or Quizforge can't be reached. "
			+ "Check your connection and try again.")
		return false
	return true


func _handle(result: int, code: int, body: PackedByteArray, is_generate: bool) -> void:
	print("[quizclient] result=%d  http=%d  bytes=%d" % [result, code, body.size()])

	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit(_result_message(result))
		return

	if code != 200:
		# the status, code and body stay in the console; the student gets plain words
		print("[quizclient] body: ", body.get_string_from_utf8().left(300))
		failed.emit(_code_message(code, _error_code(body)))
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("questions"):
		failed.emit("Quizforge sent something we didn't understand. Try again.")
		return

	# a 200 with no questions would otherwise open an empty review screen
	if is_generate and parsed.get("questions", []).is_empty():
		failed.emit("We couldn't make questions from that file. "
			+ "Try a different file, or enter a page range.")
		return

	if is_generate:
		generated.emit(parsed)
	else:
		regenerated.emit(parsed)


## No codes, no addresses: what happened, and what the student can do about it.
static func _result_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_TIMEOUT:
			return "Quizforge took too long to answer. Check your connection and try again."
		HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CANT_CONNECT, \
				HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Could not connect to quiz generation. Check that the laptop generation server is running, then try again."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "We couldn't make a secure connection. Try again in a moment."
		_:
			return "Something went wrong sending your file. Check your connection and try again."


## The server tags the failures it can explain; those get specific wording.
static func _error_code(body: PackedByteArray) -> String:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("code"):
		return str(parsed["code"])
	return ""


static func _code_message(code: int, tag := "") -> String:
	match tag:
		"empty":
			return "This file is empty. Choose a reviewer containing study material."
		"insufficient":
			return "Not enough clear study material was found. Try a chapter with complete definitions or explanations."
		"vision":
			return "This image or scan could not be read by the current generation setup. Try a text-based PDF or TXT file."
		"unsupported":
			return "This format is not supported. Choose a PDF, text file or supported image."
		"count":
			return "Choose a valid number of questions, then try again."
		"page_range":
			return "That page range isn't in this file. Check the page numbers, or leave the range empty."
		"quality":
			return "We couldn't write good questions from that part of the file. Try again, or enter a page range."
		"unreadable":
			return "We couldn't read that file. Try a different PDF, or a photo of the pages."
		"provider_busy":
			return "Quizforge is busy right now. Please try again in a minute."
		"server":
			return "Quizforge is having a problem on our side. Try again in a moment."

	if code == 413:
		return "That file is too big. Try a smaller file or a shorter page range."
	if code >= 500:
		return "Quizforge is having a problem on our side. Try again in a moment."
	if code >= 400:
		return "We couldn't read that file. Try a different PDF, or a photo of the pages."
	return "Something went wrong. Try again."
