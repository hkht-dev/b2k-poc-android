## Tests the camera rig's orbit maths and the on-screen controls.
##
## The stick-to-world mapping is the one place where a sign error makes the
## game feel broken but never errors, so it is pinned down here.
extends GutTest

const RIG := preload("res://scenes/player/CameraRig.tscn")
const CONTROLS := preload("res://scenes/ui/TouchControls.tscn")


func test_pushing_the_stick_up_moves_away_from_the_camera() -> void:
	var rig: Node3D = add_child_autofree(RIG.instantiate())
	# Screen-up is y = +1 from the joystick; forward in Godot is -Z.
	var world: Vector2 = rig.stick_to_world(Vector2(0.0, 1.0))
	assert_almost_eq(world.x, 0.0, 0.001, "no sideways drift")
	assert_lt(world.y, -0.9, "forward is -Z")


func test_pushing_the_stick_right_moves_along_plus_x() -> void:
	var rig: Node3D = add_child_autofree(RIG.instantiate())
	var world: Vector2 = rig.stick_to_world(Vector2(1.0, 0.0))
	assert_gt(world.x, 0.9, "right on the stick is +X at zero yaw")
	assert_almost_eq(world.y, 0.0, 0.001)


func test_orbiting_a_quarter_turn_rotates_the_movement_frame() -> void:
	var rig: Node3D = add_child_autofree(RIG.instantiate())
	var before: Vector2 = rig.stick_to_world(Vector2(0.0, 1.0))
	rig.orbit(Vector2(1000.0, 0.0))
	var after: Vector2 = rig.stick_to_world(Vector2(0.0, 1.0))
	assert_ne(rig.get_yaw(), 0.0, "the drag turned the camera")
	assert_gt(before.distance_to(after), 0.1, "forward follows the camera round")
	assert_almost_eq(after.length(), 1.0, 0.001, "and keeps its magnitude")


func test_pitch_is_clamped_at_both_ends() -> void:
	var rig: Node3D = add_child_autofree(RIG.instantiate())
	rig.orbit(Vector2(0.0, 100000.0))
	assert_between(rig.get_pitch(), rig.PITCH_MIN, rig.PITCH_MAX, "clamped looking one way")
	rig.orbit(Vector2(0.0, -200000.0))
	assert_between(rig.get_pitch(), rig.PITCH_MIN, rig.PITCH_MAX, "and the other")


func test_the_joystick_only_claims_its_own_half_of_the_screen() -> void:
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	controls.apply_scheme("touch")
	controls.size = Vector2(1080, 1920)
	var stick: Control = controls.joystick()
	stick.size = controls.size

	assert_false(stick.owns_point(Vector2(900, 1500)), "the right thumb is not the joystick's")
	assert_true(stick.owns_point(Vector2(180, 1500)), "the left thumb is")


func test_dragging_the_joystick_up_reads_as_forward() -> void:
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	controls.apply_scheme("touch")
	controls.size = Vector2(1080, 1920)
	var stick: Control = controls.joystick()
	stick.size = controls.size

	assert_true(stick.try_claim(0, Vector2(200, 1500)), "the touch is claimed")
	stick.drag_to(0, Vector2(200, 1500 - stick.radius))
	assert_almost_eq(stick.vector().y, 1.0, 0.01, "up the screen is forward")
	assert_almost_eq(stick.vector().x, 0.0, 0.01)


func test_the_joystick_vector_never_exceeds_one() -> void:
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	controls.apply_scheme("touch")
	controls.size = Vector2(1080, 1920)
	var stick: Control = controls.joystick()
	stick.size = controls.size

	stick.try_claim(0, Vector2(200, 1500))
	stick.drag_to(0, Vector2(200 + stick.radius * 40.0, 1500))
	assert_almost_eq(stick.vector().length(), 1.0, 0.01, "a long drag clamps to the ring")


func test_releasing_the_joystick_zeroes_it() -> void:
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	controls.apply_scheme("touch")
	controls.size = Vector2(1080, 1920)
	var stick: Control = controls.joystick()
	stick.size = controls.size

	stick.try_claim(0, Vector2(200, 1500))
	stick.drag_to(0, Vector2(200, 1400))
	stick.release(0)
	assert_eq(stick.vector(), Vector2.ZERO, "letting go stops the player")
	assert_false(stick.is_active(), "and hides the ring")


func test_a_second_finger_cannot_steal_the_joystick() -> void:
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	controls.apply_scheme("touch")
	controls.size = Vector2(1080, 1920)
	var stick: Control = controls.joystick()
	stick.size = controls.size

	assert_true(stick.try_claim(0, Vector2(200, 1500)))
	assert_false(stick.try_claim(1, Vector2(300, 1600)), "one thumb owns it at a time")


func test_the_contextual_button_is_hidden_until_a_verb_is_set() -> void:
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	controls.apply_scheme("touch")
	var button: Button = controls.contextual_button()
	assert_eq(button.current_verb(), "", "no verb until something is near (GDD §11)")
	assert_eq(button.text, Strings.t("verb.idle"), "it idles as a faint mark the Call can land on")
	assert_lte(button.modulate.a, button.IDLE_ALPHA + 0.01, "and stays faint")


func test_the_contextual_button_labels_itself_from_the_string_table() -> void:
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	controls.apply_scheme("touch")
	var button: Button = controls.contextual_button()
	button.show_verb("verb.listen")
	assert_eq(button.text, Strings.t("verb.listen"), "the label is data, never a literal")
	assert_eq(button.current_verb(), "verb.listen")


func test_pressing_the_button_reports_the_verb_id() -> void:
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	controls.apply_scheme("touch")
	var button: Button = controls.contextual_button()
	button.show_verb("verb.listen")
	watch_signals(button)
	button.pressed.emit()
	assert_signal_emitted_with_parameters(button, "verb_used", ["verb.listen"])


func test_a_cleared_button_reports_nothing_when_pressed() -> void:
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	controls.apply_scheme("touch")
	var button: Button = controls.contextual_button()
	button.show_verb("verb.listen")
	button.clear_verb()
	watch_signals(button)
	button.pressed.emit()
	assert_signal_not_emitted(button, "verb_used", "a cleared button is inert")
