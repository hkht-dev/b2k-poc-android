## Tests docs/BRIEF_AMENDMENT_1.md §A: zones, dead zone and curve, tap-to-walk,
## camera auto-align, pause and the per-device controls card.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const CONTROLS := preload("res://scenes/ui/TouchControls.tscn")
const RIG := preload("res://scenes/player/CameraRig.tscn")
const PLAYER := preload("res://scenes/player/Player.tscn")
const HINT := preload("res://scenes/ui/ControlsHint.tscn")
const SCRATCH := "user://test_controls_journey.json"

var _real_path := ""


func before_each() -> void:
	_real_path = GameState.save_path
	GameState.save_path = SCRATCH
	GameState.set_autosave(false)
	GameState.wipe()


func after_each() -> void:
	get_tree().paused = false
	GameState.wipe()
	GameState.save_path = _real_path
	GameState.set_autosave(true)


func _controls() -> Control:
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	controls.apply_scheme("touch")
	controls.size = Vector2(1080, 1920)
	controls.joystick().size = controls.size
	return controls


func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _drag(index: int, position: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event


# -- §A1 zones ----------------------------------------------------------------


func test_the_joystick_owns_the_left_forty_five_percent() -> void:
	var stick: Control = _controls().joystick()
	assert_true(stick.owns_point(Vector2(1080 * 0.44, 1500)), "just inside the zone")
	assert_false(stick.owns_point(Vector2(1080 * 0.46, 1500)), "just outside it")


func test_one_finger_on_each_side_works_at_once() -> void:
	var controls := _controls()
	watch_signals(controls)
	controls._unhandled_input(_touch(0, Vector2(200, 1500), true))
	controls._unhandled_input(_touch(1, Vector2(800, 900), true))
	controls._unhandled_input(_drag(0, Vector2(200, 1400)))
	controls._unhandled_input(_drag(1, Vector2(860, 900)))
	assert_gt(controls.move_vector().y, 0.0, "the left finger walks")
	assert_signal_emitted(controls, "camera_dragged", "the right finger looks")


# -- §A2 dead zone and curve --------------------------------------------------


func test_a_push_inside_the_dead_zone_does_nothing() -> void:
	var stick: Control = _controls().joystick()
	stick.try_claim(0, Vector2(200, 1500))
	stick.drag_to(0, Vector2(200, 1500 - stick.radius * 0.10))
	assert_eq(stick.vector(), Vector2.ZERO, "under 12% is nothing")
	assert_eq(stick.deflection(), 0.0)


func test_the_response_is_cubic_but_deflection_is_raw() -> void:
	var stick: Control = _controls().joystick()
	stick.try_claim(0, Vector2(200, 1500))
	stick.drag_to(0, Vector2(200, 1500 - stick.radius * 0.56))
	# 0.56 raw, minus the 12% dead zone, renormalised = 0.5 deflection.
	assert_almost_eq(stick.deflection(), 0.5, 0.01, "half deflection")
	assert_almost_eq(stick.vector().length(), 0.125, 0.01, "cubed for the walk")


func test_auto_run_needs_eighty_five_percent_deflection() -> void:
	var player: CharacterBody3D = add_child_autofree(PLAYER.instantiate())
	player.set_move_input(Vector2(0.0, -0.5), 0.8)
	for _i in 8:
		player._physics_process(0.1)
	assert_false(player.is_running(), "80% is a walk")
	player.set_move_input(Vector2(0.0, -0.7), 0.86)
	for _i in 8:
		player._physics_process(0.1)
	assert_true(player.is_running(), "86% held becomes a run")


# -- §A3 tap-to-walk ----------------------------------------------------------


func test_a_quick_still_touch_on_the_right_is_a_tap() -> void:
	var controls := _controls()
	watch_signals(controls)
	controls._unhandled_input(_touch(0, Vector2(800, 900), true))
	controls._unhandled_input(_drag(0, Vector2(804, 902)))
	controls._unhandled_input(_touch(0, Vector2(804, 902), false))
	assert_signal_emitted_with_parameters(controls, "tapped", [Vector2(804, 902)])
	assert_signal_not_emitted(controls, "camera_dragged", "under the slop, no orbit")


func test_a_drag_on_the_right_never_taps() -> void:
	var controls := _controls()
	watch_signals(controls)
	controls._unhandled_input(_touch(0, Vector2(800, 900), true))
	controls._unhandled_input(_drag(0, Vector2(900, 900)))
	controls._unhandled_input(_touch(0, Vector2(900, 900), false))
	assert_signal_not_emitted(controls, "tapped", "dragging never walks")
	assert_signal_emitted(controls, "camera_dragged")


func test_walk_to_carries_the_player_to_the_point_and_stops() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: CharacterBody3D = street.get_node("%Player")
	# On the road: the one strip of the block guaranteed free of buildings.
	player.global_position = Vector3(-10.0, 0.3, 16.0)
	await wait_frames(10)
	player.walk_to(Vector3(-6.0, 0.0, 16.0))
	assert_true(player.is_walking_to())
	await wait_frames(200)
	assert_false(player.is_walking_to(), "arrived")
	assert_almost_eq(player.global_position.x, -6.0, player.ARRIVE_DISTANCE + 0.1)


func test_the_stick_cancels_a_walk_to() -> void:
	var player: CharacterBody3D = add_child_autofree(PLAYER.instantiate())
	player.walk_to(Vector3(10.0, 0.0, 0.0))
	player.set_move_input(Vector2(0.0, -1.0), 1.0)
	assert_false(player.is_walking_to(), "the thumb wins")


func test_a_tap_in_the_street_walks_the_player() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: CharacterBody3D = street.get_node("%Player")
	var controls: Control = street.get_node("%TouchControls")
	controls.apply_scheme("touch")
	controls.size = Vector2(1080, 1920)
	player.global_position = Vector3(-10.0, 0.3, 16.0)
	await wait_frames(3)
	controls.tapped.emit(Vector2(540, 1700))
	assert_true(player.is_walking_to(), "the tap found ground")


# -- §A4 auto-align ----------------------------------------------------------


func test_the_camera_eases_behind_a_sustained_run() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: CharacterBody3D = street.get_node("%Player")
	var rig: Node3D = street.get_node("%CameraRig")
	var controls: Control = street.get_node("%TouchControls")
	controls.apply_scheme("touch")
	controls.size = Vector2(1080, 1920)
	controls.joystick().size = controls.size
	player.global_position = Vector3(0.0, 0.05, 40.0)
	rig.orbit(Vector2(400.0, 0.0))
	var turned: float = rig.get_yaw()
	controls.joystick().try_claim(0, Vector2(200, 1500))
	controls.joystick().drag_to(0, Vector2(200, 1500 - 140))
	await wait_frames(150)
	assert_true(player.is_running())
	var drift := absf(angle_difference(rig.get_yaw(), player.rotation.y))
	assert_lt(
		drift, absf(angle_difference(turned, player.rotation.y)), "the camera came round behind"
	)


func test_touch_devices_get_half_sensitivity_by_default() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var rig: Node3D = street.get_node("%CameraRig")
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	assert_almost_eq(
		rig.sensitivity, street.TOUCH_SENSITIVITY if touch else street.DESKTOP_SENSITIVITY, 0.001
	)


# -- §A5 pause and the card ---------------------------------------------------


func test_pause_opens_a_menu_with_controls_and_stops_the_world() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	# No awaits while paused: GUT's own frame waits stop with the tree.
	street.pause()
	assert_true(street.is_paused())
	assert_true(get_tree().paused, "the street stands still")
	street._pause_menu.controls_requested.emit()
	assert_not_null(street._controls_overlay, "the card is reachable from pause")
	street._controls_overlay.dismissed.emit()
	assert_null(street._controls_overlay, "and closes again")
	street.resume()
	assert_false(get_tree().paused)
	assert_false(street.is_paused())


func test_the_card_names_a_scheme_and_six_lines() -> void:
	var hint: Control = add_child_autofree(HINT.instantiate())
	await wait_frames(1)
	assert_true(["touch", "desktop", "gamepad"].has(hint.current_scheme()))
	assert_eq(
		hint.get_node("%Lines").get_child_count(), 6, "move, look, walk there, use, hum, doors"
	)


func test_the_card_names_a_scheme_and_a_line_per_key() -> void:
	var hint: Control = add_child_autofree(HINT.instantiate())
	await wait_frames(1)
	assert_true(["touch", "desktop", "gamepad"].has(hint.current_scheme()))
	assert_eq(hint.get_node("%Lines").get_child_count(), hint.LINE_KEYS.size())


func test_the_hint_shows_until_the_player_first_moves() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	var stick: Control = street.get_node("%TouchControls").joystick()
	assert_true(stick.hint_visible(), "a new player sees the hint")
	street.get_node("%Player").moved_first_time.emit()
	assert_false(stick.hint_visible(), "and it goes on the first move")
