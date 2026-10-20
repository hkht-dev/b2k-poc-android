## The way back down a ladder: *Climb down*, one segment at a time.
##
## GDD §3a, §5: the billboard tower is climbed by a ladder with four landings.
## Walking into the rungs carries the player up a segment
## (scripts/street/ladder.gd); the landings above the first are railed on
## every open side, so without this the roof is a place with no way out.
## Coming down is deliberate rather than a drop: the one contextual button
## offers the verb, which works the same on a thumb, a key and a pad, and the
## body climbs down by the same move it climbed up with
## (`Player.begin_climb`, which eases to the marker whether it is above or
## below). The landing below is a marker on the scene, never a path in code.
extends Node3D

## The player set off down this segment.
signal descended(player: Node3D)

## The landing below: a Marker3D the body is carried to.
@export var exit_marker_path: NodePath

@onready var _use: Interactable = %Use
@onready var _exit: Node3D = get_node_or_null(exit_marker_path) as Node3D


func _ready() -> void:
	_use.used.connect(_on_use)
	if _exit == null:
		push_error("LadderDown '%s' has no landing below; it can never be used" % name)
		_use.enabled = false


## Where the climb ends, for the tests and for anything that draws the route.
func exit_position() -> Vector3:
	return _exit.global_position if _exit != null else global_position


func _on_use(player: Node3D) -> void:
	if _exit == null or not player.has_method("begin_climb"):
		return
	if player.begin_climb(_exit.global_position):
		descended.emit(player)
