class_name AudioMixer
extends RefCounted
## Music and SFX volume, and the buses they drive.
##
## The build shipped with only Godot's Master bus, so the old settings screen
## turned the whole output down under the label "Music". This keeps two named
## buses so the sliders mean what they say, creating them on first use — the
## project has no bus layout resource to depend on.
##
## Volumes live in the student's profile as whole percentages, `volume_music`
## and `volume_sfx`, so they save and reload with the rest of it.

const MUSIC := "Music"
const SFX := "SFX"
const DEFAULT_VOLUME := 70
const MASTER := "Master"

const MIN_SCALE := 0.0001


## Reads a stored percentage, falling back to the default for a profile written
## before these settings existed, or one holding junk.
static func volume_of(user: Dictionary, key: String) -> int:
	if not user.has(key):
		return DEFAULT_VOLUME
	var stored: Variant = user[key]
	if typeof(stored) == TYPE_INT or typeof(stored) == TYPE_FLOAT:
		return clampi(int(stored), 0, 100)
	return DEFAULT_VOLUME


## Applies every stored volume to its bus. Called at startup and after the
## settings screen changes something.
static func apply(user: Dictionary) -> void:
	set_volume_percent(MUSIC, volume_of(user, "volume_music"))
	set_volume_percent(SFX, volume_of(user, "volume_sfx"))


## Sets one bus to a 0-100 percentage. Zero mutes rather than merely quietening,
## so a slider at the far left is genuinely silent on a cheap handset's speakers.
static func set_volume_percent(bus_name: String, percent: int) -> void:
	var index := ensure_bus(bus_name)
	if index == -1:
		return
	var clamped := clampi(percent, 0, 100)
	AudioServer.set_bus_mute(index, clamped == 0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clamped / 100.0, MIN_SCALE)))


## Returns the bus index, adding the bus (routed to Master) if it is missing.
static func ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index != -1:
		return index
	if bus_name == MASTER:
		return 0
	index = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, MASTER)
	return index


static func bus_percent(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1 or AudioServer.is_bus_mute(index):
		return 0
	return roundi(db_to_linear(AudioServer.get_bus_volume_db(index)) * 100.0)
