## Tests the Grove riverbank, Act 1 (GDD §3 Act 1, §3a, §5, §7, §8 Scene A):
## the place loads and spawns where the journey says, the calf answers a hum
## and follows once petted, the water-pot quest runs from the data, Kuvera's
## cards leave their flag either way, the Dive and the street's development
## door lead where they say, and no colour in the Grove is peacock blue or
## magenta (CLAUDE.md).
extends GutTest

const GROVE := preload("res://scenes/places/Grove.tscn")
const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_grove_journey.json"
## Where tools/gen_grove.py put things (its layout constants).
const POT_PICKUP := Vector3(2.0, 0.1, -27.6)
const LALITA_TALK := Vector3(-14.0, 0.1, 8.2)
const POT_PLACE := Vector3(-11.4, 0.1, 8.6)
const KUVERA_TALK := Vector3(13.0, 0.1, -27.2)
const SWING := Vector3(23.2, 0.1, -5.0)
const DIVE_DOOR := Vector3(24.3, 0.1, 17.0)
const STREET_GROVE_DOOR := Vector3(-2.6, -0.4, 2.6)

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


func _grove() -> Node3D:
	var grove: Node3D = add_child_autofree(GROVE.instantiate())
	grove.get_node("%TouchControls").apply_scheme("touch")
	return grove


func _street() -> Node3D:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	return street


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


# -- the place ----------------------------------------------------------------


func test_the_grove_loads_as_a_place_with_id_grove() -> void:
	var grove := _grove()
	assert_true(grove is Place, "the Grove is a Place like the street and the shops")
	assert_eq(grove.place_id, "grove")
	assert_eq(Places.scene_of("grove"), "res://scenes/places/Grove.tscn")
	assert_eq(Strings.t(Places.name_id_of("grove")), "The Grove")
	for landmark: String in [
		"River",
		"FarBank",
		"Feast",
		"Meadow",
		"Garden",
		"Kadamba",
		"Pool",
		"Bubbles",
		"Sky",
		"Trees"
	]:
		assert_not_null(grove.get_node_or_null(landmark), "the Grove has %s" % landmark)
	assert_eq(grove.get_node("Bubbles").get_child_count(), 6, "six bubbles drift")
	assert_not_null(grove.get_node_or_null("%FarFigure"), "someone leans on the far tree")


func test_a_fresh_journey_wakes_on_the_grass_beside_the_river() -> void:
	var grove := _grove()
	await wait_frames(4)
	var player := _player(grove)
	assert_lt(player.global_position.z, -20.0, "by the river, which is the north edge")
	assert_almost_eq(player.global_position.y, 0.0, 0.3, "on the grass")


func test_the_player_spawns_at_the_pool_bank_when_the_journey_says_so() -> void:
	GameState.set_place("grove", "pool_bank")
	var grove := _grove()
	await wait_frames(2)
	var spawn: Node3D = null
	for node: Node in get_tree().get_nodes_in_group(SpawnPoint.GROUP):
		var point := node as SpawnPoint
		if point != null and point.spawn_id == "pool_bank":
			spawn = point
	assert_not_null(
		spawn, "the Grove has a 'pool_bank' spawn point (the Veil's ascent lands on it)"
	)
	var at := _player(grove).global_position
	var flat := Vector2(at.x - spawn.global_position.x, at.z - spawn.global_position.z)
	assert_lt(flat.length(), 0.6, "the player stands on it")
	assert_gt(grove.fade_alpha(), 0.0, "and the view comes back from black")


func test_the_river_cannot_be_crossed() -> void:
	var grove := _grove()
	var player := _player(grove)
	player.global_position = Vector3(0.0, 0.1, -29.0)
	for _i in 60:
		player.set_move_input(Vector2(0.0, -1.0), 1.0)
		await wait_frames(1)
	assert_gt(player.global_position.z, -31.0, "the water's edge holds (GDD §3: cannot cross)")


# -- the calf -----------------------------------------------------------------


