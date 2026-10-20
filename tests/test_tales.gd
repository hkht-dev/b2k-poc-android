## Tests sitting for a tale (GDD §3a "Sit with Madhuri; tap to turn a painted
## scroll", §9a "Tales told", §6 "The Garden": hearing leaves flags): the data
## loads and every word is in the string table; the seat offers *Sit*; the
## scroll opens on the next unheard sitting; turning through one sets its
## flag; the third sets the tale's; closing early sets nothing; pause-safe.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCROLL := preload("res://scenes/ui/ScrollScreen.tscn")
const NANDA_FLAT := preload("res://scenes/places/NandaFlat.tscn")
const SCRATCH := "user://test_tales_journey.json"
## Where the player stands to be offered the street's seat: the pavement
## corner beside the cushion on the fountain's south-east step.
const BESIDE_SEAT := Vector3(-6.3, 0.0, 6.3)
## The mat at Sarang's right hand (tools/street_parts/sarang.py TALE_MAT) and
## the mat under Nanda's photograph (tools/interiors/nanda_flat.py TALE_SEAT).
const PRAHLADA_MAT := Vector3(18.57, 0.0, -11.21)
const DHRUVA_MAT := Vector3(-0.9, 0.0, 1.0)
const MAX_PANEL_WORDS := 40

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


func _seat(street: Node3D) -> TaleSeat:
	return street.get_node("%TaleSeat")


func _button(street: Node3D) -> Button:
	return street.get_node("%TouchControls").contextual_button()


func _rig(street: Node3D) -> CharacterRig:
	return street.get_node("%Player/%Mesh")


func _sit_down(street: Node3D) -> Control:
	street.get_node("%Player").global_position = BESIDE_SEAT
	await wait_frames(8)
	assert_eq(_button(street).current_verb(), "verb.sit", "the seat offers Sit")
	_button(street).pressed.emit()
	await wait_frames(2)
	return _seat(street).scroll()


func _turn_through(scroll: Control) -> void:
	for _i in scroll.panel_count():
		scroll.turn()


# -- data ----------------------------------------------------------------------


func test_the_tales_load_with_their_sittings() -> void:
	assert_true(Tales.has("puranjana"))
	assert_true(Tales.has("prahlada"))
	assert_true(Tales.has("dhruva"))
	assert_eq(Tales.sitting_count("puranjana"), 3, "Puranjana in three sittings (GDD §3a)")
	for sitting in range(1, 4):
		assert_between(Tales.panels("puranjana", sitting).size(), 5, 7, "5 to 7 panels a sitting")
	assert_eq(Tales.sitting_count("prahlada"), 1, "a witness tale, one sitting")
	assert_eq(Tales.sitting_count("dhruva"), 1)
	assert_true(Tales.panels("puranjana", 4).is_empty(), "no fourth sitting")
	assert_eq(Tales.sitting_count("nobody"), 0)


func test_every_string_id_exists_and_every_panel_is_short() -> void:
	for tale_id in Tales.ids():
		assert_true(Strings.has_id(Tales.title_id_of(tale_id)), "%s has a title" % tale_id)
		assert_true(Strings.has_id(Tales.source_id_of(tale_id)), "%s names its canto" % tale_id)
		assert_true(
			Strings.has_id(Tales.journey_line_id_of(tale_id)), "%s has a journey line" % tale_id
		)
		assert_true(
			Dialogue.REVIEW_STATUSES.has(Tales.review_status_of(tale_id)), "reviewed like a line"
		)
		for sitting in range(1, Tales.sitting_count(tale_id) + 1):
			assert_true(Strings.has_id(Tales.sitting_name_id(sitting)), "the sitting has a name")
			for panel_id in Tales.panels(tale_id, sitting):
				assert_true(Strings.has_id(panel_id), "%s is in the string table" % panel_id)
				assert_lt(
					Strings.t(panel_id).split(" ").size(),
					MAX_PANEL_WORDS,
					"%s is under %d words" % [panel_id, MAX_PANEL_WORDS]
				)


