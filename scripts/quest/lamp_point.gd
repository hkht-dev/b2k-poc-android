## The lamp in the shrine room as a place the player can use: *Place* a can
## of water for it.
##
## GDD §7 "Investigate" step 3 ("carry water for the lamp"), §8 Scene D ("The
## well is dry and the lamp wants water. If you're going somewhere anyway."),
## §3a Act 3 ("Carry a can into the shrine room; set it by the lamp: service
## asked with no reward"). Mirrors scripts/quest/fountain_point.gd: *Place* is
## offered only while the player carries a can (the `requires` on the
## Interactable, data on the scene); using it puts the can down, fires
## `event_id` and sets `sets`, both data on the node, and the lamp brightens
## so it will see the dawn. No reward is mentioned, as the scene says.
extends Node3D

signal placed

## The lamp comes up to `lit_energy` over this long once it has its water.
const BRIGHTEN_SECONDS := 4.0

## The event fired when the can is set down (GameState.fire_event).
@export var event_id := ""
## Flags set when the can is set down; all of them set means "watered".
@export var sets: PackedStringArray = PackedStringArray()
## The carried item this point accepts (Player.carryables).
@export var item := ""
## The lamp's light once watered; it starts at the scene's dimmer value.
@export var lit_energy := 1.6

var _tween: Tween = null

@onready var _place: Interactable = %Place
@onready var _lamp: OmniLight3D = %Lamp
@onready var _can: Node3D = %PlacedCan


func _ready() -> void:
	_place.used.connect(_on_place)
	_can.visible = false
	if is_watered():
		_show_watered(0.0)
	GameState.flag_changed.connect(_on_flag_changed)


## Every flag this point sets is set: the lamp has had its water.
func is_watered() -> bool:
	if sets.is_empty():
		return false
	for flag in sets:
		if not GameState.has_flag(flag):
			return false
	return true


func light_energy() -> float:
	return _lamp.light_energy


func _on_place(player: Node3D) -> void:
	if not player.is_carrying(item):
		return
	player.put_down()
	if not event_id.is_empty():
		GameState.fire_event(event_id)
	for flag in sets:
		GameState.set_flag(flag)
	placed.emit()


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if is_set and sets.has(flag) and is_watered() and not _can.visible:
		_show_watered(BRIGHTEN_SECONDS)


func _show_watered(seconds: float) -> void:
	_can.visible = true
	if _tween != null:
		_tween.kill()
		_tween = null
	if seconds <= 0.0:
		_lamp.light_energy = lit_energy
		return
	_tween = create_tween()
	_tween.tween_property(_lamp, "light_energy", lit_energy, seconds)
