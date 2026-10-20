## A sound shown as a soft ripple at its source (brief §7 "Sound cues as
## visuals", GDD §11). A flat ring grows and fades over RIPPLE_SECONDS; far
## slower than 3 Hz, so nothing flashes. Continuous for a source that is
## always sounding (Tulu's hum), or one pulse on demand (the player's hum).
## Off unless the `sound_cues` setting is on; the street toggles every node
## in the group.
class_name SoundRipple
extends Node3D

const GROUP := "sound_cue"
const RIPPLE_SECONDS := 1.4
const START_SCALE := 0.4
const END_SCALE := 3.2

@export var continuous := false
## Off until the setting turns it on.
@export var enabled := false

var _phase := 0.0
var _pulsing := false

@onready var _ring: MeshInstance3D = %Ring


func _ready() -> void:
	add_to_group(GROUP)
	_ring.visible = false


func _process(delta: float) -> void:
	if not enabled or not (continuous or _pulsing):
		_ring.visible = false
		return
	_phase += delta / RIPPLE_SECONDS
	if _phase >= 1.0:
		_phase = 0.0 if continuous else 1.0
		_pulsing = false
		if not continuous:
			_ring.visible = false
			return
	var t := _phase
	_ring.visible = true
	_ring.scale = Vector3.ONE * lerpf(START_SCALE, END_SCALE, t)
	_ring.transparency = t


## One ripple now (a hum, a reply).
func pulse() -> void:
	if not enabled:
		return
	_phase = 0.0
	_pulsing = true


func is_showing() -> bool:
	return _ring.visible