func test_the_flags_follow_the_tale_id_and_pick_the_next_sitting() -> void:
	assert_eq(Tales.sitting_flag("puranjana", 2), "heard_tale_puranjana_2")
	assert_eq(Tales.heard_flag("puranjana"), "heard_tale_puranjana")
	var flags := FlagStore.new()
	assert_eq(Tales.next_sitting("puranjana", flags), 1, "nothing heard: the first")
	flags.set_flag("heard_tale_puranjana_1")
	assert_eq(Tales.next_sitting("puranjana", flags), 2)
	flags.set_flag("heard_tale_puranjana_2")
	flags.set_flag("heard_tale_puranjana_3")
	assert_eq(Tales.next_sitting("puranjana", flags), 3, "all heard: the last, again")
	assert_eq(Tales.next_sitting("nobody", flags), 0, "an unknown tale offers nothing")
	assert_true(Tales.known_flags().has("heard_tale_dhruva_1"))
	assert_true(Tales.known_flags().has("heard_tale_dhruva"))


# -- the seat on the street ------------------------------------------------------


func test_sitting_opens_the_scroll_on_sitting_one_panel_one_with_the_table_text() -> void:
	var street := _street()
	var seat := _seat(street)
	watch_signals(seat)
	var scroll: Control = await _sit_down(street)
	assert_not_null(scroll, "the scroll opened")
	assert_true(seat.is_sitting())
	assert_signal_emitted_with_parameters(seat, "sat", ["puranjana", 1])
	assert_eq(scroll.sitting(), 1)
	assert_eq(scroll.panel_index(), 0)
	assert_eq(scroll.panel_text(), Strings.t("tale.puranjana.1.1"), "the words are the table's")
	assert_eq(scroll.get_node("%Title").text, Strings.t("tale.puranjana.title"))
	assert_eq(scroll.get_node("%Source").text, Strings.t("tale.puranjana.source"))
	assert_eq(_rig(street).state(), "pose", "the player sits")
	assert_false(street.get_node("%Player").is_physics_processing(), "and cannot walk off")
	assert_true(street.get_node("%CameraRig").is_drifting(), "the camera drifts")
	assert_eq(scroll.get_parent(), street.get_node("UI"), "over the HUD")
	await wait_frames(8)
	assert_ne(_button(street).current_verb(), "verb.sit", "no second Sit while sitting")
	assert_true(seat.is_sitting(), "and the scroll is still up")


func test_turning_through_the_first_sitting_sets_its_flag_and_closes() -> void:
	var street := _street()
	var seat := _seat(street)
	watch_signals(seat)
	var scroll: Control = await _sit_down(street)
	var panels: int = scroll.panel_count()
	for i in range(panels - 1):
		scroll.turn()
		assert_eq(scroll.panel_index(), i + 1)
		assert_false(GameState.has_flag("heard_tale_puranjana_1"), "nothing until the end")
	assert_true(scroll.is_last())
	scroll.turn()
	await wait_frames(2)
	assert_true(GameState.has_flag("heard_tale_puranjana_1"))
	assert_false(GameState.has_flag("heard_tale_puranjana"), "two sittings remain")
	assert_signal_emitted_with_parameters(seat, "sitting_finished", ["puranjana", 1])
	assert_false(seat.is_sitting(), "the scroll closed")
	assert_null(street.get_node("UI").get_node_or_null("ScrollScreen"))
	assert_ne(_rig(street).state(), "pose", "the player stands")
	assert_true(street.get_node("%Player").is_physics_processing())


func test_the_next_use_opens_sitting_two_and_three_sittings_hear_the_tale() -> void:
	var street := _street()
	var seat := _seat(street)
	var scroll: Control = await _sit_down(street)
	_turn_through(scroll)
	await wait_frames(2)
	scroll = await _sit_down(street)
	assert_eq(scroll.sitting(), 2, "the next sitting is offered next time")
	assert_eq(scroll.get_node("%Sitting").text, Strings.t("tale.sitting.2"))
	assert_eq(scroll.panel_text(), Strings.t("tale.puranjana.2.1"))
	_turn_through(scroll)
	await wait_frames(2)
	assert_true(GameState.has_flag("heard_tale_puranjana_2"))
	scroll = await _sit_down(street)
	assert_eq(scroll.sitting(), 3)
	_turn_through(scroll)
	await wait_frames(2)
	assert_true(GameState.has_flag("heard_tale_puranjana_3"))
	assert_true(GameState.has_flag("heard_tale_puranjana"), "the whole tale was heard")
	assert_true(GameState.journey_lines.has("journey.tale.puranjana"), "and Your journey says so")
	assert_eq(seat.offered_sitting(), 3, "re-hearing is allowed: the last sitting again")
	scroll = await _sit_down(street)
	assert_eq(scroll.sitting(), 3)
	assert_eq(scroll.panel_text(), Strings.t("tale.puranjana.3.1"))


