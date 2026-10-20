## Tests the shrine room behind the chai stall (GDD §5 Hollow Vale, §7
## "Investigate" steps 1-3, §8 Scene D, §6 "Remembering Krishna" saw_shrine):
## the stall's back door leads in, the room spawns the player at the door,
## the three photographs set saw_shrine from the data, Madhuri talks, her
## chant rises to a hum, and a carried can waters the lamp.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_shrine_journey.json"
const PLACE_ID := "shrine"
const SPAWN_ID := "shrine_door"

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


func _street() -> Node3D:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	return street


## The shrine, found the way Main finds it: through data/places.json.
func _shrine() -> Node3D:
	var packed: PackedScene = load(Places.scene_of(PLACE_ID))
	assert_not_null(packed, "data/places.json names the shrine's scene")
	var shrine: Node3D = add_child_autofree(packed.instantiate())
	shrine.get_node("%TouchControls").apply_scheme("touch")
	return shrine


func _player(place: Node3D) -> CharacterBody3D:
	return place.get_node("%Player")


func _button(place: Node3D) -> Button:
	return place.get_node("%TouchControls").contextual_button()


func _put(place: Node3D, where: Vector3) -> void:
	_player(place).global_position = where
	await wait_frames(8)


func _press(place: Node3D) -> void:
	_button(place).pressed.emit()
	await wait_frames(2)


func test_the_stall_back_door_offers_go_in_and_leads_to_the_shrine() -> void:
	var street := _street()
	watch_signals(street)
	await _put(street, Vector3(13.0, 0.05, -12.1))
	assert_eq(_button(street).current_verb(), "verb.enter", "the back door offers Go in")
	await _press(street)
	assert_true(street.is_leaving())
	assert_eq(GameState.place, PLACE_ID, "the journey remembers the place")
	assert_eq(GameState.spawn, SPAWN_ID)
	await wait_seconds(street.DOOR_FADE_SECONDS + 0.3)
	assert_signal_emitted_with_parameters(street, "place_requested", [PLACE_ID, SPAWN_ID])


func test_the_room_spawns_the_player_inside_at_the_door_spawn() -> void:
	GameState.set_place(PLACE_ID, SPAWN_ID)
	var shrine := _shrine()
	await wait_frames(2)
	assert_eq(shrine.place_id, PLACE_ID)
	var spawn: Node3D = null
	for node: Node in get_tree().get_nodes_in_group(SpawnPoint.GROUP):
		if shrine.is_ancestor_of(node) and node.spawn_id == SPAWN_ID:
			spawn = node
	assert_not_null(spawn, "the room has the spawn point the street door names")
	var player := _player(shrine)
	assert_almost_eq(
		player.global_position.distance_to(spawn.global_position), 0.0, 0.1, "the player is on it"
	)
	assert_lt(absf(player.global_position.x), 3.0, "inside the room")
	assert_lt(absf(player.global_position.z), 2.5)
	var doors := 0
	for node: Node in get_tree().get_nodes_in_group(Door.GROUP):
		if shrine.is_ancestor_of(node):
			doors += 1
			assert_eq(node.place_id, "street", "the door leads back to the street")
			assert_eq(node.spawn_id, SPAWN_ID, "onto the spawn outside the stall")
			assert_eq(node.verb_id, "verb.leave")
	assert_eq(doors, 1)


func test_the_three_photographs_offer_look_and_all_three_set_saw_shrine() -> void:
	var shrine := _shrine()
	var spots := {
		"PhotoFountain": Vector3(2.4, 0.0, -1.6),
		"PhotoTower": Vector3(2.4, 0.0, -0.4),
		"PhotoLamp": Vector3(2.4, 0.0, 0.8),
	}
	var seen := 0
	for name: String in spots:
		assert_not_null(shrine.get_node_or_null("%" + name), "the room has %s" % name)
		await _put(shrine, spots[name])
		assert_eq(_button(shrine).current_verb(), "verb.look", "%s offers Look" % name)
		await _press(shrine)
		var dialogue: Dialogue = Content.dialogue
		assert_true(dialogue.is_running(), "%s says what it shows" % name)
		assert_eq(dialogue.get_line(dialogue.current_line_id()).get("speaker", ""), "photo")
		assert_true(shrine.cards().visible)
		dialogue.dismiss()
		seen += 1
		assert_eq(
			GameState.has_flag("saw_shrine"),
			seen == 3,
			"saw_shrine after the third photograph only (%d seen)" % seen
		)
	for stem: String in ["fountain", "tower", "lamp"]:
		assert_true(GameState.has_flag("saw_photo_%s" % stem), "each photograph left its mark")