func test_the_calf_comes_toward_a_hum() -> void:
	var grove := _grove()
	var calf: Node3D = grove.get_node("%Calf")
	var player := _player(grove)
	assert_true(calf.is_in_group(Interactable.SOUND_SOURCE_GROUP), "it hears")
	player.global_position = calf.global_position + Vector3(0.0, 0.1, 10.0)
	await wait_frames(2)
	var before := calf.global_position.distance_to(player.global_position)
	grove.hum()
	assert_eq(calf.mode(), calf.Mode.COMING)
	await wait_frames(45)
	var after := calf.global_position.distance_to(player.global_position)
	assert_lt(after, before - 0.4, "the calf walks toward the hum")


func test_petting_the_calf_sets_the_flag_and_it_follows() -> void:
	var grove := _grove()
	var calf: Node3D = grove.get_node("%Calf")
	await _put(grove, calf.global_position + Vector3(0.0, 0.1, 1.2))
	assert_eq(_button(grove).current_verb(), "verb.pet", "beside the calf the button says Pet")
	await _press(grove)
	assert_true(GameState.has_flag("pet_calf"), "the one flag petting sets")
	assert_eq(calf.mode(), calf.Mode.FOLLOWING)
	assert_true(calf.is_nuzzling(), "it nudges back")
	var player := _player(grove)
	player.global_position = calf.global_position + Vector3(8.0, 0.1, 0.0)
	await wait_frames(150)
	var distance := calf.global_position.distance_to(player.global_position)
	assert_lt(distance, 6.0, "it comes after the player")
	assert_gt(distance, calf.FOLLOW_DISTANCE - 0.5, "but keeps its two metres")


func test_a_journey_that_pet_the_calf_finds_it_following() -> void:
	GameState.set_flag("pet_calf")
	var grove := _grove()
	var calf: Node3D = grove.get_node("%Calf")
	assert_eq(calf.mode(), calf.Mode.FOLLOWING)
	grove.hum()
	assert_eq(calf.mode(), calf.Mode.FOLLOWING, "a hum changes nothing once it follows")


# -- the water for the feast --------------------------------------------------


func test_the_pot_quest_runs_from_pick_up_to_placed() -> void:
	var grove := _grove()
	var quest: Quest = Content.quest("grove_water")
	assert_not_null(quest, "data/quests/grove_water.json loaded")
	assert_eq(quest.status(), Quest.Status.ACTIVE)
	assert_eq(quest.current_step_id(), "hear")
	# Lalita asks.
	await _put(grove, LALITA_TALK)
	assert_eq(_button(grove).current_verb(), "verb.talk")
	await _press(grove)
	assert_eq(Content.dialogue.current_line_id(), "lalita_greet")
	assert_true(GameState.has_flag("lalita_asked_water"), "the line's `sets` landed")
	assert_eq(quest.current_step_id(), "fetch")
	Content.dialogue.choose(0)
	assert_false(Content.dialogue.is_running())
	# The pot at the river.
	await _put(grove, POT_PICKUP)
	assert_eq(_button(grove).current_verb(), "verb.pick_up", "the pot at the water's edge")
	await _press(grove)
	var player := _player(grove)
	assert_true(player.is_carrying("pot"), "the pot is in hand")
	assert_true(GameState.has_event("pot_picked_up"))
	assert_false(grove.get_node("%PotPickup").visible, "and no longer on the bank")
	assert_eq(quest.current_step_id(), "carry")
	# Lalita sees it coming (requires carrying_pot, data in the dialogue file).
	await _put(grove, LALITA_TALK)
	await _press(grove)
	assert_eq(Content.dialogue.current_line_id(), "lalita_carrying")
	Content.dialogue.dismiss()
	# Placed beside her.
	await _put(grove, POT_PLACE)
	assert_eq(_button(grove).current_verb(), "verb.place", "carrying, beside her: Place")
	await _press(grove)
	assert_false(player.is_carrying(), "hands empty")
	assert_true(GameState.has_event("pot_placed"))
	assert_true(GameState.has_flag("grove_pot_placed"), "the quest's end set it")
	assert_eq(quest.status(), Quest.Status.ENDED)
	assert_true(GameState.journey_lines.has("journey.grove_water"), "one line in Your journey")
	assert_true(grove.get_node("%PlacedPot").visible, "the pot stays where it was set down")
	await _put(grove, LALITA_TALK)
	await _press(grove)
	assert_eq(Content.dialogue.current_line_id(), "lalita_thanks")