func test_a_journey_that_heard_one_sitting_resumes_at_the_second() -> void:
	GameState.set_flag("heard_tale_puranjana_1")
	var street := _street()
	assert_eq(_seat(street).offered_sitting(), 2)
	var scroll: Control = await _sit_down(street)
	assert_eq(scroll.sitting(), 2)


func test_close_mid_sitting_sets_nothing_and_stands_the_player_up() -> void:
	var street := _street()
	var seat := _seat(street)
	var scroll: Control = await _sit_down(street)
	scroll.turn()
	scroll.turn()
	scroll.get_node("%CloseButton").pressed.emit()
	await wait_frames(2)
	assert_false(seat.is_sitting())
	assert_false(GameState.has_flag("heard_tale_puranjana_1"), "nothing recorded")
	assert_true(GameState.flags.all().is_empty(), "no flag at all")
	assert_true(GameState.journey_lines.is_empty())
	assert_ne(_rig(street).state(), "pose")
	assert_true(street.get_node("%Player").is_physics_processing())
	scroll = await _sit_down(street)
	assert_eq(scroll.sitting(), 1, "the first sitting is offered again")
	assert_eq(scroll.panel_index(), 0)


func test_back_goes_back_one_panel_and_no_further() -> void:
	var street := _street()
	var scroll: Control = await _sit_down(street)
	var back: Button = scroll.get_node("%BackButton")
	assert_true(back.disabled, "nothing to go back to")
	scroll.turn()
	scroll.turn()
	assert_false(back.disabled)
	back.pressed.emit()
	assert_eq(scroll.panel_index(), 1)
	assert_eq(scroll.panel_text(), Strings.t("tale.puranjana.1.2"))
	scroll.back()
	scroll.back()
	assert_eq(scroll.panel_index(), 0, "Back stops at the first panel")
	assert_true(_seat(street).is_sitting(), "and never closes the scroll")


func test_keys_turn_and_are_ignored_while_paused() -> void:
	var street := _street()
	var scroll: Control = await _sit_down(street)
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	# No awaits while paused (the frame waiter pauses with the tree).
	street.pause()
	scroll._unhandled_input(accept)
	assert_eq(scroll.panel_index(), 0, "paused: nothing turns")
	street.resume()
	await wait_frames(1)
	scroll._unhandled_input(accept)
	assert_eq(scroll.panel_index(), 1, "Enter turns the page")
	var use := InputEventAction.new()
	use.action = "contextual"
	use.pressed = true
	scroll._last_turn_ms = -1000
	scroll._unhandled_input(use)
	assert_eq(scroll.panel_index(), 2, "the gamepad's A turns too")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	scroll._unhandled_input(escape)
	assert_eq(scroll.panel_index(), 2, "Escape is not the scroll's: it stays the pause")
	assert_true(_seat(street).is_sitting())


func test_a_tap_turns_once_even_as_touch_and_emulated_click() -> void:
	var street := _street()
	var scroll: Control = await _sit_down(street)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	scroll._gui_input(touch)
	scroll._gui_input(click)
	assert_eq(scroll.panel_index(), 1, "one tap, one turn")


# -- the scroll itself ------------------------------------------------------------