func test_madhuri_offers_talk_and_her_first_line_opens() -> void:
	var shrine := _shrine()
	var madhuri: Node3D = shrine.get_node("%Madhuri")
	watch_signals(madhuri)
	await _put(shrine, Vector3(-1.1, 0.0, 0.8))
	assert_eq(_button(shrine).current_verb(), "verb.talk", "Madhuri offers Talk")
	await _press(shrine)
	var dialogue: Dialogue = Content.dialogue
	assert_signal_emitted_with_parameters(madhuri, "talked", ["madhuri_greet"])
	assert_eq(dialogue.current_line_id(), "madhuri_greet", "she knows the player already")
	assert_true(GameState.has_flag("met_madhuri"), "the greeting leaves its mark (data)")
	assert_eq(shrine.cards().card_count(), 2)
	dialogue.choose(0)
	assert_eq(dialogue.current_line_id(), "madhuri_tulu")
	dialogue.choose(0)
	assert_eq(dialogue.current_line_id(), "madhuri_song")
	dialogue.choose(0)
	assert_eq(dialogue.current_line_id(), "madhuri_ask_water", "she asks for water for the lamp")
	dialogue.dismiss()
	await _press(shrine)
	assert_eq(dialogue.current_line_id(), "madhuri_ask_water", "and asks again, not the greeting")
	dialogue.dismiss()
	GameState.set_flag("lamp_watered")
	await _press(shrine)
	assert_eq(dialogue.current_line_id(), "madhuri_after_water", "watered, she says so")
	dialogue.dismiss()


func test_a_hum_raises_her_chant_for_a_moment() -> void:
	var shrine := _shrine()
	await wait_frames(2)
	var chant: Node3D = shrine.get_node("%Madhuri").chant()
	assert_true(chant.is_in_group("sound_source"), "the hum reaches it through the group")
	var base: float = chant.volume_db()
	assert_false(chant.is_raised())
	watch_signals(chant)
	shrine.hum()
	await wait_frames(2)
	assert_signal_emitted(chant, "rose")
	assert_true(chant.is_raised())
	await wait_seconds(chant.SWELL_SECONDS + 0.3)
	assert_gt(chant.volume_db(), base + 3.0, "the chant rises to meet the note")
	assert_eq(
		shrine.get_node("%TouchControls").subtitle_text(),
		Strings.t("sub.madhuri_chant"),
		"and is subtitled"
	)
	await wait_seconds(chant.RAISE_SECONDS + chant.SETTLE_SECONDS)
	assert_false(chant.is_raised())
	assert_almost_eq(chant.volume_db(), base, 0.5, "then settles")


func test_placing_a_carried_can_waters_the_lamp() -> void:
	var shrine := _shrine()
	var lamp: Node3D = shrine.get_node("%LampPoint")
	var dim: float = lamp.light_energy()
	await _put(shrine, Vector3(0.4, 0.0, 1.0))
	assert_ne(_button(shrine).current_verb(), "verb.place", "nothing to place with empty hands")
	assert_true(_player(shrine).carry(), "the player picks up a can")
	await wait_frames(3)
	assert_eq(_button(shrine).current_verb(), "verb.place", "carrying a can, the lamp offers Place")
	watch_signals(lamp)
	await _press(shrine)
	assert_signal_emitted(lamp, "placed")
	assert_true(GameState.has_event("can_placed_at_shrine"), "the event fired")
	assert_true(GameState.has_flag("lamp_watered"), "the flag is set (data on the node)")
	assert_false(GameState.has_flag("carrying_can"), "the can left the hand")
	assert_false(_player(shrine).is_carrying())
	assert_true(lamp.get_node("%PlacedCan").visible, "the can stands by the lamp")
	await wait_frames(10)
	assert_gt(lamp.light_energy(), dim, "the lamp comes up")
	assert_ne(_button(shrine).current_verb(), "verb.place", "nothing more to place")
