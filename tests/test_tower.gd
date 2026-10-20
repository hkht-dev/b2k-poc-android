## Tests the tower climb and the dawn choice (GDD §3a "Climb the tower at
## dawn: ladder, four landings"; §5 the tower and the Rooftop; §7 the carving
## on the second landing; §8 Scene E). The stair and the landings rise, each
## ladder foot climbs to the next landing, the roof is noticed once, the
## carving and the Veena offer *Look*, and either card ends the stand's offer.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_tower_journey.json"
## The brief's landing heights; the fourth is the roof lid (14.45).
const LANDING_HEIGHTS := [3.5, 7.0, 10.5, 14.0]
const LANDING_X := -22.45
const LADDER_Z := -27.0

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


func _player(street: Node3D) -> CharacterBody3D:
	return street.get_node("%Player")


## Waits for `done` to come true, up to `frames`; returns whether it did.
func _until(done: Callable, frames: int) -> bool:
	for _i in frames:
		if done.call():
			return true
		await wait_frames(1)
	return done.call()


func _button(street: Node3D) -> Button:
	return street.get_node("%TouchControls").contextual_button()


func _landing(street: Node3D, index: int) -> Node3D:
	return street.get_node("Tower/Landing%d" % index)


func _top(street: Node3D) -> Node3D:
	return street.get_node("%TowerTop")


func _put(street: Node3D, where: Vector3) -> void:
	_player(street).global_position = where
	await wait_frames(8)


func _press(street: Node3D) -> void:
	_button(street).pressed.emit()
	await wait_frames(2)


## Stands the player beside the Veena and opens the dawn choice.
func _open_dawn_choice(street: Node3D) -> void:
	var top := _top(street)
	await _put(street, top.global_position + Vector3(0.0, 0.05, 1.4))
	assert_eq(_button(street).current_verb(), "verb.look", "the stand offers Look")
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "veena_dawn")
	assert_eq(street.cards().card_count(), 2, "the two cards of Scene E")


func test_the_stair_and_four_landings_rise_to_the_roof() -> void:
	var street := _street()
	assert_not_null(street.get_node_or_null("Tower/StairSteps"), "an external stair")
	assert_not_null(street.get_node_or_null("Tower/StairBody"), "that can be walked")
	var roof_y: float = _top(street).global_position.y
	var last_y := 0.0
	for i: int in 4:
		var landing := _landing(street, i)
		assert_not_null(landing, "landing %d exists" % i)
		var y: float = landing.global_position.y
		assert_almost_eq(
			y, LANDING_HEIGHTS[i], 0.5, "landing %d is at about %.1f m" % [i, LANDING_HEIGHTS[i]]
		)
		assert_gt(y, last_y, "the landings rise")
		last_y = y
	assert_almost_eq(last_y, roof_y, 0.01, "the fourth landing is the roof")
	assert_gt(street.get_node("Tower/TopBeam").global_position.y, roof_y + 8.0, "a beam far above")
	var ladders := get_tree().get_nodes_in_group("ladder")
	assert_eq(ladders.size(), 3, "three ladder segments between four landings")
	for ladder: Area3D in ladders:
		assert_lte(ladder.exit_position().y, roof_y + 0.1, "no segment climbs past the roof")


func test_walking_into_each_ladder_foot_climbs_to_the_next_landing() -> void:
	var street := _street()
	var player := _player(street)
	for i: int in 3:
		var from: Node3D = _landing(street, i)
		var to: Node3D = _landing(street, i + 1)
		await _put(street, from.global_position + Vector3(0.0, 0.05, 0.0))
		assert_almost_eq(
			player.global_position.y, from.global_position.y, 0.2, "standing on landing %d" % i
		)
		player.velocity = Vector3(-2.0, 0.0, 0.0)  # into the wall, where the rungs are
		await wait_frames(4)
		assert_true(player.is_climbing(), "walking into the ladder on landing %d climbs" % i)
		await wait_seconds(player.CLIMB_DURATION + 0.3)
		assert_false(player.is_climbing())
		assert_almost_eq(
			player.global_position.y,
			to.global_position.y,
			0.3,
			"and arrives on landing %d" % (i + 1)
		)


func test_walking_along_the_wall_does_not_climb() -> void:
	var street := _street()
	var player := _player(street)
	await _put(street, _landing(street, 0).global_position + Vector3(0.0, 0.05, 0.0))
	player.velocity = Vector3(0.0, 0.0, -2.0)
	await wait_frames(6)
	assert_false(player.is_climbing(), "moving along the wall is not a climb")


