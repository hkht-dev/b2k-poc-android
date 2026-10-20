## The bus stop: where the slice ends.
##
## CLAUDE_CODE_BRIEF.md §4.6: the ending is reached by walking here after
## the can was placed or taken, or by sitting here (contextual *Sit*) at any
## time after 90 s of play. The flags that end it are data on the scene; the
## play time comes from the journey. This node only says "it is over";
## the street fades and the end screen follows.
extends Node3D

signal slice_ended(reason: String)

const REASON_ARRIVED := "arrived"
const REASON_SAT := "sat"

## Any of these flags set makes arriving here the end.
@export
var ending_flags: PackedStringArray = PackedStringArray(["gave_dry_fountain", "took_dry_fountain"])
## *Sit* is offered once this much of the journey has been played, in seconds.
@export_range(0.0, 600.0, 1.0) var sit_after := 90.0

var _ended := false

@onready var _arrive: Area3D = %Arrive
@onready var _sit: Interactable = %Sit


func _ready() -> void:
	_arrive.body_entered.connect(_on_body_entered)
	_sit.used.connect(_on_sit)


func _physics_process(_delta: float) -> void:
	_sit.enabled = not _ended and GameState.play_seconds >= sit_after


func has_ended() -> bool:
	return _ended


func _on_body_entered(body: Node3D) -> void:
	if _ended or not body.is_in_group("player"):
		return
	for flag in ending_flags:
		if GameState.has_flag(flag):
			_end(REASON_ARRIVED)
			return


func _on_sit(_player: Node3D) -> void:
	if not _ended:
		_end(REASON_SAT)


func _end(reason: String) -> void:
	_ended = true
	slice_ended.emit(reason)
