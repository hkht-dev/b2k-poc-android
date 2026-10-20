## A place the player walks about in: the street, or the inside of a shop.
##
## Owner expansion 2026-10-20 (docs/DECISIONS.md "The world grows"): the
## Street was the one scene; now a door leads to another place and back, and
## every place needs the same seam between input and the player, the camera
## and the HUD. This is that seam, lifted out of scripts/street/street.gd,
## which now only adds what is the street's own.
##
## It owns no gameplay rules. Which doors lead where, and where the player
## lands, is data on the Door and SpawnPoint nodes; which scene a place id
## names is data/places.json. Pointing input arrives as screen touches, as it
## always did (see street.gd's history for why there is no mouse path).
class_name Place
extends Node3D

## The player used a door: this place has faded; Main shows the next one.
signal place_requested(place_id: String, spawn_id: String)

const PAUSE_MENU := preload("res://scenes/ui/PauseMenu.tscn")
const PLAYER_HUM := preload("res://assets/audio/player_hum.ogg")
## How far the player's hum carries to anything that can answer it.
const HUM_REACH := 40.0
const CONTROLS_HINT := preload("res://scenes/ui/ControlsHint.tscn")
const CHOICE_CARDS := preload("res://scenes/ui/ChoiceCards.tscn")
const SETTINGS_SCREEN := preload("res://scenes/ui/SettingsScreen.tscn")
# -- lamps (GDD §16a): the block at the end of this file ------------------------
const LAMP_LINES_SCREEN := preload("res://scenes/ui/LampLinesScreen.tscn")
const LAMP := preload("res://scenes/quest/Lamp.tscn")
## How long a lamp's line stays on screen after *Sit*.
const LAMP_LINE_SECONDS := 4.0
const LAMPS_NODE := "Lamps"
# -- end lamps ------------------------------------------------------------------
const LARGE_TEXT_SCALE := 1.2
## §A4: touch sensitivity is half the desktop default.
const TOUCH_SENSITIVITY := 0.5
const DESKTOP_SENSITIVITY := 1.0
## Through a door the view goes black over this long, and comes back as long.
const DOOR_FADE_SECONDS := 0.45

## This place's id in data/places.json.
@export var place_id := "street"

var _pause_menu: Control = null
var _controls_overlay: Control = null
var _settings_overlay: Control = null
var _near: Interactable = null
var _hum_player: AudioStreamPlayer = null
var _cards: Control = null
var _fade: ColorRect = null
## Set while the player may not move: leaving through a door, or the end.
var _input_locked := false
var _leaving := false
# -- lamps ----------------------------------------------------------------------
var _lamps_root: Node3D = null
var _lamp_lines_overlay: Control = null
# -- end lamps ------------------------------------------------------------------

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
	_player.moved_first_time.connect(func() -> void: _controls.joystick().dismiss_hint())
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_cards = CHOICE_CARDS.instantiate()
	_ui.add_child(_cards)
	_cards.bind(Content.dialogue)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)
	for node in get_tree().get_nodes_in_group(Door.GROUP):
		(node as Door).used_door.connect(_on_door_used)
	if _place_at_spawn():
		# Arrived through a door: the view comes back from black.
		_fade.color.a = 1.0
		create_tween().tween_property(_fade, "color:a", 0.0, DOOR_FADE_SECONDS)
	_lamps_ready()  # lamps


func _physics_process(delta: float) -> void:
	if not is_paused() and not _input_locked:
		GameState.add_play_time(delta)
	_scan_interactables()
	_controls.compass().set_heading(heading())
	if _player.is_climbing() or _input_locked:
		_player.set_move_input(Vector2.ZERO, 0.0)
		return
	_player.set_move_input(
		_camera_rig.stick_to_world(_controls.move_vector()), _controls.move_deflection()
	)


## Which way the player is going, as the body's yaw (0 faces north, -Z).
func heading() -> float:
	return _player.rotation.y


## Puts the player on the spawn point the journey names, if this place has
## it. Returns whether it did. A journey with no spawn (a fresh one) leaves
## the player where the scene put them.
func _place_at_spawn() -> bool:
	var wanted: String = GameState.spawn
	if wanted.is_empty():
		return false
	for node in get_tree().get_nodes_in_group(SpawnPoint.GROUP):
		var point := node as SpawnPoint
		if point == null or point.spawn_id != wanted:
			continue
		_player.global_position = point.global_position
		_player.rotation.y = point.global_rotation.y
		_camera_rig.snap_behind(point.global_rotation.y)
		return true
	return false


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


func cards() -> Control:
	return _cards


func player() -> CharacterBody3D:
	return _player


func _on_verb_used(_verb_id: String) -> void:
	if _near == null or is_paused() or _input_locked:
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
	if is_paused() or _player.is_climbing() or _input_locked:
		return
	_hum_player.play()
	_controls.subtitle("sub.player_hum")
	var ripple: SoundRipple = _player.get_node_or_null("%Ripple")
	if ripple != null:
		ripple.pulse()
	GameState.record_hum()
	for node in get_tree().get_nodes_in_group(Interactable.SOUND_SOURCE_GROUP):
		var source := node as Node3D
		if source == null or not source.has_method("hear_hum"):
			continue
		if source.global_position.distance_to(_player.global_position) <= HUM_REACH:
			source.hear_hum()


