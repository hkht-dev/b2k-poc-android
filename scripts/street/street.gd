## Hollow Vale, the Street. Wires input to the player and camera, and owns
## pause.
##
## GDD §3 Act 3 "Arrival", CLAUDE_CODE_BRIEF.md §4.1, docs/BRIEF_AMENDMENT_1.md
## §A. This script owns no gameplay rules: it is the seam between input and
## the two things that consume it.
##
## All pointing input arrives as screen touches (mouse emulated into them on
## desktop); there is deliberately no second mouse-motion path, because
## Android emulates mouse events from touches too and a second path made
## every thumb on the joystick swing the camera.
extends Node3D

const PAUSE_MENU := preload("res://scenes/ui/PauseMenu.tscn")
const PLAYER_HUM := preload("res://assets/audio/player_hum.ogg")
const STREET_BED := preload("res://assets/audio/street_bed.ogg")
## How far the player's hum carries to anything that can answer it.
const HUM_REACH := 40.0
const CONTROLS_HINT := preload("res://scenes/ui/ControlsHint.tscn")
## §A4: touch sensitivity is half the desktop default.
const TOUCH_SENSITIVITY := 0.5
const DESKTOP_SENSITIVITY := 1.0

var _pause_menu: Control = null
var _controls_overlay: Control = null
var _near: Interactable = null
var _hum_player: AudioStreamPlayer = null
var _bed_player: AudioStreamPlayer = null

@onready var _player: CharacterBody3D = %Player
@onready var _camera_rig: Node3D = %CameraRig
@onready var _controls: Control = %TouchControls
@onready var _ui: CanvasLayer = $UI


func _ready() -> void:
	_apply_settings()
	_controls.camera_dragged.connect(_on_camera_dragged)
	_controls.tapped.connect(_on_tapped)
	_controls.pause_pressed.connect(pause)
	_controls.minimap().bind(self, _player)
	_controls.contextual_button().verb_used.connect(_on_verb_used)
	_controls.contextual_button().hummed.connect(hum)
	_hum_player = AudioStreamPlayer.new()
	_hum_player.stream = PLAYER_HUM
	add_child(_hum_player)
	_bed_player = AudioStreamPlayer.new()
	_bed_player.stream = STREET_BED
	_bed_player.volume_db = -10.0
	add_child(_bed_player)
	_bed_player.play()
	_player.moved_first_time.connect(func() -> void: _controls.joystick().dismiss_hint())
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(_delta: float) -> void:
	_scan_interactables()
	if _player.is_climbing():
		_player.set_move_input(Vector2.ZERO, 0.0)
		return
	_player.set_move_input(
		_camera_rig.stick_to_world(_controls.move_vector()), _controls.move_deflection()
	)


## The nearest usable thing the player stands in decides the button's verb.
func _scan_interactables() -> void:
	var best: Interactable = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var area := node as Interactable
		if area == null or not area.is_available() or not area.overlaps_body(_player):
			continue
		var distance := area.global_position.distance_to(_player.global_position)
		if distance < best_distance:
			best = area
			best_distance = distance
	_near = best
	_controls.contextual_button().show_verb(best.verb_id if best != null else "")


func near() -> Interactable:
	return _near


func _on_verb_used(_verb_id: String) -> void:
	if _near == null or is_paused():
		return
	var target := _near
	if (
		target.is_in_group(Interactable.SOUND_SOURCE_GROUP)
		or target.get_parent().is_in_group(Interactable.SOUND_SOURCE_GROUP)
	):
		_camera_rig.drift_toward(target.global_position, 1.5)
		_controls.subtitle("sub.tulu_hum")
	target.use(_player)


## The Call (GDD §6): the player hums; anything that can answer, does.
func hum() -> void:
	if is_paused() or _player.is_climbing():
		return
	_hum_player.play()
	_controls.subtitle("sub.player_hum")
	GameState.record_hum()
	for node in get_tree().get_nodes_in_group(Interactable.SOUND_SOURCE_GROUP):
		var source := node as Node3D
		if source == null or not source.has_method("hear_hum"):
			continue
		if source.global_position.distance_to(_player.global_position) <= HUM_REACH:
			source.hear_hum()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("contextual"):
		_controls.contextual_button().button_down.emit()
		if _near != null:
			_controls.contextual_button().pressed.emit()
	elif event.is_action_released("contextual"):
		_controls.contextual_button().button_up.emit()
	if event.is_action_pressed("pause"):
		if is_paused():
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()


## §A6: settings live in the journey. Defaults differ by device.
func _apply_settings() -> void:
	var settings: Dictionary = GameState.settings
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	var default_sensitivity := TOUCH_SENSITIVITY if touch else DESKTOP_SENSITIVITY
	_camera_rig.sensitivity = float(settings.get("camera_sensitivity", default_sensitivity))
	_camera_rig.invert_y = bool(settings.get("camera_invert_y", false))
	var stick: Control = _controls.joystick()
	stick.side = str(settings.get("joystick_side", "left"))
	stick.radius = float(settings.get("joystick_size", stick.radius))
	stick.max_opacity = float(settings.get("joystick_opacity", stick.max_opacity))


func tap_to_walk_enabled() -> bool:
	return bool(GameState.settings.get("tap_to_walk", true))


func is_paused() -> bool:
	return _pause_menu != null


func pause() -> void:
	if _pause_menu != null:
		return
	_pause_menu = PAUSE_MENU.instantiate()
	_pause_menu.resumed.connect(resume)
	_pause_menu.controls_requested.connect(_show_controls)
	_pause_menu.map_toggled.connect(
		func(_on: bool) -> void: _controls.minimap().refresh_visibility()
	)
	_ui.add_child(_pause_menu)
	get_tree().paused = true


func resume() -> void:
	if _pause_menu == null:
		return
	_ui.remove_child(_pause_menu)
	_pause_menu.queue_free()
	_pause_menu = null
	get_tree().paused = false


func _show_controls() -> void:
	if _controls_overlay != null:
		return
	_controls_overlay = CONTROLS_HINT.instantiate()
	_controls_overlay.from_pause = true
	_controls_overlay.dismissed.connect(
		func() -> void:
			_ui.remove_child(_controls_overlay)
			_controls_overlay.queue_free()
			_controls_overlay = null
	)
	_ui.add_child(_controls_overlay)


func _on_camera_dragged(delta: Vector2) -> void:
	if is_paused():
		return
	_camera_rig.orbit(delta)


## §A3: a tap on the right zone walks the player to that point on the ground.
func _on_tapped(screen: Vector2) -> void:
	if is_paused() or not tap_to_walk_enabled() or _player.is_climbing():
		return
	var point: Variant = _camera_rig.ground_point(screen)
	if point != null:
		_player.walk_to(point)
