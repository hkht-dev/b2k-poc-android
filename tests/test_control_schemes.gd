## Tests the control scheme switch (docs/BRIEF_AMENDMENT_1.md §A5; owner
## request 2026-10-20: desktop web and mobile web should not share the
## touch layout). Touch keeps the joystick and its zone; desktop and gamepad
## hide it, so a drag anywhere orbits and the keys move.
extends GutTest

const CONTROLS := preload("res://scenes/ui/TouchControls.tscn")
const HINT := preload("res://scripts/ui/controls_hint.gd")


func _controls(scheme: String) -> Control:
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	controls.size = Vector2(1080, 1920)
	controls.joystick().size = controls.size
	controls.apply_scheme(scheme)
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


func test_the_scheme_is_detected_without_a_touchscreen_as_desktop() -> void:
	# The test runner has no touchscreen and no joypad.
	if not Input.get_connected_joypads().is_empty():
		pending("a joypad is connected on this machine")
		return
	assert_eq(HINT.detect_scheme(), "desktop")
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	assert_eq(controls.scheme(), "desktop", "the controls pick the detected scheme up")
	assert_false(controls.joystick().visible, "and show no joystick on a desktop")


func test_touch_shows_the_joystick_and_it_owns_the_left_zone() -> void:
	var controls := _controls("touch")
	assert_true(controls.joystick().visible)
	controls._unhandled_input(_touch(0, Vector2(200, 1500), true))
	assert_true(controls.joystick().is_active(), "a left touch is the stick's")


func test_desktop_hides_the_joystick_and_a_left_drag_orbits_instead() -> void:
	var controls := _controls("desktop")
	assert_false(controls.joystick().visible)
	watch_signals(controls)
	controls._unhandled_input(_touch(0, Vector2(200, 1500), true))
	assert_false(controls.joystick().is_active(), "no stick to claim it")
	controls._unhandled_input(_drag(0, Vector2(260, 1500)))
	controls._unhandled_input(_drag(0, Vector2(320, 1500)))
	assert_signal_emitted(controls, "camera_dragged", "the drag went to the camera")
	assert_true(controls.move_vector().is_zero_approx(), "and nothing moved the player")


func test_gamepad_hides_the_joystick_too() -> void:
	var controls := _controls("gamepad")
	assert_false(controls.joystick().visible)


func test_switching_back_to_touch_brings_the_joystick_back() -> void:
	var controls := _controls("desktop")
	controls.apply_scheme("touch")
	assert_true(controls.joystick().visible)
	controls._unhandled_input(_touch(0, Vector2(200, 1500), true))
	assert_true(controls.joystick().is_active())