func test_the_roof_sets_on_the_tower_once() -> void:
	var street := _street()
	var top := _top(street)
	watch_signals(GameState)
	watch_signals(top)
	assert_false(GameState.has_flag("on_the_tower"))
	await _put(street, top.global_position + Vector3(0.0, 0.05, 3.0))
	assert_true(GameState.has_flag("on_the_tower"), "stepping onto the roof is noticed")
	assert_signal_emitted(top, "arrived")
	assert_signal_emit_count(GameState, "flag_changed", 1, "one flag, nothing else")
	await _put(street, top.global_position + Vector3(0.0, 0.05, -4.0))
	await _put(street, top.global_position + Vector3(2.0, 0.05, 3.0))
	assert_signal_emit_count(GameState, "flag_changed", 1, "and only once")
	assert_signal_emit_count(top, "arrived", 1)


func test_the_carving_on_the_second_landing_offers_look_and_sets_read_carving() -> void:
	var street := _street()
	await _put(street, _landing(street, 1).global_position + Vector3(0.0, 0.05, 0.0))
	assert_eq(_button(street).current_verb(), "verb.look", "the carving offers Look")
	var carving: Node3D = street.get_node("Tower/Carving")
	var label: Label3D = carving.get_node("%Name")
	assert_eq(label.text, Strings.t("sign.nanda_brother"), "the name comes from the string table")
	assert_false(label.text.is_empty())
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "carving_look")
	assert_true(street.cards().visible, "one line, nothing to choose")
	assert_eq(street.cards().card_count(), 0)
	assert_true(GameState.has_flag("read_carving"), "the line's `sets` landed")
	Content.dialogue.dismiss()


func test_look_is_not_offered_at_the_stand_while_carrying() -> void:
	var street := _street()
	var top := _top(street)
	await wait_frames(2)
	_player(street).carry("can")
	await _put(street, top.global_position + Vector3(0.0, 0.05, 1.4))
	assert_ne(_button(street).current_verb(), "verb.look", "hands full")


func test_playing_it_for_the_street_is_recorded_and_the_stand_offers_nothing_more() -> void:
	var street := _street()
	var top := _top(street)
	await _open_dawn_choice(street)
	var cards: Control = street.cards()
	for i: int in cards.card_count():
		var card: PanelContainer = cards.card_button(i)
		var first: PanelContainer = cards.card_button(0)
		assert_eq(card.theme_type_variation, first.theme_type_variation, "no card is marked")
		assert_eq(card.modulate, first.modulate, "nor coloured apart")
		assert_eq(card.self_modulate, first.self_modulate)
	Content.dialogue.choose(0)
	assert_true(GameState.has_flag("played_for_others"))
	assert_false(GameState.has_flag("kept_veena"))
	assert_true(GameState.journey_lines.has("journey.dawn.played"), "*Your journey* has the line")
	assert_false(GameState.journey_lines.has("journey.dawn.kept"))
	assert_eq(Content.dialogue.current_line_id(), "veena_played", "one line answers")
	assert_true(top.veena_on_stand(), "the Veena stays where it was played")
	assert_false(_player(street).is_carrying())
	Content.dialogue.dismiss()
	await wait_frames(3)
	assert_true(top.is_chosen())
	assert_ne(_button(street).current_verb(), "verb.look", "the stand offers nothing")


func test_taking_it_and_going_puts_the_veena_in_the_hand() -> void:
	var street := _street()
	var top := _top(street)
	await _open_dawn_choice(street)
	Content.dialogue.choose(1)
	assert_true(GameState.has_flag("kept_veena"))
	assert_false(GameState.has_flag("played_for_others"))
	assert_true(GameState.journey_lines.has("journey.dawn.kept"))
	assert_eq(Content.dialogue.current_line_id(), "veena_kept")
	var player := _player(street)
	assert_true(player.is_carrying("veena"), "the Veena is carried, as a flag")
	assert_true(GameState.has_flag("carrying_veena"))
	var rig: CharacterRig = street.get_node("%Player/Mesh")
	assert_true(rig.is_carrying(), "and shows in the hand")
	assert_false(top.veena_on_stand(), "the stand is empty")
	Content.dialogue.dismiss()
	await wait_frames(3)
	assert_ne(_button(street).current_verb(), "verb.look", "the stand offers nothing")


func test_a_loaded_journey_that_kept_the_veena_finds_the_stand_empty() -> void:
	GameState.set_flag("kept_veena")
	GameState.set_flag("carrying_veena")
	var street := _street()
	await wait_frames(2)
	assert_false(_top(street).veena_on_stand())
	assert_true(_player(street).is_carrying("veena"))
	assert_true(_top(street).is_chosen())


