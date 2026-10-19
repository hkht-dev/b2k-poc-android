## Tests the quest machine and the dialogue runner against the real data.
##
## P2's gate (CLAUDE_CODE_BRIEF.md §3): "A quest defined only in JSON can be
## stepped through with cards and sets flags." These tests step The Dry
## Fountain through every outcome from data alone.
extends GutTest

const GAME_STATE := preload("res://scripts/core/game_state.gd")
const QUEST_PATH := "res://data/quests/dry_fountain.json"
const DIALOGUE_PATH := "res://data/dialogue/en.json"

var _state: Node
var _quest: Quest
var _dialogue: Dialogue


func before_each() -> void:
	_state = autofree(GAME_STATE.new())
	_state.set_autosave(false)
	_quest = Quest.from_dict(Strings.read_json_file(QUEST_PATH), QUEST_PATH)
	_dialogue = Dialogue.from_dict(Strings.read_json_file(DIALOGUE_PATH), DIALOGUE_PATH)
	assert_not_null(_quest, "the dry fountain quest parses")
	assert_not_null(_dialogue, "the dialogue table parses")
	_quest.attach(_state)
	_dialogue.attach(_state)


# -- quest --------------------------------------------------------------------


func test_the_quest_starts_at_once_and_waits_on_the_fountain() -> void:
	assert_eq(_quest.status(), Quest.Status.ACTIVE, "start_condition is true")
	assert_eq(_quest.current_step_id(), "notice")
	assert_eq(_quest.waiting_on(), "flag:looked_dry_fountain")


func test_looking_at_the_fountain_advances_to_hearing_gopal_out() -> void:
	watch_signals(_quest)
	_state.set_flag("looked_dry_fountain")
	assert_signal_emitted_with_parameters(_quest, "step_completed", ["notice"])
	assert_eq(_quest.current_step_id(), "hear_him_out")


func test_the_give_path_ends_with_the_fountain_full() -> void:
	watch_signals(_quest)
	_state.set_flag("looked_dry_fountain")
	_state.set_flag("gopal_admitted_fear")
	_state.set_flag("gopal_will_carry")
	assert_eq(_quest.current_step_id(), "carry", "two steps done, waiting to carry")
	_state.fire_event("can_placed_at_fountain")
	assert_true(_state.has_flag("gave_dry_fountain"), "the carry step set the flag")
	assert_eq(_quest.status(), Quest.Status.ENDED)
	assert_eq(_quest.ended_branch(), "give")
	assert_signal_emitted_with_parameters(_quest, "ended", ["give"])
	assert_eq(_state.journey_lines, ["journey.dry_fountain.gave"])


func test_talking_to_gopal_before_looking_still_counts_once_you_look() -> void:
	# Steps are sequential, but the flags are not: a player who hears Gopal out
	# first and only then looks at the fountain clears both steps on the look.
	_state.set_flag("gopal_admitted_fear")
	assert_eq(_quest.current_step_id(), "notice", "still waiting on the look")
	_state.set_flag("looked_dry_fountain")
	assert_eq(_quest.current_step_id(), "carry", "both steps cleared in one go")


func test_the_take_path_ends_the_quest_from_any_step() -> void:
	_state.fire_event("can_taken_from_shop")
	assert_eq(_quest.status(), Quest.Status.ENDED)
	assert_eq(_quest.ended_branch(), "take")
	assert_true(_state.has_flag("took_dry_fountain"))
	assert_eq(_state.journey_lines, ["journey.dry_fountain.took"])


func test_taking_a_can_after_gopal_agreed_is_not_the_take_branch() -> void:
	_state.set_flag("gopal_will_carry")
	_state.fire_event("can_taken_from_shop")
	assert_eq(_quest.status(), Quest.Status.ACTIVE, "he said carry one; picking it up is not theft")
	assert_false(_state.has_flag("took_dry_fountain"))


func test_ignoring_the_fountain_never_ends_the_quest() -> void:
	assert_eq(_quest.status(), Quest.Status.ACTIVE)
	assert_eq(_quest.ended_branch(), "")
	assert_eq(_state.journey_lines.size(), 0, "nothing happened, nothing is written")


func test_a_loaded_journey_lands_on_the_same_step() -> void:
	_state.set_flag("looked_dry_fountain")
	_state.set_flag("gopal_admitted_fear")
	var again := Quest.from_dict(Strings.read_json_file(QUEST_PATH), QUEST_PATH)
	again.attach(_state)
	assert_eq(again.current_step_id(), "carry", "progress is derived from flags, not stored")


