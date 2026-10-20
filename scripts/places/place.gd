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
##
## Driving (owner request 2026-10-20, "enter inside cars, drive"): a
## DriveableCar's *Drive* boards the player here; the stick then goes to the
## car, the button says the car's exit verb, and using it puts the player
## back on their feet beside it. The journey never records a seat.
class_name Place
extends Node3D

## The player used a door: this place has faded; Main shows the next one.
signal place_requested(place_id: String, spawn_id: String)
## The player left the journey from the pause menu; Main shows the title.
signal quit_requested

const PAUSE_MENU := preload("res://scenes/ui/PauseMenu.tscn")
const PLAYER_HUM := preload("res://assets/audio/player_hum.ogg")
## How far the player's hum carries to anything that can answer it.
const HUM_REACH := 40.0
const CONTROLS_HINT := preload("res://scenes/ui/ControlsHint.tscn")
const CHOICE_CARDS := preload("res://scenes/ui/ChoiceCards.tscn")
const DROPPED_ITEM := preload("res://scenes/quest/DroppedItem.tscn")
const SETTINGS_SCREEN := preload("res://scenes/ui/SettingsScreen.tscn")
# -- lamps (GDD §16a): the block at the end of this file ------------------------
const LAMP_LINES_SCREEN := preload("res://scenes/ui/LampLinesScreen.tscn")
const LAMP := preload("res://scenes/quest/Lamp.tscn")
## How long a lamp's line stays on screen after *Sit*.
const LAMP_LINE_SECONDS := 4.0
const LAMPS_NODE := "Lamps"
# -- end lamps ------------------------------------------------------------------
## Optional wisdom (GDD §6, §9): the card the lotus opens.
const WISDOM_CARD := preload("res://scenes/ui/WisdomCard.tscn")
const LARGE_TEXT_SCALE := 1.2
## §A4: touch sensitivity is half the desktop default.
const TOUCH_SENSITIVITY := 0.5
const DESKTOP_SENSITIVITY := 1.0
## Through a door the view goes black over this long, and comes back as long.
const DOOR_FADE_SECONDS := 0.45
## The verb the one button shows with a full hand and nothing else near.
const PUT_DOWN_VERB := "verb.put_down"
## How far in front of the feet a set-down thing lands.
const DROP_REACH := 0.7
## Arriving through a door, the place's name is the first subtitle, this long
## (GDD §11 allows subtitles; owner request 2026-10-20 "where am I").
const PLACE_NAME_SECONDS := 2.5

## Slower than this, horizontally, the player is standing (walking is 2.2).
const ROUTE_MOVING_SPEED := 0.3

## This place's id in data/places.json.
@export var place_id := "street"
## GDD §16a "Path card": on the street, where the player stands joins
## GameState.route every this many seconds of walking.
@export var route_sample_seconds := 3.0

var _pause_menu: Control = null
var _controls_overlay: Control = null
var _settings_overlay: Control = null
var _wisdom_card: Control = null
var _near: Interactable = null
var _hum_player: AudioStreamPlayer = null
var _cards: Control = null
var _fade: ColorRect = null
## Set while the player may not move: leaving through a door, or the end.
var _input_locked := false
var _leaving := false
## Path card (GDD §16a): whether this place is the one the card draws, and
## the time walked since the last sample.
var _tracks_route := false
var _route_clock := 0.0

# -- lamps ----------------------------------------------------------------------
var _lamps_root: Node3D = null
var _lamp_lines_overlay: Control = null
# -- end lamps ------------------------------------------------------------------
## -- driving: the car the player is at the wheel of, or null on foot --------
var _car: DriveableCar = null
var _player_layer := 0
var _player_mask := 0

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
	_cards.apply_scheme(_controls.scheme())
	_controls.scheme_changed.connect(_cards.apply_scheme)
	# Optional wisdom (GDD §6, §9): a flag may offer a card; the lotus opens it.
	GameState.flag_changed.connect(_on_wisdom_trigger)
	_controls.lotus().opened.connect(_open_wisdom_card)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)
	for node in get_tree().get_nodes_in_group(Door.GROUP):
		(node as Door).used_door.connect(_on_door_used)
	for node in get_tree().get_nodes_in_group(DriveableCar.GROUP):
		(node as DriveableCar).board_requested.connect(board)
	# -- Path card (GDD §16a) ----------------------------------------------------
	_tracks_route = place_id == GameState.ROUTE_PLACE
	_route_clock = route_sample_seconds  # the first step of a walk is on the card
	if _tracks_route:
		PathCard.remember_blocks(_controls.minimap().footprints())
	# ---------------------------------------------------------------------------
	if _place_at_spawn():
		# Arrived through a door: the view comes back from black, and the
		# place says its name once.
		var name_id := Places.name_id_of(place_id)
		if not name_id.is_empty():
			_controls.subtitle(name_id, PLACE_NAME_SECONDS)
		_fade.color.a = 1.0
		create_tween().tween_property(_fade, "color:a", 0.0, DOOR_FADE_SECONDS)
	_lamps_ready()  # lamps


