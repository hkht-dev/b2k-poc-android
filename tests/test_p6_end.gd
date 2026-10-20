## Tests P6: the end of the slice, Play again, settings and the sound cues
## (CLAUDE_CODE_BRIEF.md §4.6, §7; GDD §11).
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const END := preload("res://scenes/ui/EndScreen.tscn")
const SETTINGS := preload("res://scenes/ui/SettingsScreen.tscn")
const GAME_STATE := preload("res://scripts/core/game_state.gd")
const SCRATCH := "user://test_p6_journey.json"

var _real_path := ""


func before_each() -> void:
	_real_path = GameState.save_path
	GameState.save_path = SCRATCH
	GameState.set_autosave(false)
	GameState.wipe()


func after_each() -> void:
	get_tree().paused = false
	get_tree().root.content_scale_factor = 1.0
	GameState.wipe()
	GameState.save_path = _real_path
	GameState.set_autosave(true)


func _street() -> Node3D:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	return street


func _at_bus_stop(street: Node3D) -> void:
	street.get_node("%Player").global_position = Vector3(9.2, 0.3, 19.6)
	await wait_frames(8)


func test_arriving_at_the_bus_stop_with_nothing_decided_ends_nothing() -> void:
	var street := _street()
	watch_signals(street)
	await _at_bus_stop(street)
	assert_false(street.is_ending())
	assert_ne(
		street.get_node("%TouchControls").contextual_button().current_verb(),
		"verb.sit",
		"no Sit before 90 s of play"
	)


func test_arriving_after_the_can_was_placed_fades_and_ends() -> void:
	var street := _street()
	watch_signals(street)
	GameState.set_flag("gave_dry_fountain")
	await _at_bus_stop(street)
	assert_true(street.is_ending(), "the fade began")
	await wait_seconds(street.FADE_SECONDS + 0.3)
	assert_almost_eq(street.fade_alpha(), 1.0, 0.01, "black")
	assert_signal_emitted_with_parameters(street, "slice_ended", ["arrived"])


func test_arriving_after_the_can_was_taken_ends_too() -> void:
	var street := _street()
	GameState.set_flag("took_dry_fountain")
	await _at_bus_stop(street)
	assert_true(street.is_ending())


func test_sit_is_offered_after_ninety_seconds_and_ends_the_slice_sitting() -> void:
	var street := _street()
	watch_signals(street)
	GameState.play_seconds = 91.0
	await _at_bus_stop(street)
	var button: Button = street.get_node("%TouchControls").contextual_button()
	assert_eq(button.current_verb(), "verb.sit")
	button.pressed.emit()
	await wait_frames(2)
	assert_true(street.is_ending())
	var rig: CharacterRig = street.get_node("%Player/Mesh")
	assert_eq(rig.state(), "pose", "the player sits")
	await wait_seconds(street.FADE_SECONDS + 0.3)
	assert_signal_emitted_with_parameters(street, "slice_ended", ["sat"])


func test_play_time_is_counted_and_saved() -> void:
	var street := _street()
	await wait_frames(30)
	assert_gt(GameState.play_seconds, 0.3, "the street counts play time")
	GameState.save()
	var loaded: Node = GAME_STATE.new()
	loaded.save_path = SCRATCH
	loaded.load_journey()
	assert_gt(loaded.play_seconds, 0.3, "and it is in the journey file")
	loaded.free()
	street.queue_free()


func test_the_end_screen_says_the_one_line_in_white_at_24_and_offers_play_again_only() -> void:
	var screen: Control = add_child_autofree(END.instantiate())
	await wait_frames(1)
	assert_eq(screen.line_text(), "The journey back begins again wherever you are.")
	var line: Label = screen.get_node("%Line")
	assert_eq(line.get_theme_font_size("font_size"), 24)
	assert_eq(line.get_theme_color("font_color"), Color(1, 1, 1, 1))
	var buttons := 0
	for node: Node in screen.find_children("*", "Button", true, false):
		buttons += 1
	assert_eq(buttons, 1, "Play again only")
	assert_eq(screen.get_node("%PlayAgainButton").text, "Play again")


func test_play_again_wipes_the_journey() -> void:
	GameState.set_flag("gave_dry_fountain")
	GameState.add_journey_line("journey.dry_fountain.gave")
	var screen: Control = add_child_autofree(END.instantiate())
	watch_signals(screen)
	await wait_frames(1)
	screen.get_node("%PlayAgainButton").pressed.emit()
	assert_signal_emitted(screen, "play_again_pressed")
	assert_false(GameState.has_flag("gave_dry_fountain"), "GameState reset")
	assert_true(GameState.journey_lines.is_empty())


func test_settings_persist_and_the_street_applies_them() -> void:
	var street := _street()
	await wait_frames(2)
	# No awaits while paused: the tree is paused and GUT's frame waiter with it.
	street.pause()
	street._pause_menu.get_node("%SettingsButton").pressed.emit()
	var settings: Control = street.settings_overlay()
	assert_not_null(settings, "the settings screen opened from the pause menu")
	(settings.control_for("subtitle_box") as CheckButton).button_pressed = true
	assert_true(GameState.settings.get("subtitle_box", false))
	assert_true(street.get_node("%TouchControls").has_subtitle_box())
	(settings.control_for("large_text") as CheckButton).button_pressed = true
	assert_almost_eq(get_tree().root.content_scale_factor, street.LARGE_TEXT_SCALE, 0.001)
	(settings.control_for("joystick_side") as CheckButton).button_pressed = true
	assert_eq(GameState.settings.get("joystick_side"), "right")
	assert_eq(street.get_node("%TouchControls").joystick().side, "right")
	(settings.control_for("camera_sensitivity") as HSlider).value = 1.5
	assert_almost_eq(street.get_node("%CameraRig").sensitivity, 1.5, 0.001)
	var loaded: Node = GAME_STATE.new()
	loaded.save_path = SCRATCH
	loaded.load_journey()
	assert_true(loaded.settings.get("subtitle_box", false), "saved at once")
	loaded.free()
	for control: Node in settings.find_children("*", "Control", true, false):
		if control is CheckButton or control is HSlider:
			assert_false(control.tooltip_text.is_empty(), "every control carries its label")
	settings.get_node("%CloseButton").pressed.emit()
	assert_null(street.settings_overlay())
	street.resume()
	await wait_frames(1)


func test_sound_cues_ripple_at_tulu_and_on_a_hum_only_when_on() -> void:
	var street := _street()
	await wait_frames(2)
	var tulu_ripple: SoundRipple = street.get_node("%Tulu/%Ripple")
	assert_false(tulu_ripple.enabled, "off by default")
	await wait_frames(3)
	assert_false(tulu_ripple.is_showing())
	GameState.settings["sound_cues"] = true
	street._apply_settings()
	await wait_frames(3)
	assert_true(tulu_ripple.enabled)
	assert_true(tulu_ripple.is_showing(), "his hum ripples")
	assert_gte(SoundRipple.RIPPLE_SECONDS, 0.34, "never faster than 3 Hz")
	var player_ripple: SoundRipple = street.get_node("%Player/%Ripple")
	street.hum()
	await wait_frames(2)
	assert_true(player_ripple.is_showing(), "the hum ripples once")
