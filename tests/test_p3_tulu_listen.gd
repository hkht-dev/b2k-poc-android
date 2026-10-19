## Tests P3: Tulu, the generic *Listen* verb, the hum, subtitles and the
## pause menu's one line.
##
## CLAUDE_CODE_BRIEF.md §3 P3 ("a blindfolded tester can locate Tulu" is a
## playtest; what can be asserted is that the sound is there, positional and
## looping, and that *Listen* does exactly what §4.3 says), §4.2 "Call", §4.3.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_p3_journey.json"

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


func _street_with_player_at(where: Vector3) -> Node3D:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%Player").global_position = where
	return street


# -- the sound ------------------------------------------------------------------


func test_tulu_hums_on_a_positional_loop_from_the_start() -> void:
	var street := _street_with_player_at(Vector3(0, -1, 2))
	var tulu: Node3D = street.get_node("%Tulu")
	var hum: AudioStreamPlayer3D = tulu.get_node("%HumLoop")
	assert_true(hum.playing, "he is humming when the player surfaces")
	assert_true(hum.stream.loop, "on a loop")
	assert_lt(hum.max_distance, 30.0, "faint beyond ~15 m, not everywhere")
	assert_true(tulu.is_in_group("sound_source"), "Listen is exposed through the group")


func test_the_audio_placeholders_exist_and_load() -> void:
	for name in ["tulu_three_notes", "player_hum", "street_bed", "water_loop"]:
		var stream: AudioStream = load("res://assets/audio/%s.ogg" % name)
		assert_not_null(stream, "%s loads" % name)
		assert_gt(stream.get_length(), 0.5, "%s is not empty" % name)


# -- Listen ------------------------------------------------------------------


func test_the_button_reads_listen_only_next_to_tulu() -> void:
	var street := _street_with_player_at(Vector3(-10, 0.3, 16))
	var button: Button = street.get_node("%TouchControls").contextual_button()
	await wait_frames(3)
	assert_eq(button.current_verb(), "", "nothing near on the road")
	var tulu: Node3D = street.get_node("%Tulu")
	street.get_node("%Player").global_position = tulu.global_position + Vector3(0.8, 0, 0.8)
	await wait_frames(4)
	assert_eq(button.current_verb(), "verb.listen", "next to him it says Listen")
	assert_eq(button.text, Strings.t("verb.listen"), "from the string table")


func test_listen_sets_the_flag_drifts_the_camera_and_subtitles_the_hum() -> void:
	var street := _street_with_player_at(Vector3(0, 0.05, -9))
	var tulu: Node3D = street.get_node("%Tulu")
	var rig: Node3D = street.get_node("%CameraRig")
	var controls: Control = street.get_node("%TouchControls")
	street.get_node("%Player").global_position = tulu.global_position + Vector3(0.8, 0, 0.8)
	await wait_frames(4)
	watch_signals(tulu)
	controls.contextual_button().pressed.emit()
	assert_true(GameState.has_flag("heard_tulu"), "heard_tulu is set (GDD §6)")
	assert_signal_emitted(tulu, "listened")
	assert_true(rig.is_drifting(), "the camera drifts toward him")
	assert_eq(controls.subtitle_text(), Strings.t("sub.tulu_hum"), "[Tulu hums three notes]")
	assert_eq(tulu.mode(), tulu.Mode.LEADING, "and he sets off")


func test_after_listen_he_walks_toward_the_back_door_and_waits_when_the_player_lags() -> void:
	var street := _street_with_player_at(Vector3(0, 0.05, -9))
	var tulu: Node3D = street.get_node("%Tulu")
	var player: Node3D = street.get_node("%Player")
	player.global_position = tulu.global_position + Vector3(0.8, 0, 0.8)
	await wait_frames(4)
	street.get_node("%TouchControls").contextual_button().pressed.emit()
	var start := tulu.global_position
	# Keep the player at his side so he keeps walking.
	for _i in 6:
		await wait_frames(10)
		player.global_position = tulu.global_position + Vector3(0.5, 0, 0.5)
	assert_gt(start.distance_to(tulu.global_position), 1.0, "he walked")
	# Now fall far behind: he stops.
	player.global_position = Vector3(0, 0.05, 30)
	await wait_frames(5)
	var held := tulu.global_position
	await wait_frames(30)
	assert_almost_eq(held.distance_to(tulu.global_position), 0.0, 0.05, "he waits")


