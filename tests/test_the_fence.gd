## Tests the side quest *The Fence* (GDD §7; §4 Vasanti): the quest loads from
## data, Vasanti talks at the gate, and all three outcomes play from the flags
## alone — *Mend* ends on `fixed`; a fruit picked and placed with her, or the
## humming boy named, ends on `open` and takes the padlock off.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_the_fence_journey.json"
const STRINGS_PATH := "res://data/strings/en.json"

const AT_VASANTI := Vector3(-29.6, 0.16, 9.8)
const AT_GATE := Vector3(-31.7, 0.16, 8.6)
const AT_TREE := Vector3(-25.0, 0.0, 3.9)

var _real_path := ""


func before_each() -> void:
	_real_path = GameState.save_path
	GameState.save_path = SCRATCH
	GameState.set_autosave(false)
	GameState.wipe()


func after_each() -> void:
	get_tree().paused = false
	Content.dialogue.dismiss()
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


func _padlock(street: Node3D) -> Node3D:
	return street.get_node("Fences/Padlock")


## Talks to Vasanti the first time and lets her finish.
func _meet_her(street: Node3D) -> void:
	await _put(street, AT_VASANTI)
	assert_eq(_button(street).current_verb(), "verb.talk", "Vasanti offers Talk at the gate")
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "vasanti_greet")
	Content.dialogue.choose(1)  # the gate's hanging off
	assert_eq(Content.dialogue.current_line_id(), "vasanti_fence")
	Content.dialogue.choose(0)  # I'll see to it
	assert_false(Content.dialogue.is_running())


func test_the_quest_loads_from_data_and_starts_when_she_is_met() -> void:
	var quest: Quest = Content.quest("the_fence")
	assert_not_null(quest, "data/quests/the_fence.json loads")
	assert_eq(quest.giver, "vasanti")
	assert_eq(quest.status(), Quest.Status.INACTIVE, "nothing until she is met or fruit is picked")
	GameState.set_flag("talked_vasanti")
	assert_eq(quest.status(), Quest.Status.ACTIVE)
	assert_eq(quest.current_step_id(), "decide")
	for line_id: String in [
		"vasanti_greet", "vasanti_hum_clue", "vasanti_opens", "vasanti_gift", "vasanti_after_fixed"
	]:
		assert_true(Content.dialogue.has_line(line_id), "dialogue has %s" % line_id)


func test_vasanti_offers_talk_at_the_gate_and_her_cards_carry_no_cue() -> void:
	var street := _street()
	await _put(street, AT_VASANTI)
	assert_eq(_button(street).current_verb(), "verb.talk")
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "vasanti_greet")
	assert_true(GameState.has_flag("talked_vasanti"), "the greeting's `sets` landed")
	assert_eq(Content.quest("the_fence").status(), Quest.Status.ACTIVE)
	var cards: Control = street.cards()
	assert_true(cards.visible)
	assert_eq(cards.card_count(), 3, "three full-sentence cards")
	for i: int in cards.card_count():
		var card: PanelContainer = cards.card_button(i)
		var first: PanelContainer = cards.card_button(0)
		assert_eq(
			card.theme_type_variation, first.theme_type_variation, "every card the same style"
		)
		assert_eq(card.modulate, first.modulate, "and the same colour")
		assert_eq(card.self_modulate, first.self_modulate)


func test_mend_is_not_offered_before_talking_to_her() -> void:
	var street := _street()
	await _put(street, AT_GATE)
	assert_ne(_button(street).current_verb(), "verb.fix", "the gate asks nothing of a stranger")
	var gate: Node3D = street.get_node("%GardenGate")
	assert_true(gate.is_padlocked())
	assert_almost_eq(gate.leaf_yaw(), gate.ajar_yaw, 0.001, "the gate hangs off its hinge")


func test_mending_the_gate_fires_the_event_and_ends_on_the_fixed_branch() -> void:
	var street := _street()
	await _meet_her(street)
	await _put(street, AT_GATE)
	assert_eq(_button(street).current_verb(), "verb.fix", "once met, the gate offers Mend")
	await _press(street)
	assert_true(GameState.has_event("fence_mended"))
	var quest: Quest = Content.quest("the_fence")
	assert_eq(quest.status(), Quest.Status.ENDED)
	assert_eq(quest.ended_branch(), "fixed")
	assert_true(GameState.has_flag("has_fruit"), "the fixed branch says she gave fruit")
	assert_false(GameState.has_flag("garden_open"))
	assert_true(_player(street).is_carrying("fruit"), "and the fruit is in the player's hand")
	assert_true(GameState.journey_lines.has("journey.the_fence.fixed"))
	assert_false(GameState.journey_lines.has("journey.the_fence.open"))
	assert_eq(Content.dialogue.current_line_id(), "vasanti_after_fixed", "she hands it over")
	var gate: Node3D = street.get_node("%GardenGate")
	assert_true(gate.is_padlocked(), "the padlock stays on")
	await wait_seconds(gate.SWING_SECONDS + 0.3)
	assert_almost_eq(gate.leaf_yaw(), 0.0, 0.02, "the gate sits true on its hinge")
	await _put(street, AT_GATE)
	assert_ne(_button(street).current_verb(), "verb.fix", "nothing left to mend")


