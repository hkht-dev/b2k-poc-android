## One of the three fixed spots on the Street where a dawn vignette's
## stranger stands.
##
## GDD §16a "Dawn vignettes"; the pool and the queue are
## scripts/core/vignettes.gd. At ready the spot grants today's vignette to
## the journey, takes the oldest pending vignette whose `spot` is this
## letter, and stands its stranger here: the same rigged body as everyone
## else with the vignette's skin, and a *Talk* area. Talk opens the
## vignette's first line through Content.dialogue, whose table the
## vignette's lines were added to, so the cards are the same cards as
## everywhere (GDD §6 "Choice"). A card that sets one of the vignette's
## outcome flags finishes it: the done flag and the journey line are written
## and Talk closes. A conversation left without an outcome leaves the
## vignette pending; nothing is lost.
##
## PLACEHOLDER body: Kenney's rigged character with a Kenney skin, replaced
## by the painted strangers of GDD §10 "Characters".
extends Node3D

signal talked(line_id: String)
signal completed(vignette_id: String)

const CHARACTER := preload("res://scenes/characters/Character.tscn")
const FIGURE_NAME := "Figure"
## Kenney's animated-characters skins by name (docs/RIGHTS_REGISTER.md); a
## vignette names one. PLACEHOLDER for the painted strangers of GDD §10.
const SKINS := {
	"humanFemaleA":
	preload("res://assets/thirdparty/kenney/animated-characters-retro/humanFemaleA.png"),
	"humanMaleA":
	preload("res://assets/thirdparty/kenney/animated-characters-retro/humanMaleA.png"),
	"criminalMaleA":
	preload("res://assets/thirdparty/kenney/animated-characters-protagonists/criminalMaleA.png"),
	"skaterFemaleA":
	preload("res://assets/thirdparty/kenney/animated-characters-protagonists/skaterFemaleA.png"),
	"skaterMaleA":
	preload("res://assets/thirdparty/kenney/animated-characters-protagonists/skaterMaleA.png"),
	"survivorFemaleA":
	preload("res://assets/thirdparty/kenney/animated-characters-survivors/survivorFemaleA.png"),
	"survivorMaleB":
	preload("res://assets/thirdparty/kenney/animated-characters-survivors/survivorMaleB.png"),
}

## Which of the three spots this is: "a", "b" or "c" (data on the street scene).
@export var spot := "a"

var _vignette: Dictionary = {}
var _figure: CharacterRig = null

@onready var _talk: Interactable = %Talk
@onready var _body_shape: CollisionShape3D = %BodyShape


func _ready() -> void:
	_talk.used.connect(_on_talk)
	Vignettes.grant_today()
	_vignette = Vignettes.pending_for_spot(spot)
	if not _vignette.is_empty():
		var source := Vignettes.DIR + str(_vignette["id"]) + ".json"
		if not Content.dialogue.add_lines(_vignette["lines"], source):
			_vignette = {}
	if _vignette.is_empty():
		_talk.enabled = false
		_body_shape.disabled = true
		return
	_figure = CHARACTER.instantiate()
	_figure.name = FIGURE_NAME
	var skin: Texture2D = SKINS.get(_vignette["skin"])
	if skin != null:
		_figure.skin = skin
	else:
		push_warning("VignetteSpot: '%s' names no skin '%s'" % [_vignette["id"], _vignette["skin"]])
	add_child(_figure)
	GameState.flag_changed.connect(_on_flag_changed)


## The vignette standing here, or {} when the spot is empty today.
func vignette() -> Dictionary:
	return _vignette


func vignette_id() -> String:
	return str(_vignette.get("id", ""))


func has_stranger() -> bool:
	return _figure != null


func figure() -> CharacterRig:
	return _figure


func _on_talk(player: Node3D) -> void:
	if _vignette.is_empty():
		return
	if player != null:
		_face(player.global_position)
	var entry := Vignettes.entry_line_id(_vignette)
	if Content.dialogue.start(entry):
		talked.emit(entry)


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if not is_set or _vignette.is_empty():
		return
	if not (_vignette["outcomes"] as PackedStringArray).has(flag):
		return
	var id := vignette_id()
	Vignettes.complete(id)
	_talk.enabled = false
	completed.emit(id)


func _face(point: Vector3) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length() > 0.05:
		rotation.y = atan2(-to.x, -to.z)