func _physics_process(delta: float) -> void:
	if not is_paused() and not _input_locked:
		GameState.add_play_time(delta)
		_sample_route(delta)
	_scan_interactables()
	_controls.compass().set_heading(heading())
	if _car != null:
		_drive()
		return
	if _player.is_climbing() or _input_locked:
		_player.set_move_input(Vector2.ZERO, 0.0)
		return
	_player.set_move_input(
		_camera_rig.stick_to_world(_controls.move_vector()), _controls.move_deflection()
	)


## Which way the player is going, as the body's yaw (0 faces north, -Z); at
## the wheel, the car's.
func heading() -> float:
	return _car.rotation.y if _car != null else _player.rotation.y


# -- Path card (GDD §16a) -------------------------------------------------------


## Every route_sample_seconds of walking about the street, where the player
## stands joins GameState.route. Standing still adds nothing, and the shop
## interiors are not on the card.
func _sample_route(delta: float) -> void:
	if not _tracks_route:
		return
	if Vector2(_player.velocity.x, _player.velocity.z).length() < ROUTE_MOVING_SPEED:
		return
	_route_clock += delta
	if _route_clock < route_sample_seconds:
		return
	_route_clock = 0.0
	GameState.add_route_point(_player.global_position.x, _player.global_position.z)


# -------------------------------------------------------------------------------


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
	if _car != null:
		_near = null
		_controls.contextual_button().show_verb(_car.exit_verb_id)
		return
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
	if best != null:
		_controls.contextual_button().show_verb(best.verb_id)
		return
	# Nothing usable here. A full hand can always be emptied, so no item is
	# ever carried with no way back (docs/DECISIONS.md "Nothing is carried
	# for ever"); a hold is still the Call.
	var free_hand: bool = _player.is_carrying() and not _player.is_climbing() and not _leaving
	_controls.contextual_button().show_verb(PUT_DOWN_VERB if free_hand else "")


func near() -> Interactable:
	return _near


## The hand is emptied where the player stands, and what was in it lies
## there to be picked up again (scenes/quest/DroppedItem.tscn). The item's
## look is the scene the hand was holding, so this knows no item by name.
func put_down_carried() -> Node3D:
	var item: String = _player.carried_item()
	if item.is_empty():
		return null
	var dropped: Node3D = DROPPED_ITEM.instantiate()
	dropped.item = item
	dropped.model = _player.carryables.get(item)
	add_child(dropped)
	var ahead := -_player.global_transform.basis.z
	ahead.y = 0.0
	if ahead.length() < 0.01:
		ahead = Vector3.FORWARD
	dropped.global_position = _player.global_position + ahead.normalized() * DROP_REACH
	_player.put_down()
	return dropped


func cards() -> Control:
	return _cards


func player() -> CharacterBody3D:
	return _player


func _on_verb_used(verb_id: String) -> void:
	if _car != null:
		if verb_id == _car.exit_verb_id and not is_paused():
			leave_car()
		return
	if is_paused() or _input_locked:
		return
	if _near == null:
		if verb_id == PUT_DOWN_VERB:
			put_down_carried()
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
	if is_paused() or _player.is_climbing() or _input_locked or _car != null:
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


## Whether the player's hum is sounding now (GDD §6 "Call"). A Tell may
## need it (GDD §6 "Tells": "a clock that stops while the hum is held").
func is_humming() -> bool:
	return _hum_player != null and _hum_player.playing


## Says something on the HUD for a while: a subtitle from the string table.
func subtitle(text_id: String, seconds: float = 2.5) -> void:
	_controls.subtitle(text_id, seconds)


## A door was used: the journey remembers where the player is going and on
## which spawn point to land, the view fades, and Main swaps the place.
func _on_door_used(target_place: String, spawn_id: String) -> void:
	if _leaving or _input_locked:
		return
	_leaving = true
	_input_locked = true
	_player.set_move_input(Vector2.ZERO, 0.0)
	# One runner serves every place (Content.dialogue): a line still on the
	# cards would outlive this place and hold the next one's people.
	if Content.dialogue.is_running():
		Content.dialogue.dismiss()
	GameState.set_place(target_place, spawn_id)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, DOOR_FADE_SECONDS)
	tween.tween_callback(func() -> void: place_requested.emit(target_place, spawn_id))


## The player asked to leave the journey: the world unpauses and Main is
## told, so the title screen comes back. Nothing is wiped — the journey is
## saved and waiting (GDD §11 lists quit among the pause menu's contents).
func _on_quit_requested() -> void:
	resume()
	quit_requested.emit()


func is_leaving() -> bool:
	return _leaving


func fade_alpha() -> float:
	return _fade.color.a


# -- driving ------------------------------------------------------------------
# Owner request 2026-10-20 ("enter inside cars, drive"). GDD §6: movement is
# the first of the five things the player does; a car is that at another
# pace. Nothing here is saved: the journey knows places and spawn points,
# never a seat, so a reloaded journey is on foot (docs/DECISIONS.md).


