## Routes touches to the joystick, the camera and the contextual button.
##
## One node owns the multitouch bookkeeping so no two controls fight over the
## same finger. GDD §11 "Controls": left thumb moves, right thumb orbits, one
## contextual button sits lower right.
extends Control

signal camera_dragged(delta: Vector2)

## Pixels a right-thumb touch may wander before it counts as a camera drag
## rather than a tap. Keeps a tap on the contextual button from spinning the
## camera.
const DRAG_SLOP := 8.0

var _camera_touch := -1
var _camera_last := Vector2.ZERO
var _camera_moved := false

@onready var _joystick: Control = %Joystick
@onready var _button: Button = %ContextualButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


## This frame's movement wish, in screen space. The caller rotates it into
## world space; on desktop the keyboard stands in for the joystick.
func move_vector() -> Vector2:
	if _joystick.is_active():
		return _joystick.vector()
	var keys := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	return keys


func joystick() -> Control:
	return _joystick


func contextual_button() -> Button:
	return _button


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _joystick.try_claim(event.index, event.position):
			return
		if _camera_touch == -1 and not _over_button(event.position):
			_camera_touch = event.index
			_camera_last = event.position
			_camera_moved = false
		return

	_joystick.release(event.index)
	if event.index == _camera_touch:
		_camera_touch = -1


func _on_drag(event: InputEventScreenDrag) -> void:
	_joystick.drag_to(event.index, event.position)
	if event.index != _camera_touch:
		return
	var delta := event.position - _camera_last
	if not _camera_moved and delta.length() < DRAG_SLOP:
		return
	_camera_moved = true
	_camera_last = event.position
	camera_dragged.emit(delta)


func _over_button(position: Vector2) -> bool:
	return _button.visible and _button.get_global_rect().has_point(position)
