## Tests Tulu's thread to the shrine and the chai stall's front: his arrival
## at the back door, the Talk verb that appears there, Amma's lines, the
## kettle's steam and the chant a hum stirs behind the door.
##
## GDD §3 Act 3 "Arrival", §4 "Tulu ... follows the player if ignored", §5
## "the shrine room is tucked behind the chai stall, found by following
## Tulu", §7 "Hum near the shrine: Madhuri's chant rises to meet the note".
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_tulu_lead_journey.json"

var _real_path := ""


func before_each() -> void:
	_real_path = GameState.save_path
	GameState.save_path = SCRATCH
	GameState.set_autosave(false)
	GameState.wipe()


func after_each() -> void:
	get_tree().paused = false
	if Content.dialogue.is_running():
		Content.dialogue.dismiss()
	GameState.wipe()
	GameState.save_path = _real_path
	GameState.set_autosave(true)
	# Let the cards a line left behind finish their queue_free.
	await wait_frames(1)


func _street() -> Node3D:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	return street


func _button(street: Node3D) -> Button:
	return street.get_node("%TouchControls").contextual_button()


func _last_waypoint(tulu: Node3D) -> Vector3:
	return tulu.waypoints[tulu.waypoints.size() - 1]


## Puts Tulu a step short of his last waypoint with the player beside him and
## lets him walk the rest: the way the street gets him there, shortened.
func _walk_tulu_to_the_door(street: Node3D) -> Node3D:
	var tulu: Node3D = street.get_node("%Tulu")
	var player: Node3D = street.get_node("%Player")
	GameState.set_flag("heard_tulu")
	var last := _last_waypoint(tulu)
	tulu._waypoint = tulu.waypoints.size() - 1
	tulu.global_position = last + Vector3(-0.6, 0, 0)
	player.global_position = last + Vector3(0.9, 0, 0.9)
	await wait_frames(60)
	return tulu


# -- the door --------------------------------------------------------------------


func test_reaching_the_last_waypoint_turns_him_hums_and_sets_the_flag() -> void:
	var street := _street()
	var tulu: Node3D = street.get_node("%Tulu")
	var player: Node3D = street.get_node("%Player")
	watch_signals(tulu)
	assert_false(GameState.has_flag(tulu.at_door_flag))
	await _walk_tulu_to_the_door(street)
	assert_true(tulu.is_at_the_door(), "he arrived")
	assert_eq(tulu.at_door_flag, "tulu_at_door", "the flag is data on him")
	assert_true(GameState.has_flag("tulu_at_door"))
	assert_signal_emitted(tulu, "arrived_at_door")
	assert_true(tulu.get_node("%Reply").playing, "he hums once more")
	var controls: Control = street.get_node("%TouchControls")
	assert_eq(controls.subtitle_text(), Strings.t("sub.tulu_points"))
	assert_eq(Strings.t("sub.tulu_points"), "[Tulu looks at the door, then at you]")
	await wait_frames(30)
	var to_player := player.global_position - tulu.global_position
	var facing := atan2(-to_player.x, -to_player.z)
	assert_almost_eq(wrapf(tulu.rotation.y - facing, -PI, PI), 0.0, 0.25, "he turned to the player")


func test_the_subtitle_shows_once_per_journey() -> void:
	var street := _street()
	var tulu := await _walk_tulu_to_the_door(street)
	var controls: Control = street.get_node("%TouchControls")
	controls.subtitle("sub.player_hum")
	tulu._arrive()
	assert_eq(
		controls.subtitle_text(), Strings.t("sub.player_hum"), "a second arrival says nothing"
	)


func test_a_loaded_journey_finds_him_at_the_door() -> void:
	GameState.set_flag("heard_tulu")
	GameState.set_flag("tulu_at_door")
	var street := _street()
	var tulu: Node3D = street.get_node("%Tulu")
	await wait_frames(2)
	assert_true(tulu.is_at_the_door())
	assert_lt(tulu.global_position.distance_to(_last_waypoint(tulu)), 0.5)
	assert_true(tulu.get_node("%Talk").is_available())
	assert_false(tulu.get_node("%Listen").is_available(), "beside him it says Talk now")


# -- Talk ----------------------------------------------------------------------


func test_talk_is_absent_before_the_door_and_present_at_it() -> void:
	var street := _street()
	var tulu: Node3D = street.get_node("%Tulu")
	var player: Node3D = street.get_node("%Player")
	player.global_position = tulu.global_position + Vector3(0.8, 0, 0.8)
	await wait_frames(6)
	assert_eq(_button(street).current_verb(), "verb.listen", "at the fountain he is listened to")
	assert_false(tulu.get_node("%Talk").is_available(), "no Talk before the door")
	await _walk_tulu_to_the_door(street)
	player.global_position = tulu.global_position + Vector3(0.8, 0, 0.8)
	await wait_frames(6)
	assert_eq(_button(street).current_verb(), "verb.talk", "at the door the button says Talk")
	assert_eq(_button(street).text, Strings.t("verb.talk"))
	_button(street).pressed.emit()
	assert_eq(Content.dialogue.current_line_id(), "tulu_door")
	assert_eq(street.cards().card_count(), 3, "what is in there, where the notes came from, go on")
	assert_eq(street.cards().get_node("%Speaker").text, "Tulu")
	Content.dialogue.choose(0)
	assert_eq(Content.dialogue.current_line_id(), "tulu_door_lamp")
	assert_true(
		Strings.t("line.tulu_door_lamp").contains("Madhuri"),
		"he names who is behind the door, not just 'she'"
	)
	Content.dialogue.dismiss()
	assert_false(Content.dialogue.is_running())


