## Tests P4, The Dry Fountain (CLAUDE_CODE_BRIEF.md §4.4, GDD §7): the three
## outcomes play from the data — Look, Talk through the cards, Pick up, Place
## — with the flags deciding everything and no path variable anywhere.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_p4_journey.json"
const STATE := preload("res://scripts/core/game_state.gd")

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


## Walks Gopal's conversation by card index until he admits the fear.
func _talk_until_admit(street: Node3D, last_card: int) -> void:
	await _put(street, Vector3(-13.2, 0.16, 3.0))
	assert_eq(_button(street).current_verb(), "verb.talk", "the counter offers Talk")
	await _press(street)
	var dialogue: Dialogue = Content.dialogue
	assert_eq(dialogue.current_line_id(), "gopal_greet")
	dialogue.choose(0)  # why not today
	dialogue.choose(0)  # how many
	dialogue.choose(0)  # a lot
	assert_eq(dialogue.current_line_id(), "gopal_admit")
	dialogue.choose(last_card)


func test_look_at_the_fountain_sets_the_flag_and_opens_the_quest() -> void:
	var street := _street()
	await _put(street, Vector3(2.4, -0.4, 2.0))
	assert_eq(_button(street).current_verb(), "verb.look", "in the basin the fountain offers Look")
	await _press(street)
	assert_true(GameState.has_flag("looked_dry_fountain"), "the line's `sets` landed")
	assert_true(street.cards().visible, "the fountain's line is on screen")
	assert_eq(Content.quest("dry_fountain").current_step_id(), "hear_him_out")


func test_take_a_can_without_asking_ends_the_quest_on_the_took_branch() -> void:
	var street := _street()
	await _put(street, Vector3(-14.0, 0.16, 3.6))
	assert_eq(_button(street).current_verb(), "verb.pick_up", "the stack offers Pick up")
	var stack: Node3D = street.get_node("Shop/CanStack")
	var before: int = stack.cans_left()
	await _press(street)
	assert_true(_player(street).is_carrying(), "the player holds a can")
	assert_eq(stack.cans_left(), before - 1, "one can left the stack")
	assert_true(GameState.has_event("can_taken_from_shop"))
	assert_true(GameState.has_flag("took_dry_fountain"), "the take branch fired (quest data)")
	assert_false(GameState.has_flag("gave_dry_fountain"))
	assert_eq(Content.quest("dry_fountain").status(), Quest.Status.ENDED)
	assert_true(GameState.journey_lines.has("journey.dry_fountain.took"))
	await _put(street, Vector3(2.4, -0.4, 2.0))
	assert_ne(
		_button(street).current_verb(),
		"verb.place",
		"a taken can cannot be placed: the fountain stays dry"
	)
	await _put(street, Vector3(-13.2, 0.16, 3.0))
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "gopal_hurt", "Gopal says the hurt line")


func test_talk_until_he_admits_then_carry_one_with_him_fills_the_fountain() -> void:
	var street := _street()
	await _talk_until_admit(street, 0)  # carry one with me
	assert_true(GameState.has_flag("gopal_admitted_fear"))
	assert_true(GameState.has_flag("gopal_will_carry"))
	assert_eq(Content.dialogue.current_line_id(), "gopal_agree")
	Content.dialogue.dismiss()
	await _put(street, Vector3(-14.0, 0.16, 3.6))
	await _press(street)
	assert_true(_player(street).is_carrying())
	assert_false(GameState.has_flag("took_dry_fountain"), "with him it is not a theft")
	var gopal: Node3D = street.get_node("%Gopal")
	await wait_frames(2)
	assert_eq(gopal.mode(), gopal.Mode.WALKING_WITH, "Gopal walks with the player")
	await _put(street, Vector3(2.4, -0.4, 2.0))
	assert_eq(
		_button(street).current_verb(),
		"verb.place",
		"in the basin, carrying, the fountain offers Place"
	)
	await _press(street)
	assert_false(_player(street).is_carrying())
	assert_true(GameState.has_event("can_placed_at_fountain"))
	assert_true(GameState.has_flag("gave_dry_fountain"), "the quest's carry step set it")
	assert_eq(Content.quest("dry_fountain").status(), Quest.Status.ENDED)
	assert_true(GameState.journey_lines.has("journey.dry_fountain.gave"))
	var fountain: Node3D = street.get_node("%FountainPoint")
	await wait_frames(10)
	assert_gt(fountain.fill(), 0.0, "the water is rising")
	assert_true(fountain.get_node("%WaterPlane").visible)
	assert_ne(
		gopal.mode(),
		gopal.Mode.WALKING_WITH,
		"Gopal stops walking with the player (back to the counter)"
	)


func test_decline_leaves_everything_as_it_was() -> void:
	var street := _street()
	await _talk_until_admit(street, 1)  # keep them
	assert_true(GameState.has_flag("gopal_admitted_fear"))
	assert_false(GameState.has_flag("gopal_will_carry"))
	assert_eq(Content.dialogue.current_line_id(), "gopal_decline")
	Content.dialogue.dismiss()
	await _put(street, Vector3(-13.2, 0.16, 3.0))
	await _press(street)
	assert_eq(
		Content.dialogue.current_line_id(), "gopal_decline", "he says it again, not the greeting"
	)
	assert_eq(Content.quest("dry_fountain").status(), Quest.Status.ACTIVE)


func test_the_light_answers_the_outcome() -> void:
	var street := _street()
	await wait_frames(2)
	var before: Color = street.mood_sun_colour()
	GameState.set_flag("took_dry_fountain")
	await wait_frames(2)
	assert_ne(street.mood_sun_colour(), before, "a taken can steps the light")


func test_carrying_survives_a_save_and_shows_in_the_hand() -> void:
	var street := _street()
	await wait_frames(2)
	_player(street).carry()
	var rig: CharacterRig = street.get_node("%Player/Mesh")
	assert_true(rig.is_carrying(), "the rig holds the can")
	assert_not_null(rig.skeleton().find_child("Carried", false, false))
	GameState.save()
	var loaded: Node = STATE.new()
	loaded.save_path = SCRATCH
	loaded.load_journey()
	assert_true(loaded.has_flag("carrying_can"), "carrying is a flag, so it is saved")
	_player(street).put_down()
	assert_false(rig.is_carrying())


func test_no_option_is_labelled_and_no_score_meter_or_marker_appears() -> void:
	var street := _street()
	await _put(street, Vector3(-13.2, 0.16, 3.0))
	await _press(street)
	var cards: Control = street.cards()
	assert_eq(cards.card_count(), 3, "three full-sentence cards")
	for i: int in cards.card_count():
		var a: PanelContainer = cards.card_button(i)
		assert_eq(a.get_class(), cards.card_button(0).get_class(), "every card drawn the same")
	for node: Node in street.get_node("UI").get_children():
		assert_false(node is ProgressBar, "no meter")