## The player used *Drive*: they vanish into the car, the camera steps back
## to see it, and the stick is the car's until they get out.
func board(car: DriveableCar) -> void:
	if _car != null or car == null or is_paused() or _input_locked or _player.is_climbing():
		return
	_car = car
	_player.set_move_input(Vector2.ZERO, 0.0)
	_player.velocity = Vector3.ZERO
	_player_layer = _player.collision_layer
	_player_mask = _player.collision_mask
	_player.collision_layer = 0
	_player.collision_mask = 0
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.visible = false
	_player.global_position = car.global_position
	_camera_rig.target_path = _camera_rig.get_path_to(car)
	_camera_rig.set_follow_profile(_camera_rig.PROFILE_CAR)
	car.start_driving()


## *Get out*: the player stands beside the car's door, on their feet again.
func leave_car() -> void:
	if _car == null:
		return
	var car := _car
	_car = null
	car.stop_driving()
	_player.global_position = car.door_point() + Vector3.UP * 0.2
	_player.rotation.y = car.rotation.y
	_player.velocity = Vector3.ZERO
	_player.collision_layer = _player_layer
	_player.collision_mask = _player_mask
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_player.visible = true
	# A tap-to-walk begun before boarding ends where the player now stands.
	_player.walk_to(_player.global_position)
	_camera_rig.target_path = _camera_rig.get_path_to(_player)
	_camera_rig.set_follow_profile(_camera_rig.PROFILE_WALK)
	_controls.contextual_button().clear_verb()


func is_driving() -> bool:
	return _car != null


func car() -> DriveableCar:
	return _car


## At the wheel: the raw stick is the car's (its Y the throttle, its X the
## wheel, no camera frame), and the hidden player rides along inside.
func _drive() -> void:
	_car.set_drive_input(Vector2.ZERO if _input_locked else _controls.move_vector())
	_player.global_position = _car.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("contextual"):
		# Optional wisdom: with nothing usable near and no wheel in hand, the
		# action opens the offered card; near something, or at the wheel, the
		# thing wins (the card is optional).
		if (
			_near == null
			and _car == null
			and not is_paused()
			and not _input_locked
			and _controls.lotus().open()
		):
			get_viewport().set_input_as_handled()
			return
		_controls.contextual_button().button_down.emit()
		if _near != null or _car != null:
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


## The world stands still under the pause menu and under an open wisdom
## card (GDD §9: "the game pauses while one is open").
func is_paused() -> bool:
	return _pause_menu != null or _wisdom_card != null


func pause() -> void:
	if _pause_menu != null or _wisdom_card != null:
		return
	_pause_menu = PAUSE_MENU.instantiate()
	_pause_menu.resumed.connect(resume)
	_pause_menu.controls_requested.connect(_show_controls)
	_pause_menu.settings_requested.connect(_show_settings)
	_pause_menu.lamp_requested.connect(_show_lamp_lines)  # lamps
	_pause_menu.quit_requested.connect(_on_quit_requested)
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


# -- optional wisdom (GDD §6 "Optional wisdom", §9) ---------------------------


## A flag was set: if a card in data/wisdom.json waits on it and has not been
## offered this journey, the lotus pulses. One card per beat; never on a
## clear, never on load (loading emits nothing per flag), and nothing the
## player must do about it. Which cards exist, and when, is data.
func _on_wisdom_trigger(flag: String, is_set: bool) -> void:
	if not is_set:
		return
	for card_id in Wisdom.cards_for_flag(flag):
		if GameState.has_seen_wisdom(card_id):
			continue
		if not Wisdom.is_triggered(card_id, GameState.flags, GameState.events):
			continue
		GameState.mark_wisdom_seen(card_id)
		_controls.lotus().show_card(card_id)
		return


## The lotus was tapped: the card opens and the world pauses under it.
func _open_wisdom_card(card_id: String) -> void:
	if _wisdom_card != null or _pause_menu != null or not Wisdom.has(card_id):
		return
	_wisdom_card = WISDOM_CARD.instantiate()
	_ui.add_child(_wisdom_card)
	_wisdom_card.show_card(card_id)
	_wisdom_card.closed.connect(_close_wisdom_card)
	get_tree().paused = true


func _close_wisdom_card() -> void:
	if _wisdom_card == null:
		return
	_ui.remove_child(_wisdom_card)
	_wisdom_card.queue_free()
	_wisdom_card = null
	get_tree().paused = false


func wisdom_card() -> Control:
	return _wisdom_card


func _on_camera_dragged(delta: Vector2) -> void:
	if is_paused():
		return
	_camera_rig.orbit(delta)


## §A3: a tap on the right zone walks the player to that point on the ground.
func _on_tapped(screen: Vector2) -> void:
	if is_paused() or not tap_to_walk_enabled() or _player.is_climbing() or _input_locked:
		return
	if _car != null:
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
		lamp.position = Vector3(
			float(record.get("x", 0.0)), float(record.get("y", 0.0)), float(record.get("z", 0.0))
		)
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
		"y": at.y,
		"z": at.z,
		"line_id": line_id,
		"lit_day": LampLines.play_day(),
	}
	GameState.set_lamp(record, LampLines.max_per_place())
	_close_lamp_lines()
	resume()
# -- end lamps ------------------------------------------------------------------