func test_ignored_he_follows_the_player_at_a_distance() -> void:
	var street := _street_with_player_at(Vector3(0, 0.05, 30))
	var tulu: Node3D = street.get_node("%Tulu")
	tulu._ignored_for = tulu.FOLLOW_AFTER + 1.0
	await wait_frames(3)
	assert_eq(tulu.mode(), tulu.Mode.FOLLOWING)
	var before := tulu.global_position.distance_to(Vector3(0, 0.05, 30))
	await wait_frames(90)
	var after := tulu.global_position.distance_to(Vector3(0, 0.05, 30))
	assert_lt(after, before, "he came closer")
	assert_gt(after, tulu.FOLLOW_DISTANCE - 1.5, "but keeps his distance")


# -- the hum -------------------------------------------------------------------


func test_holding_the_button_with_nothing_near_hums_and_counts() -> void:
	var street := _street_with_player_at(Vector3(-10, 0.3, 16))
	var controls: Control = street.get_node("%TouchControls")
	await wait_frames(3)
	assert_eq(controls.contextual_button().current_verb(), "", "nothing near")
	controls.contextual_button().hold_for(1.0)
	assert_eq(GameState.hum_count, 1, "one hum counted (brief §4.2)")
	assert_eq(controls.subtitle_text(), Strings.t("sub.player_hum"))
	controls.contextual_button().hold_for(1.0)
	controls.contextual_button().hold_for(1.0)
	assert_true(GameState.has_flag("hummed"), "the third hum sets `hummed` (GDD §6)")


func test_a_press_next_to_tulu_listens_rather_than_hums() -> void:
	var street := _street_with_player_at(Vector3(0, 0.05, -9))
	var tulu: Node3D = street.get_node("%Tulu")
	street.get_node("%Player").global_position = tulu.global_position + Vector3(0.8, 0, 0.8)
	await wait_frames(4)
	street.get_node("%TouchControls").contextual_button().hold_for(1.0)
	assert_eq(GameState.hum_count, 0, "a hold with a verb showing is not a hum")


func test_tulu_answers_a_hum_only_once_he_has_been_heard() -> void:
	var street := _street_with_player_at(Vector3(0, 0.05, -12))
	var tulu: Node3D = street.get_node("%Tulu")
	watch_signals(tulu)
	street.hum()
	assert_signal_not_emitted(tulu, "replied", "nothing answers until heard_tulu (brief §4.2)")
	GameState.set_flag("heard_tulu")
	street.hum()
	assert_signal_emitted(tulu, "replied", "after that his three notes reply")


func test_the_hum_count_survives_a_save() -> void:
	GameState.set_autosave(true)
	GameState.record_hum()
	GameState.record_hum()
	var fresh: Node = autofree(load("res://scripts/core/game_state.gd").new())
	fresh.set_autosave(false)
	fresh.save_path = SCRATCH
	assert_true(fresh.load_journey())
	assert_eq(fresh.hum_count, 2)


# -- the one line -----------------------------------------------------------------


func test_the_pause_menu_says_a_boy_is_humming_until_he_is_heard() -> void:
	var street := _street_with_player_at(Vector3(-10, 0.3, 16))
	street.pause()
	assert_eq(street._pause_menu.get_node("%Now").text, Strings.t("now.boy_humming"))
	street.resume()
	GameState.set_flag("heard_tulu")
	street.pause()
	assert_ne(street._pause_menu.get_node("%Now").text, Strings.t("now.boy_humming"))
	assert_ne(street._pause_menu.get_node("%Now").text, "", "something else now")
	street.resume()


func test_there_is_still_no_marker_arrow_or_objective_on_the_hud() -> void:
	var street := _street_with_player_at(Vector3(0, -1, 2))
	var controls: Control = street.get_node("%TouchControls")
	await wait_frames(2)
	assert_eq(controls.subtitle_text(), "", "no text on the HUD until a sound")
	assert_eq(controls.contextual_button().current_verb(), "", "no verb in the basin")
	assert_false(controls.minimap().visible, "no map")