func test_the_scroll_shows_a_one_sitting_tale_without_a_sitting_name_or_counter() -> void:
	var scroll: Control = add_child_autofree(SCROLL.instantiate())
	await wait_frames(1)
	scroll.open("dhruva", 1)
	assert_eq(scroll.get_node("%Title").text, Strings.t("tale.dhruva.title"))
	assert_false(scroll.get_node("%Sitting").visible, "one sitting needs no name")
	assert_eq(scroll.get_node("%Source").text, Strings.t("tale.dhruva.source"))
	assert_eq(scroll.get_node("%Hint").text, Strings.t("scroll.turn"))
	for _i in scroll.panel_count() - 1:
		scroll.turn()
	assert_true(scroll.is_last())
	assert_eq(scroll.get_node("%Hint").text, Strings.t("scroll.roll_up"))
	var counter := RegEx.create_from_string("\\d+\\s*/\\s*\\d+")
	for label: Node in scroll.find_children("*", "Label", true, false):
		assert_null(counter.search((label as Label).text), "no page counter anywhere")
	for node: Node in scroll.find_children("*", "Range", true, false):
		fail_test("no bar or meter on the scroll: %s" % node.name)
	var paper: Rect2 = scroll.paper_rect()
	assert_gt(paper.size.x, 0.0)
	assert_true(
		paper.encloses(Rect2(scroll.get_node("%Panel").position, scroll.get_node("%Panel").size)),
		"the words lie on the paper"
	)
	assert_eq(scroll.get_node("%BackButton").text, Strings.t("scroll.back"))
	assert_eq(scroll.get_node("%CloseButton").text, Strings.t("scroll.close"))


func _seats_in(place: Node3D) -> Dictionary:
	var out := {}
	for node: Node in place.find_children("*", "Node3D", true, false):
		if node is TaleSeat:
			out[node.tale_id] = node
	return out


func test_every_tale_in_the_data_has_a_seat_in_some_place() -> void:
	var street := _street()
	var flat: Node3D = add_child_autofree(NANDA_FLAT.instantiate())
	var seats := _seats_in(street)
	seats.merge(_seats_in(flat))
	for tale_id: String in Tales.ids():
		assert_true(seats.has(tale_id), "a seat somewhere for '%s'" % tale_id)
	assert_true(
		seats.has("prahlada") and seats["prahlada"].get_parent().name == "SarangCorner",
		"the teacher tells Prahlada"
	)
	assert_true(
		seats.has("dhruva") and flat.is_ancestor_of(seats["dhruva"]), "Nanda's flat has Dhruva"
	)


func test_the_mat_beside_sarang_offers_sit_not_talk() -> void:
	var street := _street()
	street.get_node("%Player").global_position = PRAHLADA_MAT
	await wait_frames(8)
	assert_eq(_button(street).current_verb(), "verb.sit", "on the mat, the seat wins over Sarang")
	var sarang: Node3D = street.get_node("%Sarang")
	assert_lt(PRAHLADA_MAT.distance_to(sarang.global_position), 3.5, "and it is at his side")


func test_the_mat_in_nandas_flat_offers_sit_and_opens_dhruva() -> void:
	var flat: Node3D = add_child_autofree(NANDA_FLAT.instantiate())
	flat.get_node("%TouchControls").apply_scheme("touch")
	flat.get_node("%Player").global_position = DHRUVA_MAT
	await wait_frames(8)
	var button: Button = flat.get_node("%TouchControls").contextual_button()
	assert_eq(button.current_verb(), "verb.sit")
	button.pressed.emit()
	await wait_frames(2)
	var scroll: Control = flat.get_node("%TaleSeat").scroll()
	assert_not_null(scroll, "the scroll opened")
	if scroll != null:
		assert_eq(scroll.tale_id(), "dhruva")
		scroll.close()


func test_sitting_holds_the_body_still_and_silences_the_feet() -> void:
	var street := _street()
	var player: CharacterBody3D = street.get_node("%Player")
	player.global_position = BESIDE_SEAT
	await wait_frames(8)
	player.set_move_input(Vector2(0.0, -1.0), 1.0)
	await wait_frames(6)
	assert_true(player.is_footsteps_playing(), "walking up to it")
	_button(street).pressed.emit()
	await wait_frames(2)
	assert_not_null(_seat(street).scroll(), "sat")
	assert_true(player.is_held_still(), "held on the seat")
	assert_false(player.is_footsteps_playing(), "the feet fall silent")
	assert_eq(player.velocity, Vector3.ZERO)
	_seat(street).scroll().close()
	await wait_frames(1)
	assert_false(player.is_held_still(), "and let go on standing up")
