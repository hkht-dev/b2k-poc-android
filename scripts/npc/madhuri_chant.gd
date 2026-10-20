## Madhuri's chant, the sound the shrine room is found by.
##
## GDD §5 Hollow Vale: the room "leaks a faint drone of Madhuri's chanting
## under the traffic"; GDD §10 "Sound": the maha-mantra "is mixed low under
## the shrine". A positional loop, in the `sound_source` group so the
## player's hum reaches it (Place.hum): GDD §7 micro-interaction "Hum near
## the shrine: Madhuri's chant rises to meet the note", for a few seconds,
## then settles. No reward, no flag: a sound answering a sound.
extends Node3D

signal rose

## How long the chant stays raised after a hum.
const RAISE_SECONDS := 4.0
## How much louder it comes up; how long the swell and the settling take.
const RAISE_DB := 7.0
const SWELL_SECONDS := 0.6
const SETTLE_SECONDS := 1.2

## Subtitle shown as the chant rises (GDD §11: every vocal sound).
@export var subtitle_id := ""

var _base_db := 0.0
var _raised_left := 0.0
var _tween: Tween = null

@onready var _loop: AudioStreamPlayer3D = %Loop


func _ready() -> void:
	add_to_group(Interactable.SOUND_SOURCE_GROUP)
	_base_db = _loop.volume_db
	_loop.play()


func _process(delta: float) -> void:
	if _raised_left <= 0.0:
		return
	_raised_left -= delta
	if _raised_left <= 0.0:
		_ease_to(_base_db, SETTLE_SECONDS)


## The player's hum reaches the room: the chant rises to meet the note.
func hear_hum() -> bool:
	_raised_left = RAISE_SECONDS
	_ease_to(_base_db + RAISE_DB, SWELL_SECONDS)
	if not subtitle_id.is_empty():
		_tween.tween_callback(_subtitle.bind(subtitle_id))
	rose.emit()
	return true


func is_raised() -> bool:
	return _raised_left > 0.0


func volume_db() -> float:
	return _loop.volume_db


func base_db() -> float:
	return _base_db


func _ease_to(db: float, seconds: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_loop, "volume_db", db, seconds)


## The place's HUD shows the subtitle; outside a place there is none to show.
func _subtitle(text_id: String) -> void:
	var node: Node = get_parent()
	while node != null and not (node is Place):
		node = node.get_parent()
	if node == null:
		return
	var controls: Node = node.get_node_or_null("%TouchControls")
	if controls != null:
		controls.subtitle(text_id)
