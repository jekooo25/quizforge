extends Node
## Short local retro cues, routed through the existing SFX volume controls.
const CUES := {
 "attack": preload("res://assets/audio/attack.wav"),
 "recover": preload("res://assets/audio/recover.wav"),
 "hit": preload("res://assets/audio/hit.wav"),
 "shield": preload("res://assets/audio/shield.wav"),
 "victory": preload("res://assets/audio/victory.wav"),
}
func play_cue(cue: String) -> void:
 var voice := AudioStreamPlayer.new()
 AudioMixer.ensure_bus(AudioMixer.SFX)
 voice.bus = AudioMixer.SFX
 voice.volume_db = -12.0
 voice.stream = CUES[cue]
 add_child(voice)
 voice.finished.connect(voice.queue_free)
 voice.play()
