## Tests the three competitors on the Street: Rukma asleep at the bus stop,
## Bhima Lal by Gopal's shop, Old Nanda at his door (GDD §4; §7 main quest
## table, the Compete and Mediate steps). Each offers *Talk* where they
## stand, and every flag the steps name is set by the dialogue data; nothing
## here reads a path.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_competitors_journey.json"

## Where the player stands to talk to each: in front of Rukma on the road
## side of the bench, in front of Bhima Lal on the fountain's step, in front
## of Nanda on his doorstep, and square to the door itself.
const RUKMA_SPOT := Vector3(7.3, 0.3, 19.8)
const BHIMA_SPOT := Vector3(-6.6, 0.1, 5.4)
const NANDA_SPOT := Vector3(-27.3, 0.1, -16.0)
const DOOR_SPOT := Vector3(-29.0, 0.1, -17.3)

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


func _button(street: Node3D) -> Button:
	return street.get_node("%TouchControls").contextual_button()


func _put(street: Node3D, where: Vector3) -> void:
	_player(street).global_position = where
	await wait_frames(8)


func _press(street: Node3D) -> void:
	_button(street).pressed.emit()
	await wait_frames(2)


## Stands at the spot, checks the button says Talk, and presses it.
func _talk(street: Node3D, where: Vector3, who: String) -> void:
	await _put(street, where)
	assert_eq(_button(street).current_verb(), "verb.talk", "%s offers Talk" % who)
	await _press(street)


func _cards_setting(line_id: String, flag: String) -> int:
	var count := 0
	for card: Dictionary in Content.dialogue.get_line(line_id)["cards"]:
		if card["sets"].has(flag):
			count += 1
	return count


# -- they are there ------------------------------------------------------------


func test_all_three_stand_on_the_street_and_offer_talk() -> void:
	var street := _street()
	for entry: Array in [
		["%Rukma", RUKMA_SPOT, "rukma_greet"],
		["%BhimaLal", BHIMA_SPOT, "bhima_greet"],
		["%Nanda", NANDA_SPOT, "nanda_greet"],
	]:
		assert_not_null(street.get_node_or_null(entry[0]), "%s is placed" % entry[0])
		await _talk(street, entry[1], entry[0])
		assert_eq(Content.dialogue.current_line_id(), entry[2], "%s opens the greeting" % entry[0])
		assert_true(street.cards().visible, "the line is on screen")
		Content.dialogue.dismiss()
		await wait_frames(1)


func test_rukma_sits_asleep_on_the_bench_and_bhima_is_the_big_one() -> void:
	var street := _street()
	await wait_frames(3)
	var rukma: CharacterRig = street.get_node("%Rukma/%Figure")
	assert_eq(rukma.idle_animation, "Sitting_Idle", "she sits (PLACEHOLDER for asleep)")
	assert_eq(rukma.state(), "idle")
	var rukma_pos: Vector3 = street.get_node("%Rukma").global_position
	assert_almost_eq(rukma_pos.x, 7.3, 0.01)
	assert_almost_eq(rukma_pos.z, 21.0, 0.01, "on the bus stop bench")
	var bhima: CharacterRig = street.get_node("%BhimaLal/%Figure")
	var nanda: CharacterRig = street.get_node("%Nanda/%Figure")
	assert_gt(bhima.height, nanda.height, "the gentle giant stands taller")
	assert_ne(rukma.skin, bhima.skin, "distinct skins")
	assert_ne(bhima.skin, nanda.skin)
	assert_ne(rukma.skin, nanda.skin)


# -- Rukma ---------------------------------------------------------------------


func test_asking_rukma_why_she_needs_to_win_sets_rukma_heard() -> void:
	var street := _street()
	await _talk(street, RUKMA_SPOT, "Rukma")
	var dialogue: Dialogue = Content.dialogue
	assert_eq(dialogue.current_line_id(), "rukma_greet")
	assert_false(GameState.has_flag("rukma_heard"))
	dialogue.choose(0)  # wake her: why
	assert_eq(dialogue.current_line_id(), "rukma_why")
	assert_true(GameState.has_flag("rukma_heard"), "hearing her out is the flag (GDD §7 Mediate)")
	dialogue.choose(0)  # does anyone need you to
	assert_eq(dialogue.current_line_id(), "rukma_enough")
	assert_false(GameState.has_flag("rukma_key_taken"), "nothing was taken")
	assert_false(GameState.has_flag("rukma_key_traded"))
	dialogue.dismiss()