func test_the_pot_cannot_be_placed_while_the_hands_are_empty() -> void:
	var grove := _grove()
	await _put(grove, POT_PLACE)
	assert_ne(_button(grove).current_verb(), "verb.place")


# -- Scene A, the whisper -----------------------------------------------------


func _whisper(grove: Node3D, card: int, expected_line: String) -> void:
	await _put(grove, KUVERA_TALK)
	assert_eq(_button(grove).current_verb(), "verb.talk", "Kuvera, by the bank")
	await _press(grove)
	assert_eq(Content.dialogue.current_line_id(), expected_line)
	assert_eq(grove.cards().card_count(), 2, "It doesn't matter / no one")
	assert_false(GameState.has_flag("whispered_kuvera"))
	Content.dialogue.choose(card)
	assert_true(GameState.has_flag("whispered_kuvera"), "either card sets it")
	assert_eq(Content.dialogue.current_line_id(), "kuvera_place", "either way, the same answer")
	Content.dialogue.dismiss()
	await _press(grove)
	assert_eq(Content.dialogue.current_line_id(), "kuvera_after", "he does not whisper twice")
	Content.dialogue.dismiss()


func test_kuveras_first_card_sets_whispered_kuvera() -> void:
	var grove := _grove()
	await _whisper(grove, 0, "kuvera_whisper")


func test_kuveras_second_card_sets_it_too_and_he_mentions_the_water_once_carried() -> void:
	GameState.set_flag("grove_pot_placed")
	var grove := _grove()
	await _whisper(grove, 1, "kuvera_whisper_water")


# -- the swing and the bubbles ------------------------------------------------


func test_pushing_the_swing_sets_its_flag_and_lalita_laughs() -> void:
	var grove := _grove()
	var swing: Node3D = grove.get_node("%Swing")
	await _put(grove, SWING)
	assert_eq(_button(grove).current_verb(), "verb.push")
	await _press(grove)
	assert_true(GameState.has_flag("swing_pushed"))
	assert_true(swing.is_swinging(), "the seat rocks on its ropes")
	assert_eq(
		grove.get_node("%TouchControls").subtitle_text(),
		Strings.t("sub.lalita_laughs"),
		"her laugh is subtitled (GDD §11)"
	)


func test_a_bubble_drifts_and_look_opens_its_line() -> void:
	var grove := _grove()
	var bubble: Node3D = grove.get_node("Bubbles/Bubble0")
	var start := bubble.global_position
	await wait_frames(20)
	assert_ne(bubble.global_position, start, "it drifts")
	assert_lt(
		bubble.global_position.distance_to(bubble.origin()), 5.0, "but stays about its corner"
	)
	var under := bubble.global_position
	under.y = 0.1
	await _put(grove, under)
	assert_eq(_button(grove).current_verb(), "verb.look")
	await _press(grove)
	assert_eq(Content.dialogue.current_line_id(), "bubble_look")
	assert_true(GameState.has_flag("looked_bubble"))


# -- doors --------------------------------------------------------------------


func test_the_dive_door_leads_into_the_veil_toward_the_fountain_basin() -> void:
	var grove := _grove()
	watch_signals(grove)
	await _put(grove, DIVE_DOOR)
	assert_eq(_button(grove).current_verb(), "verb.dive", "at the Pool's edge: Dive")
	await _press(grove)
	assert_eq(GameState.place, "veil_down", "the fall plays between the Grove and the street")
	assert_eq(GameState.spawn, "fountain_basin")
	assert_true(grove.is_leaving())
	await wait_seconds(grove.DOOR_FADE_SECONDS + 0.3)
	assert_signal_emitted_with_parameters(grove, "place_requested", ["veil_down", "fountain_basin"])