func test_go_on_then_ends_the_line() -> void:
	GameState.set_flag("heard_tulu")
	GameState.set_flag("tulu_at_door")
	var street := _street()
	var tulu: Node3D = street.get_node("%Tulu")
	watch_signals(tulu)
	tulu.get_node("%Talk").use(street.get_node("%Player"))
	assert_signal_emitted_with_parameters(tulu, "talked", ["tulu_door"])
	Content.dialogue.choose(2)
	assert_false(Content.dialogue.is_running(), "Go on, then: nothing more to say")


# -- the chai stall's front -----------------------------------------------------------


func test_amma_talks_and_her_door_card_tells_of_the_shrine() -> void:
	var street := _street()
	var amma: Node3D = street.get_node("%Amma")
	assert_not_null(amma, "a tea-seller at the hatch")
	street.get_node("%Player").global_position = amma.global_position + Vector3(0, 0.05, 1.2)
	await wait_frames(6)
	assert_eq(_button(street).current_verb(), "verb.talk")
	_button(street).pressed.emit()
	assert_eq(Content.dialogue.current_line_id(), "chai_greet")
	assert_eq(street.cards().card_count(), 3)
	assert_eq(street.cards().get_node("%Speaker").text, "Amma")
	assert_false(GameState.has_flag("told_about_shrine"))
	Content.dialogue.choose(1)
	assert_eq(Content.dialogue.current_line_id(), "chai_about_door")
	assert_true(GameState.has_flag("told_about_shrine"), "that's Madhuri's; knock if you like")
	Content.dialogue.dismiss()


func test_her_tulu_card_leads_to_the_same_door() -> void:
	var street := _street()
	street.get_node("%Amma").get_node("%Talk").use(street.get_node("%Player"))
	Content.dialogue.choose(0)
	assert_eq(Content.dialogue.current_line_id(), "chai_about_tulu")
	assert_eq(street.cards().card_count(), 2)
	Content.dialogue.choose(0)
	assert_eq(Content.dialogue.current_line_id(), "chai_about_door")
	assert_true(GameState.has_flag("told_about_shrine"))
	Content.dialogue.dismiss()


func test_the_kettle_steams() -> void:
	var street := _street()
	var steam: MeshInstance3D = street.get_node("ChaiFront/Steam")
	await wait_frames(2)
	var scale_before := steam.scale
	var y_before := steam.position.y
	await wait_frames(12)
	assert_ne(steam.scale, scale_before, "it grows")
	assert_ne(steam.position.y, y_before, "and rises")
	var material := steam.material_override as StandardMaterial3D
	assert_not_null(material)
	assert_eq(material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "translucent")
	assert_lt(material.albedo_color.a, 0.5)
	assert_gte(material.albedo_color.r, material.albedo_color.b, "warm white, no blue (GDD §10)")
	assert_eq(steam.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_the_sign_and_the_props_are_there() -> void:
	var street := _street()
	await wait_frames(1)
	var sign: Label3D = street.get_node("ChaiFront/ChaiSign")
	assert_eq(sign.text, Strings.t("sign.chai"), "from the string table")
	assert_not_null(street.get_node_or_null("ChaiFront/Kettle"))
	var cups: MultiMeshInstance3D = street.get_node("ChaiFront/Cups")
	assert_gte(cups.multimesh.instance_count, 6, "cups, in one draw call")


# -- the chant ------------------------------------------------------------------


func test_the_chant_placeholder_loads() -> void:
	var stream: AudioStream = load("res://assets/audio/chant_outside.ogg")
	assert_not_null(stream)
	assert_gt(stream.get_length(), 7.5, "an 8 s drone")


func test_a_hum_beside_him_at_the_door_stirs_the_chant_inside() -> void:
	var street := _street()
	var chant: AudioStreamPlayer3D = street.get_node("ChaiFront/ChantOutside")
	assert_false(chant.playing, "silent until someone hums at the door")
	assert_true(chant.is_in_group("chant_outside"))
	var tulu: Node3D = street.get_node("%Tulu")
	var player: Node3D = street.get_node("%Player")
	GameState.set_flag("heard_tulu")
	player.global_position = Vector3(0, 0.05, -9)
	street.hum()
	assert_false(chant.playing, "a hum at the fountain, with him still there, does not reach it")
	await _walk_tulu_to_the_door(street)
	tulu._reply_timer = 0.0
	player.global_position = Vector3(40, 0.05, -12)
	street.hum()
	assert_false(chant.playing, "within his reach but not within 10 m of him")
	tulu._reply_timer = 0.0
	player.global_position = tulu.global_position + Vector3(3, 0, 3)
	watch_signals(tulu)
	street.hum()
	assert_signal_emitted(tulu, "replied", "he answers")
	assert_true(chant.playing, "and the chant inside is heard")
	assert_lt(chant.volume_db, 0.0, "faintly")
	assert_lt(chant.max_distance, 20.0, "and only near the door")
	assert_gt(
		chant.global_position.distance_to(_last_waypoint(tulu)),
		0.5,
		"it is at the door, not on him"
	)
	assert_lt(chant.global_position.distance_to(_last_waypoint(tulu)), 4.0)