func test_picking_fruit_and_placing_it_with_her_opens_the_garden() -> void:
	var street := _street()
	var tree: Node3D = street.get_node("%FruitTree")
	var before: int = tree.fruit_left()
	await _put(street, AT_TREE)
	assert_eq(_button(street).current_verb(), "verb.pick_up", "the tree offers Pick up")
	await _press(street)
	assert_true(_player(street).is_carrying("fruit"))
	assert_eq(tree.fruit_left(), before - 1, "one fruit left the branch")
	assert_true(GameState.has_event("fruit_picked"))
	assert_eq(Content.quest("the_fence").status(), Quest.Status.ACTIVE, "picking opens the quest")
	await _put(street, AT_VASANTI)
	assert_eq(_button(street).current_verb(), "verb.place", "carrying fruit, she offers Place")
	await _press(street)
	assert_false(_player(street).is_carrying())
	assert_true(GameState.has_event("fruit_given"))
	assert_true(GameState.has_flag("garden_open"), "the open branch (quest data)")
	assert_false(GameState.has_flag("has_fruit"))
	var quest: Quest = Content.quest("the_fence")
	assert_eq(quest.status(), Quest.Status.ENDED)
	assert_eq(quest.ended_branch(), "open_gift")
	assert_true(GameState.journey_lines.has("journey.the_fence.open"))
	assert_eq(Content.dialogue.current_line_id(), "vasanti_gift")
	assert_false(_padlock(street).visible, "the padlock is gone")
	var vasanti: Node3D = street.get_node("%Vasanti")
	assert_true(vasanti.get_node("%Figure").is_carrying(), "she holds the fruit")
	var gate: Node3D = street.get_node("%GardenGate")
	await wait_seconds(gate.SWING_SECONDS + 0.3)
	assert_almost_eq(gate.leaf_yaw(), gate.open_yaw, 0.02, "the gate swings wide")
	await _put(street, AT_GATE)
	assert_ne(_button(street).current_verb(), "verb.fix", "an open gate is not for mending")


func test_naming_the_humming_boy_opens_the_garden() -> void:
	var street := _street()
	GameState.set_flag("heard_tulu")
	await _meet_her(street)
	assert_false(GameState.has_flag("fence_thief_known"))
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "vasanti_hum_clue", "second visit: the humming")
	assert_true(GameState.has_flag("fence_thief_known"), "the clue is the line")
	Content.dialogue.choose(0)  # the boy at the fountain
	assert_true(GameState.has_flag("told_vasanti_thief"))
	assert_true(GameState.has_flag("garden_open"))
	assert_eq(Content.dialogue.current_line_id(), "vasanti_opens")
	var quest: Quest = Content.quest("the_fence")
	assert_eq(quest.status(), Quest.Status.ENDED)
	assert_eq(quest.ended_branch(), "open_told")
	assert_true(GameState.journey_lines.has("journey.the_fence.open"))
	await wait_frames(2)
	assert_false(_padlock(street).visible, "the padlock is gone")


func test_without_hearing_tulu_the_second_visit_names_nobody() -> void:
	var street := _street()
	await _meet_her(street)
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "vasanti_again")
	assert_false(GameState.has_flag("fence_thief_known"))


func test_the_journey_lines_are_exactly_the_string_table_text() -> void:
	var table: Dictionary = Strings.read_json_file(STRINGS_PATH)
	for line_id: String in ["journey.the_fence.fixed", "journey.the_fence.open"]:
		assert_true(table.has(line_id), "%s is in data/strings/en.json" % line_id)
		assert_eq(Strings.t(line_id), str(table[line_id]))
		assert_false(Strings.t(line_id).begins_with("["), "resolved, not the missing-id marker")
	GameState.add_journey_line("journey.the_fence.open")
	assert_eq(
		Strings.t(GameState.journey_lines[0]), "Vasanti took the padlock off the garden gate."
	)