func test_taking_the_key_while_she_sleeps_sets_the_flag_and_the_line_closes() -> void:
	var street := _street()
	await _talk(street, RUKMA_SPOT, "Rukma")
	var dialogue: Dialogue = Content.dialogue
	assert_eq(_cards_setting("rukma_greet", "rukma_key_taken"), 1, "the greeting carries the take")
	dialogue.choose(1)  # her bag is open
	assert_true(GameState.has_flag("rukma_key_taken"), "the card sets it (GDD §7 Compete)")
	assert_eq(dialogue.current_line_id(), "rukma_key_pocketed")
	assert_false(GameState.has_flag("rukma_heard"), "she slept through it")
	dialogue.dismiss()
	await wait_frames(1)
	await _press(street)
	assert_eq(
		dialogue.current_line_id(),
		"rukma_after_key",
		"Talk no longer opens the line with the take card"
	)
	assert_eq(_cards_setting("rukma_after_key", "rukma_key_taken"), 0, "it cannot be taken twice")
	dialogue.choose(0)  # she can still be woken and heard
	assert_eq(dialogue.current_line_id(), "rukma_why")
	assert_true(GameState.has_flag("rukma_heard"), "a competitor can still mediate (GDD §7)")
	dialogue.dismiss()


func test_the_trade_needs_a_can_in_hand_and_clears_nothing() -> void:
	var street := _street()
	assert_false(Content.dialogue.start("rukma_greet_can"), "no water, no trade")
	_player(street).carry()
	assert_true(GameState.has_flag("carrying_can"))
	await _talk(street, RUKMA_SPOT, "Rukma")
	var dialogue: Dialogue = Content.dialogue
	assert_eq(dialogue.current_line_id(), "rukma_greet_can", "with a can she wakes to it")
	dialogue.choose(0)  # the roof key, for the water
	assert_true(GameState.has_flag("rukma_key_traded"))
	assert_true(GameState.has_flag("carrying_can"), "flags are only set here; nothing is cleared")
	assert_false(GameState.has_flag("rukma_key_taken"), "a trade is not a theft")
	assert_eq(dialogue.current_line_id(), "rukma_traded")
	dialogue.dismiss()
	await wait_frames(1)
	await _press(street)
	assert_eq(dialogue.current_line_id(), "rukma_after_trade")
	dialogue.dismiss()


# -- Bhima Lal -------------------------------------------------------------------


func test_bhima_tells_of_his_daughter_and_the_offer_sets_bhima_asked() -> void:
	var street := _street()
	await _talk(street, BHIMA_SPOT, "Bhima Lal")
	var dialogue: Dialogue = Content.dialogue
	assert_eq(dialogue.current_line_id(), "bhima_greet")
	dialogue.choose(0)  # why does it matter
	assert_eq(dialogue.current_line_id(), "bhima_daughter")
	assert_false(GameState.has_flag("bhima_asked"))
	dialogue.choose(0)  # I'll ask Gopal
	assert_true(GameState.has_flag("bhima_asked"), "the card sets it (GDD §7 Mediate)")
	assert_eq(dialogue.current_line_id(), "bhima_asked")
	dialogue.dismiss()
	await wait_frames(1)
	await _press(street)
	assert_eq(dialogue.current_line_id(), "bhima_waiting", "he waits on the answer")
	dialogue.dismiss()


func test_his_thanks_need_the_fountain_to_run() -> void:
	var street := _street()
	var dialogue: Dialogue = Content.dialogue
	assert_false(dialogue.start("bhima_thanks"), "no thanks before gave_dry_fountain")
	assert_false(GameState.has_flag("bhima_medicine_given"))
	await _talk(street, BHIMA_SPOT, "Bhima Lal")
	assert_eq(dialogue.current_line_id(), "bhima_greet", "until then, the greeting")
	dialogue.dismiss()
	await wait_frames(1)
	GameState.set_flag("gave_dry_fountain")
	await _press(street)
	assert_eq(dialogue.current_line_id(), "bhima_thanks", "the give path treats his daughter")
	assert_true(GameState.has_flag("bhima_medicine_given"), "the line sets it")
	dialogue.dismiss()


