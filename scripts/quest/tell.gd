## A Tell: a small, silent wrongness the player can *Look* at.
##
## GDD §6 "Tells", §16a "Noticed". The Street is a dream the player has
## forgotten and the game lets it show: a clock that stops while the hum is
## held, a puddle with a small world turning in it. *Look* records the tell
## in the journey's *Noticed* list (GameState.notice) and says the sentence
## it was seen in, once, as a subtitle. Nothing explains it, nothing counts
## it, nothing needs it. Which tell this is, is data on the node (`tell_id`,
## a row of data/tells.json); the prop beside it is the generator's. A tell
## that needs the hum (`requires_humming` in the data) offers *Look* only
## while the Place's hum is sounding.
extends Node3D

signal noticed(tell_id: String)

## How long the sentence stays on the HUD.
const SENTENCE_SECONDS := 4.0

## A row of data/tells.json.
@export var tell_id := ""

var _place: Place = null

@onready var _look: Interactable = %Look


func _ready() -> void:
	_look.used.connect(_on_look)
	_place = _find_place()
	if not Tells.has(tell_id):
		push_warning("Tell '%s' at %s is not in data/tells.json" % [tell_id, get_path()])


func _physics_process(_delta: float) -> void:
	_look.enabled = is_available()


## Whether *Look* is offered now: always, unless the tell needs the hum and
## nothing is humming.
func is_available() -> bool:
	if not Tells.has(tell_id):
		return false
	if Tells.requires_humming(tell_id):
		return _place != null and _place.is_humming()
	return true


func _on_look(_player: Node3D) -> void:
	GameState.notice(tell_id)
	if _place != null:
		_place.subtitle(Tells.sentence_id_of(tell_id), SENTENCE_SECONDS)
	noticed.emit(tell_id)


## The Place this tell stands in: the nearest ancestor that is one.
func _find_place() -> Place:
	var node: Node = get_parent()
	while node != null:
		if node is Place:
			return node
		node = node.get_parent()
	return null
