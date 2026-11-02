extends RefCounted
## One switch for the diagnostic overlays.
##
## Nothing diagnostic should ever reach a student's screen: the battle label and
## the generation panel both printed file paths and the server address. They are
## still useful while developing, so they are off unless asked for:
##
##     $env:QF_DEBUG = "1"; godot --path .
##     godot --path . -- --debug-overlay


static func overlay_on() -> bool:
	if OS.has_environment("QF_DEBUG"):
		return true
	return OS.get_cmdline_args().has("--debug-overlay")