# -- Old Nanda -----------------------------------------------------------------


func test_sitting_with_nanda_through_three_lines_sets_nanda_listened() -> void:
	var street := _street()
	await _talk(street, NANDA_SPOT, "Nanda")
	var dialogue: Dialogue = Content.dialogue
	assert_eq(dialogue.current_line_id(), "nanda_greet")
	dialogue.choose(0)  # I'd rather sit here a while
	assert_eq(dialogue.current_line_id(), "nanda_sit_1")
	dialogue.choose(1)  # the top of it?
	assert_eq(dialogue.current_line_id(), "nanda_sit_2")
	assert_false(GameState.has_flag("nanda_listened"), "not until he has finished")
	dialogue.choose(0)  # I'll read it
	assert_eq(dialogue.current_line_id(), "nanda_sit_3")
	assert_true(GameState.has_flag("nanda_listened"), "the third line sets it (GDD §7 Mediate)")
	dialogue.dismiss()
	await wait_frames(1)
	await _press(street)
	assert_eq(dialogue.current_line_id(), "nanda_after_listen")
	dialogue.dismiss()


func test_the_back_stairs_card_needs_accepted_contest() -> void:
	var street := _street()
	var dialogue: Dialogue = Content.dialogue
	assert_false(dialogue.start("nanda_greet_contest"), "not a competitor yet")
	await _talk(street, NANDA_SPOT, "Nanda")
	assert_eq(dialogue.current_line_id(), "nanda_greet")
	assert_eq(
		_cards_setting("nanda_greet", "nanda_told_shortcut"), 0, "no stairs card for a visitor"
	)
	dialogue.dismiss()
	await wait_frames(1)
	GameState.set_flag("accepted_contest")
	await _press(street)
	assert_eq(dialogue.current_line_id(), "nanda_greet_contest")
	var cards: Array = dialogue.get_line("nanda_greet_contest")["cards"]
	var stairs := -1
	for index: int in cards.size():
		if cards[index]["sets"].has("nanda_told_shortcut"):
			stairs = index
	assert_gte(stairs, 0, "a competitor is offered the stairs card")
	dialogue.choose(stairs)
	assert_true(GameState.has_flag("nanda_told_shortcut"), "the card sets it (GDD §7 Compete)")
	assert_eq(dialogue.current_line_id(), "nanda_shortcut")
	assert_false(GameState.has_flag("nanda_listened"), "a shortcut is not listening")
	dialogue.dismiss()
	await wait_frames(1)
	await _press(street)
	assert_eq(dialogue.current_line_id(), "nanda_after_shortcut")
	dialogue.dismiss()


func test_looking_at_his_door_opens_one_thought_under_his_sign() -> void:
	var street := _street()
	var sign: Label3D = street.get_node("Competitors/NandaSign")
	assert_eq(sign.text, Strings.t("sign.nanda"), "the sign reads from the string table")
	await _put(street, DOOR_SPOT)
	assert_eq(_button(street).current_verb(), "verb.look", "the door offers Look, not Talk")
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "nanda_door_look")
	assert_eq(street.cards().card_count(), 0, "one thought, no cards")
	assert_true(street.cards().visible)
	Content.dialogue.dismiss()
	assert_false(street.cards().visible)
	assert_null(
		street.get_node_or_null("Competitors/NandaDoor/Use"), "not a Door: it leads nowhere"
	)


func test_no_card_is_marked_and_no_line_runs_long() -> void:
	var dialogue: Dialogue = Content.dialogue
	for line_id: String in dialogue.line_ids():
		if not (
			line_id.begins_with("rukma_")
			or line_id.begins_with("bhima_")
			or line_id.begins_with("nanda_")
		):
			continue
		var line := dialogue.get_line(line_id)
		assert_lt(Strings.t(line["text_id"]).split(" ").size(), 20, "%s under 20 words" % line_id)
		var count: int = line["cards"].size()
		assert_true(count == 0 or count == 2 or count == 3, "%s: two or three cards" % line_id)
		for card: Dictionary in line["cards"]:
			assert_lt(Strings.t(card["text_id"]).split(" ").size(), 20)