func test_the_street_lands_a_diver_in_the_fountain_basin() -> void:
	GameState.set_place("street", "fountain_basin")
	var street := _street()
	await wait_frames(2)
	var at: Vector3 = street.get_node("%Player").global_position
	assert_almost_eq(at.x, 2.4, 0.5)
	assert_almost_eq(at.z, 2.0, 0.5)
	assert_lt(at.y, 0.0, "below street level, in the basin")


func test_the_streets_grove_door_needs_gave_dry_fountain() -> void:
	var street := _street()
	var door: Door = street.get_node("%GroveDoor")
	assert_eq(door.place_id, "grove")
	assert_eq(door.spawn_id, "pool_bank")
	assert_eq(door.verb_id, "verb.descend")
	assert_false(door.use_area().is_available(), "closed on a fresh journey")
	await _put(street, STREET_GROVE_DOOR)
	assert_ne(_button(street).current_verb(), "verb.descend", "the button never offers it")
	GameState.set_flag("gave_dry_fountain")
	await wait_frames(4)
	assert_true(door.use_area().is_available(), "open once the fountain was given water")
	assert_eq(_button(street).current_verb(), "verb.descend")
	await _press(street)
	assert_eq(GameState.place, "grove")
	assert_eq(GameState.spawn, "pool_bank")


# -- palette ------------------------------------------------------------------


## Peacock blue and magenta, as hue bands of a saturated, visible colour:
## teal through blue, and purple through magenta. Dark or washed-out colours
## are not a colour anyone reads.
func _is_forbidden(c: Color) -> bool:
	if c.v < 0.2 or c.s < 0.3:
		return false
	return (c.h >= 0.45 and c.h <= 0.66) or (c.h >= 0.75 and c.h <= 0.93)


func _materials_of(geometry: GeometryInstance3D) -> Array[Material]:
	var out: Array[Material] = []
	if geometry.material_override != null:
		out.append(geometry.material_override)
	var mesh: Mesh = null
	var mesh_instance := geometry as MeshInstance3D
	var multi := geometry as MultiMeshInstance3D
	if mesh_instance != null:
		mesh = mesh_instance.mesh
	elif multi != null and multi.multimesh != null:
		mesh = multi.multimesh.mesh
	if mesh == null:
		return out
	for surface: int in mesh.get_surface_count():
		var material: Material = null
		if mesh_instance != null:
			material = mesh_instance.get_surface_override_material(surface)
		if material == null:
			material = mesh.surface_get_material(surface)
		if material != null:
			out.append(material)
	return out


func test_no_colour_in_the_grove_is_peacock_blue_or_magenta() -> void:
	assert_true(_is_forbidden(Color(0.05, 0.42, 0.55)), "the feather's peacock blue would fail")
	assert_true(_is_forbidden(Color(0.85, 0.1, 0.8)), "magenta would fail")
	assert_false(_is_forbidden(Color(1.0, 0.74, 0.6)), "rose-gold is the Grove's own")
	var grove := _grove()
	var checked := 0
	for node: Node in grove.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		for material: Material in _materials_of(geometry):
			var standard := material as StandardMaterial3D
			if standard == null:
				continue
			checked += 1
			assert_false(
				_is_forbidden(standard.albedo_color),
				"%s wears a forbidden colour %s" % [node.name, standard.albedo_color]
			)
		var multi := geometry as MultiMeshInstance3D
		if multi != null and multi.multimesh != null and multi.multimesh.use_colors:
			for i: int in multi.multimesh.instance_count:
				var tint: Color = multi.multimesh.get_instance_color(i)
				if _is_forbidden(tint):
					fail_test("%s instance %d is %s" % [node.name, i, tint])
					break
			checked += 1
	for node: Node in grove.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		assert_false(_is_forbidden(light.light_color), "%s shines a forbidden colour" % node.name)
	var environment: Environment = grove.get_node("Environment").environment
	assert_false(_is_forbidden(environment.fog_light_color), "the fog")
	var sky: ProceduralSkyMaterial = environment.sky.sky_material
	for colour: Color in [
		sky.sky_top_color, sky.sky_horizon_color, sky.ground_bottom_color, sky.ground_horizon_color
	]:
		assert_false(_is_forbidden(colour), "the sky %s" % colour)
	assert_gt(checked, 30, "the walk saw the Grove's materials")