func test_play_again_resets_the_quest_to_the_start() -> void:
	_state.fire_event("can_taken_from_shop")
	assert_eq(_quest.status(), Quest.Status.ENDED)
	_state.wipe()
	assert_eq(_quest.status(), Quest.Status.ACTIVE, "a wiped journey restarts the quest")
	assert_eq(_quest.current_step_id(), "notice")


func test_a_quest_with_a_bad_condition_is_refused_at_load() -> void:
	var data: Dictionary = Strings.read_json_file(QUEST_PATH)
	data["steps"][0]["complete_when"] = "looked_dry_fountain"
	assert_null(Quest.from_dict(data, "broken"), "a bare name has no namespace")


func test_the_quest_knows_every_flag_and_event_it_touches() -> void:
	var flags := Array(_quest.known_flags())
	for name in [
		"looked_dry_fountain",
		"gopal_admitted_fear",
		"gave_dry_fountain",
		"took_dry_fountain",
		"gopal_will_carry"
	]:
		assert_true(flags.has(name), "knows '%s'" % name)
	var events := Array(_quest.known_events())
	assert_true(events.has("can_placed_at_fountain"))
	assert_true(events.has("can_taken_from_shop"))


# -- dialogue -----------------------------------------------------------------


func test_every_line_has_a_review_status_and_resolvable_text() -> void:
	for line_id in _dialogue.line_ids():
		var line := _dialogue.get_line(line_id)
		assert_true(Dialogue.REVIEW_STATUSES.has(line["review_status"]), "%s is reviewed" % line_id)
		assert_true(Strings.has_id(line["text_id"]), "%s has text" % line_id)
		for card in line["cards"]:
			assert_true(Strings.has_id(card["text_id"]), "%s card has text" % line_id)


func test_cards_are_two_or_three_or_none() -> void:
	for line_id in _dialogue.line_ids():
		var count: int = _dialogue.get_line(line_id)["cards"].size()
		assert_true(count == 0 or count == 2 or count == 3, "%s offers %d cards" % [line_id, count])


func test_the_fountain_line_leaves_its_mark_with_no_cards() -> void:
	watch_signals(_dialogue)
	assert_true(_dialogue.start("fountain_look"))
	assert_true(_state.has_flag("looked_dry_fountain"), "looking is enough")
	assert_eq(_dialogue.get_line("fountain_look")["cards"].size(), 0)
	_dialogue.dismiss()
	assert_signal_emitted(_dialogue, "finished")


func test_talking_gopal_through_to_carrying_sets_the_flags_the_quest_needs() -> void:
	_dialogue.start("fountain_look")
	_dialogue.dismiss()
	assert_true(_dialogue.start("gopal_greet"))
	_dialogue.choose(0)
	assert_eq(_dialogue.current_line_id(), "gopal_fear_1")
	_dialogue.choose(0)
	assert_eq(_dialogue.current_line_id(), "gopal_fear_2")
	_dialogue.choose(1)
	assert_eq(_dialogue.current_line_id(), "gopal_admit")
	_dialogue.choose(0)
	assert_true(_state.has_flag("gopal_admitted_fear"))
	assert_true(_state.has_flag("gopal_will_carry"))
	assert_eq(_dialogue.current_line_id(), "gopal_agree")
	assert_eq(_state.choice_history.size(), 4, "every card is on the record")
	assert_eq(_quest.current_step_id(), "carry", "and the quest moved on by itself")


func test_leaving_early_sets_nothing() -> void:
	watch_signals(_dialogue)
	_dialogue.start("gopal_greet")
	_dialogue.choose(1)
	assert_signal_emitted(_dialogue, "finished")
	assert_eq(_state.flags.size(), 0)


func test_lines_that_require_a_flag_wait_for_it() -> void:
	assert_false(_dialogue.start("gopal_hurt"), "not until a can was taken")
	_state.set_flag("took_dry_fountain")
	assert_true(_dialogue.start("gopal_hurt"))


func test_a_card_pointing_at_a_missing_line_is_refused_at_load() -> void:
	var data: Dictionary = Strings.read_json_file(DIALOGUE_PATH)
	data["gopal_greet"]["cards"][0]["next"] = "no_such_line"
	assert_null(Dialogue.from_dict(data, "broken"))


func test_four_cards_are_refused_at_load() -> void:
	var data: Dictionary = Strings.read_json_file(DIALOGUE_PATH)
	var cards: Array = data["gopal_greet"]["cards"]
	cards.append(cards[0].duplicate())
	cards.append(cards[0].duplicate())
	assert_null(Dialogue.from_dict(data, "broken"), "GDD §6: two or three options")