## A door was used: the journey remembers where the player is going and on
## which spawn point to land, the view fades, and Main swaps the place.
func _on_door_used(target_place: String, spawn_id: String) -> void:
	if _leaving or _input_locked:
		return
	_leaving = true
	_input_locked = true
	_player.set_move_input(Vector2.ZERO, 0.0)
	GameState.set_place(target_place, spawn_id)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, DOOR_FADE_SECONDS)
	tween.tween_callback(func() -> void: place_requested.emit(target_place, spawn_id))


func is_leaving() -> bool:
	return _leaving


func fade_alpha() -> float:
	return _fade.color.a


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
	_controls.set_subtitle_box(bool(settings.get("subtitle_box", false)))
	get_tree().root.content_scale_factor = (
		LARGE_TEXT_SCALE if bool(settings.get("large_text", false)) else 1.0
	)
	var cues := bool(settings.get("sound_cues", false))
	for node in get_tree().get_nodes_in_group(SoundRipple.GROUP):
		(node as SoundRipple).enabled = cues
	_controls.compass().refresh_visibility()


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
	_pause_menu.settings_requested.connect(_show_settings)
	_pause_menu.lamp_requested.connect(_show_lamp_lines)  # lamps
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


func _show_settings() -> void:
	if _settings_overlay != null:
		return
	_settings_overlay = SETTINGS_SCREEN.instantiate()
	_settings_overlay.changed.connect(func(_key: String) -> void: _apply_settings())
	_settings_overlay.closed.connect(
		func() -> void:
			_ui.remove_child(_settings_overlay)
			_settings_overlay.queue_free()
			_settings_overlay = null
	)
	_ui.add_child(_settings_overlay)


func settings_overlay() -> Control:
	return _settings_overlay


func _on_camera_dragged(delta: Vector2) -> void:
	if is_paused():
		return
	_camera_rig.orbit(delta)


## §A3: a tap on the right zone walks the player to that point on the ground.
func _on_tapped(screen: Vector2) -> void:
	if is_paused() or not tap_to_walk_enabled() or _player.is_climbing() or _input_locked:
		return
	var point: Variant = _camera_rig.ground_point(screen)
	if point != null:
		_player.walk_to(point)


# -- lamps (GDD §16a "Social: lamps") -------------------------------------------
# Owner expansion 2026-10-20. Every lamp of this place in the journey stands
# here as a small light (scenes/quest/Lamp.tscn); *Set a lamp here* on the
# pause menu opens the twelve lines and sets one down where the player is.
# No network: the lamps are the player's own (docs/DECISIONS.md).


func _lamps_ready() -> void:
	_lamps_root = Node3D.new()
	_lamps_root.name = LAMPS_NODE
	add_child(_lamps_root)
	GameState.lamp_set.connect(_on_lamp_set)
	_sync_lamps()


## The lamp nodes standing in this place.
func lamps() -> Array[Lamp]:
	var out: Array[Lamp] = []
	if _lamps_root != null:
		for node in _lamps_root.get_children():
			out.append(node as Lamp)
	return out


func lamp_lines_overlay() -> Control:
	return _lamp_lines_overlay


## One Lamp node per record of this place that still burns: none for another
## place's lamps, none for a lamp that has faded (LampLines.is_lit).
func _sync_lamps() -> void:
	var wanted: Array[Dictionary] = []
	for record in GameState.lamps_in(place_id):
		if LampLines.is_lit(record):
			wanted.append(record)
	for node in _lamps_root.get_children():
		var lamp := node as Lamp
		var index := _index_of_record(wanted, lamp.lamp)
		if index < 0:
			_lamps_root.remove_child(lamp)
			lamp.queue_free()
		else:
			wanted.remove_at(index)
	for record in wanted:
		var lamp: Lamp = LAMP.instantiate()
		lamp.lamp = record
		lamp.position = Vector3(float(record.get("x", 0.0)), 0.0, float(record.get("z", 0.0)))
		lamp.sat.connect(_on_lamp_sat)
		_lamps_root.add_child(lamp)


static func _index_of_record(records: Array[Dictionary], record: Dictionary) -> int:
	for index in records.size():
		if is_same(records[index], record):
			return index
	return -1


func _on_lamp_set(_lamp: Dictionary) -> void:
	_sync_lamps()


## *Sit* by a lamp: its line, as a subtitle, for a moment.
func _on_lamp_sat(line_id: String) -> void:
	_controls.subtitle(line_id, LAMP_LINE_SECONDS)


func _show_lamp_lines() -> void:
	if _lamp_lines_overlay != null or _input_locked or _leaving:
		return
	_lamp_lines_overlay = LAMP_LINES_SCREEN.instantiate()
	_lamp_lines_overlay.chosen.connect(_on_lamp_line_chosen)
	_lamp_lines_overlay.closed.connect(_close_lamp_lines)
	_ui.add_child(_lamp_lines_overlay)


func _close_lamp_lines() -> void:
	if _lamp_lines_overlay == null:
		return
	_ui.remove_child(_lamp_lines_overlay)
	_lamp_lines_overlay.queue_free()
	_lamp_lines_overlay = null


## A line was chosen: the lamp goes down where the player stands, into the
## journey first (this place then shows it), and play resumes.
func _on_lamp_line_chosen(line_id: String) -> void:
	if not LampLines.has_line(line_id):
		return
	var at := _player.global_position
	var record := {
		"place": place_id,
		"x": at.x,
		"z": at.z,
		"line_id": line_id,
		"lit_day": LampLines.play_day(),
	}
	GameState.set_lamp(record, LampLines.max_per_place())
	_close_lamp_lines()
	resume()
# -- end lamps ------------------------------------------------------------------