func test_the_journey_lines_and_cards_are_in_the_string_table() -> void:
	for id: String in [
		"journey.dawn.played",
		"journey.dawn.kept",
		"card.veena_dawn.play",
		"card.veena_dawn.take",
		"sign.nanda_brother",
	]:
		assert_true(Strings.has_id(id), "%s is a string" % id)
	assert_eq(Strings.t("card.veena_dawn.play"), "Play it for the street.")
	assert_eq(Strings.t("card.veena_dawn.take"), "Take it and go.")


## Drives the real chain, joystick to street to player, as test_street does:
## the Place overwrites the move input every physics frame, so only the stick
## can hold a direction. `direction` is in stick space: -y is forward (north
## with the camera at rest), -x is left (west).
func _hold_stick(street: Node3D, direction: Vector2) -> void:
	var controls: Control = street.get_node("%TouchControls")
	var stick: Control = controls.joystick()
	controls.size = Vector2(1080, 1920)
	stick.size = controls.size
	assert_true(stick.try_claim(0, Vector2(220, 1500)), "the left thumb lands on the stick")
	stick.drag_to(0, Vector2(220, 1500) + direction * stick.radius)


func test_the_stair_can_be_walked_up_to_the_first_landing() -> void:
	var street := _street()
	var player := _player(street)
	# At the stair's foot in the alley, then straight up it: no button, no new
	# code, the risers are within the feet's step.
	await _put(street, Vector3(-22.6, 0.05, -20.4))
	_hold_stick(street, Vector2(0.0, -1.0))
	await wait_seconds(5.0)
	assert_almost_eq(
		player.global_position.y,
		_landing(street, 0).global_position.y,
		0.2,
		"up the stair and on the first landing"
	)
	assert_lt(player.global_position.z, -25.0, "the north rail holds them on the deck")


func test_holding_the_stick_toward_the_wall_chains_the_segments_onto_the_roof() -> void:
	var street := _street()
	var player := _player(street)
	await _put(street, _landing(street, 0).global_position + Vector3(0.0, 0.05, 0.0))
	_hold_stick(street, Vector2(-1.0, 0.0))
	await wait_seconds(3.0 * player.CLIMB_DURATION + 2.5)
	assert_almost_eq(
		player.global_position.y,
		_landing(street, 3).global_position.y,
		0.3,
		"three segments climbed with the stick held, no button"
	)
	assert_lt(player.global_position.x, -23.0, "and on west, off the landing")
	assert_true(GameState.has_flag("on_the_tower"), "onto the roof")


func test_every_landing_above_the_first_offers_a_way_down() -> void:
	var street := _street()
	for index: int in [1, 2, 3]:
		var down: Node3D = street.get_node("Tower/Landing%d/Down" % index)
		assert_not_null(down, "landing %d can be left" % index)
		var below: Node3D = street.get_node("Tower/Landing%d/Exit" % (index - 1))
		assert_almost_eq(
			down.exit_position().y, below.global_position.y, 0.01, "it leads to the landing below"
		)
	assert_null(street.get_node_or_null("Tower/Landing0/Down"), "the first landing has the stair")


func test_the_roof_can_be_left_by_climbing_down_to_the_first_landing() -> void:
	var street := _street()
	var player: CharacterBody3D = street.get_node("%Player")
	for index: int in [3, 2, 1]:
		# Walk to the rungs on that landing, as a player would.
		var down: Node3D = street.get_node("Tower/Landing%d/Down" % index)
		player.global_position = down.global_position + Vector3(0.0, 0.2, 0.0)
		await wait_frames(8)
		assert_eq(
			_button(street).current_verb(),
			"verb.climb_down",
			"the button offers the way down from landing %d" % index
		)
		_button(street).pressed.emit()
		await wait_frames(2)
		assert_true(player.is_climbing(), "the body climbs down from landing %d" % index)
		assert_true(
			await _until(func() -> bool: return not player.is_climbing(), 120), "the climb ended"
		)
		var landing: Node3D = street.get_node("Tower/Landing%d/Exit" % (index - 1))
		assert_lt(
			player.global_position.distance_to(landing.global_position),
			1.2,
			"stood on landing %d" % (index - 1)
		)
	assert_lt(player.global_position.y, LANDING_HEIGHTS[0] + 0.6, "down at the first landing")


func test_the_carving_is_still_read_from_the_landing_itself() -> void:
	var street := _street()
	await _put(street, _landing(street, 1).global_position + Vector3(0.0, 0.05, 0.0))
	assert_eq(
		_button(street).current_verb(),
		"verb.look",
		"standing on the second landing reads the name, not the ladder"
	)
