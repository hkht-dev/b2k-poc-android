## Tests The Forgotten Song as data (GDD §7 "Main quest", §8 Scene C, §4
## Dhanpal, §6 "Remembering Krishna"): the quest loads with its steps, starts
## on hearing Tulu or meeting Dhanpal, is walked by the Compete, the Mediate
## and the Investigate flags in turn, mixes them without a path variable, and
## ends on either dawn choice with its own line in *Your journey*. Dhanpal at
## the hall offers Talk and his cards set the flags; the pause menu's one
## line is the current step's text.
extends GutTest

## tools/check_data.py MAX_WORDS. GDD §8 kept a line under twenty words;
## the owner lifted it to thirty-four after the expansion, because the
## shorthand had stopped making sense (docs/DECISIONS.md "Conversations").
const LINE_WORD_CAP := 35

const STREET := preload("res://scenes/street/Street.tscn")
const PAUSE_MENU := preload("res://scenes/ui/PauseMenu.tscn")
const PAUSE_MENU_SCRIPT := preload("res://scripts/ui/pause_menu.gd")
const GAME_STATE := preload("res://scripts/core/game_state.gd")
const QUEST_PATH := "res://data/quests/forgotten_song.json"
const DIALOGUE_PATH := "res://data/dialogue/en.json"
const SCRATCH := "user://test_forgotten_song_journey.json"

const STEP_IDS := [
	"hear_of_it",
	"the_tower_waits",
	"compete_key",
	"compete_shortcut",
	"mediate_second",
	"mediate_all",
	"investigate_lamp",
	"investigate_bar",
	"climb",
	"dawn",
]
## Every flag the task names; the quest must know each one.
const NAMED_FLAGS := [
	"met_dhanpal",
	"accepted_contest",
	"rukma_key_taken",
	"rukma_key_traded",
	"nanda_told_shortcut",
	"rukma_heard",
	"bhima_medicine_given",
	"sarang_string_given",
	"nanda_listened",
	"saw_shrine",
	"lamp_watered",
	"sarang_taught_bar",
	"on_the_tower",
	"played_for_others",
	"kept_veena",
]
## Where the player stands to talk to Dhanpal: on the hall's step beside him
## (tools/street_parts/dhanpal.py).
const BESIDE_DHANPAL := Vector3(46.0, 0.5, 21.7)

var _real_path := ""
var _state: Node
var _quest: Quest
var _dialogue: Dialogue


func before_each() -> void:
	_real_path = GameState.save_path
	GameState.save_path = SCRATCH
	GameState.set_autosave(false)
	GameState.wipe()
	_state = autofree(GAME_STATE.new())
	_state.set_autosave(false)
	_quest = _load_quest()
	_dialogue = Dialogue.from_dict(Strings.read_json_file(DIALOGUE_PATH), DIALOGUE_PATH)
	assert_not_null(_quest, "the quest parses")
	assert_not_null(_dialogue, "the dialogue table parses")
	_quest.attach(_state)
	_dialogue.attach(_state)


func after_each() -> void:
	get_tree().paused = false
	GameState.wipe()
	GameState.save_path = _real_path
	GameState.set_autosave(true)


func _load_quest() -> Quest:
	return Quest.from_dict(Strings.read_json_file(QUEST_PATH), QUEST_PATH)


## Sets [param flag] and asserts the quest is then waiting on [param step].
func _step_after(flag: String, step: String) -> void:
	_state.set_flag(flag)
	assert_eq(_quest.current_step_id(), step, "after %s" % flag)


func _street() -> Node3D:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	return street


func _button(street: Node3D) -> Button:
	return street.get_node("%TouchControls").contextual_button()


func _put(street: Node3D, where: Vector3) -> void:
	street.get_node("%Player").global_position = where
	await wait_frames(8)


func _press(street: Node3D) -> void:
	_button(street).pressed.emit()
	await wait_frames(2)


# -- the quest loads ------------------------------------------------------------


func test_the_quest_loads_with_its_steps_from_dhanpal() -> void:
	assert_eq(_quest.id, "forgotten_song")
	assert_eq(_quest.giver, "dhanpal")
	var ids: Array = []
	for step in _quest.steps:
		ids.append(step["id"])
	assert_eq(ids, STEP_IDS, "the steps, in order")
	assert_eq(_quest.branches.size(), 2, "one branch per dawn choice")
	assert_eq(_quest.status(), Quest.Status.INACTIVE, "nothing has happened yet")


func test_every_id_is_in_the_string_table_and_every_named_flag_is_known() -> void:
	for step in _quest.steps:
		assert_true(Strings.has_id(step["objective_text_id"]), "has %s" % step["objective_text_id"])
	for branch in _quest.branches:
		assert_true(Strings.has_id(branch["journey_line_id"]), "has %s" % branch["journey_line_id"])
	assert_true(Strings.has_id("speaker.dhanpal"))
	assert_true(Strings.has_id("sign.hall"))
	var known := Array(_quest.known_flags())
	for flag in NAMED_FLAGS:
		assert_true(known.has(flag), "knows '%s'" % flag)


# -- it starts ------------------------------------------------------------------


func test_it_starts_on_hearing_tulu() -> void:
	watch_signals(_quest)
	_state.set_flag("heard_tulu")
	assert_signal_emitted(_quest, "started")
	assert_eq(_quest.status(), Quest.Status.ACTIVE)
	assert_eq(_quest.current_step_id(), "hear_of_it")
	assert_eq(_quest.current_objective_text_id(), "quest.forgotten_song.hear_of_it")


func test_it_starts_on_meeting_dhanpal_too_and_then_waits_on_the_tower() -> void:
	_state.set_flag("met_dhanpal")
	assert_eq(_quest.status(), Quest.Status.ACTIVE)
	assert_eq(_quest.current_step_id(), "the_tower_waits")
	assert_eq(_quest.current_objective_text_id(), "quest.forgotten_song.the_tower_waits")


# -- the three approaches -------------------------------------------------------


func test_the_compete_flags_walk_it() -> void:
	_step_after("heard_tulu", "hear_of_it")
	_step_after("met_dhanpal", "the_tower_waits")
	_step_after("accepted_contest", "compete_key")
	_step_after("rukma_key_taken", "compete_shortcut")
	_step_after("nanda_told_shortcut", "climb")
	_step_after("on_the_tower", "dawn")
	_state.set_flag("played_for_others")
	assert_eq(_quest.status(), Quest.Status.ENDED)
	assert_eq(_quest.ended_branch(), "played")
	assert_eq(_state.journey_lines, ["journey.forgotten_song.played"])


func test_the_key_can_be_traded_instead_of_taken() -> void:
	_state.set_flag("met_dhanpal")
	_state.set_flag("accepted_contest")
	_step_after("rukma_key_traded", "compete_shortcut")


func test_the_mediate_flags_walk_it() -> void:
	_step_after("heard_tulu", "hear_of_it")
	_step_after("met_dhanpal", "the_tower_waits")
	# Two competitors talked to before accepting (GDD §7): no accepted_contest.
	_step_after("rukma_heard", "mediate_second")
	_step_after("bhima_medicine_given", "mediate_all")
	_step_after("sarang_string_given", "mediate_all")
	_step_after("nanda_listened", "climb")
	assert_false(_state.has_flag("accepted_contest"), "they never accepted")
	_step_after("on_the_tower", "dawn")
	_state.set_flag("kept_veena")
	assert_eq(_quest.status(), Quest.Status.ENDED)
	assert_eq(_quest.ended_branch(), "kept")
	assert_eq(_state.journey_lines, ["journey.forgotten_song.kept"])


func test_the_investigate_flags_walk_it() -> void:
	_step_after("heard_tulu", "hear_of_it")
	# Following Tulu to the shrine needs no word from Dhanpal.
	_step_after("saw_shrine", "investigate_lamp")
	_step_after("lamp_watered", "investigate_bar")
	_step_after("sarang_taught_bar", "climb")
	assert_false(_state.has_flag("met_dhanpal"), "Dhanpal was never met")
	_step_after("on_the_tower", "dawn")
	_state.set_flag("played_for_others")
	assert_eq(_quest.status(), Quest.Status.ENDED)
	assert_eq(_quest.ended_branch(), "played")


func test_the_approaches_mix_through_flags_not_a_path_variable() -> void:
	# Started competing: accepted, took the key...
	_state.set_flag("met_dhanpal")
	_state.set_flag("accepted_contest")
	_step_after("rukma_key_taken", "compete_shortcut")
	# ...then helped Bhima Lal: the compete steps give way to the mediate ones.
	_step_after("bhima_medicine_given", "mediate_second")
	_step_after("rukma_heard", "mediate_all")
	# ...then looked into the shrine: the investigate thread leads from here.
	_step_after("saw_shrine", "investigate_lamp")
	# The climb clears every preparation, whatever was left undone.
	_step_after("on_the_tower", "dawn")
	assert_eq(_quest.status(), Quest.Status.ACTIVE, "the dawn choice is still to come")


func test_a_loaded_journey_lands_on_the_same_step() -> void:
	_state.set_flag("heard_tulu")
	_state.set_flag("met_dhanpal")
	_state.set_flag("accepted_contest")
	_state.set_flag("rukma_key_taken")
	_state.set_flag("rukma_heard")
	var again := _load_quest()
	again.attach(_state)
	assert_eq(again.current_step_id(), _quest.current_step_id())
	assert_eq(again.current_step_id(), "mediate_second", "derived from flags, not stored")


# -- the dawn --------------------------------------------------------------------


func test_the_end_flags_set_the_journey_line_and_nothing_is_set_twice() -> void:
	watch_signals(_quest)
	_state.set_flag("heard_tulu")
	_state.set_flag("on_the_tower")
	assert_eq(_quest.current_step_id(), "dawn")
	_state.set_flag("kept_veena")
	assert_signal_emitted_with_parameters(_quest, "ended", ["kept"])
	assert_eq(_state.journey_lines, ["journey.forgotten_song.kept"])
	_state.set_flag("played_for_others")
	assert_eq(_state.journey_lines, ["journey.forgotten_song.kept"], "the quest ended once")
	assert_eq(_quest.ended_branch(), "kept")


func test_the_dawn_choice_ends_the_quest_from_any_step() -> void:
	_state.set_flag("met_dhanpal")
	_state.set_flag("played_for_others")
	assert_eq(_quest.status(), Quest.Status.ENDED)
	assert_eq(_quest.ended_branch(), "played")
	assert_eq(_state.journey_lines, ["journey.forgotten_song.played"])


func test_play_again_resets_it() -> void:
	_state.set_flag("heard_tulu")
	_state.set_flag("on_the_tower")
	_state.set_flag("kept_veena")
	assert_eq(_quest.status(), Quest.Status.ENDED)
	_state.wipe()
	assert_eq(_quest.status(), Quest.Status.INACTIVE, "a wiped journey has not heard of the tower")


# -- Dhanpal ---------------------------------------------------------------------


func test_dhanpal_offers_talk_at_the_hall_and_accept_sets_accepted_contest() -> void:
	var street := _street()
	await _put(street, BESIDE_DHANPAL)
	assert_eq(_button(street).current_verb(), "verb.talk", "the hall's step offers Talk")
	var dhanpal: Node3D = street.get_node("%Dhanpal")
	assert_true(dhanpal.is_facing_player(), "he turns to whoever comes to the hall")
	assert_ne(dhanpal.rotation.y, 0.0)
	await _press(street)
	var dialogue: Dialogue = Content.dialogue
	assert_eq(dialogue.current_line_id(), "dhanpal_greet")
	assert_true(GameState.has_flag("met_dhanpal"), "his first line's `sets` landed")
	assert_true(street.cards().visible, "Scene C is on screen")
	assert_eq(street.cards().card_count(), 3, "Accept, who else, not today")
	assert_eq(Content.quest("forgotten_song").current_step_id(), "the_tower_waits")
	dialogue.choose(0)  # Count me in.
	assert_true(GameState.has_flag("accepted_contest"))
	assert_eq(dialogue.current_line_id(), "dhanpal_accepted")
	assert_eq(Content.quest("forgotten_song").current_step_id(), "compete_key")
	dialogue.dismiss()
	await _press(street)
	assert_eq(dialogue.current_line_id(), "dhanpal_later", "once accepted, the later line")


func test_who_else_and_not_today_leave_the_contest_unaccepted() -> void:
	_state.set_flag("heard_tulu")
	assert_true(_dialogue.start("dhanpal_greet"))
	assert_true(_state.has_flag("met_dhanpal"))
	_dialogue.choose(1)  # What's a Veena?
	assert_eq(_dialogue.current_line_id(), "dhanpal_what_veena")
	_dialogue.choose(1)  # Who else is climbing?
	assert_eq(_dialogue.current_line_id(), "dhanpal_who_else")
	_dialogue.choose(0)  # Why does the name matter?
	assert_eq(_dialogue.current_line_id(), "dhanpal_why_name")
	_dialogue.choose(1)  # Not today.
	assert_eq(_dialogue.current_line_id(), "dhanpal_not_today")
	assert_false(_state.has_flag("accepted_contest"))
	assert_eq(_quest.current_step_id(), "the_tower_waits", "the offer stands; nothing chosen")
	_dialogue.dismiss()
	assert_true(_dialogue.start("dhanpal_greet"), "he will say it all again")


func test_dhanpal_has_a_line_for_each_dawn() -> void:
	assert_false(_dialogue.start("dhanpal_after_played"), "not before the dawn")
	assert_false(_dialogue.start("dhanpal_after_kept"))
	_state.set_flag("played_for_others")
	assert_true(_dialogue.start("dhanpal_after_played"))
	assert_eq(_dialogue.get_line("dhanpal_after_played")["speaker"], "dhanpal")
	_dialogue.dismiss()
	assert_false(_dialogue.start("dhanpal_after_kept"), "the other dawn did not happen")
	_state.set_flag("kept_veena")
	assert_true(_dialogue.start("dhanpal_after_kept"))


func test_dhanpal_cards_carry_no_cue_and_lines_stay_short() -> void:
	for line_id in _dialogue.line_ids():
		var line := _dialogue.get_line(line_id)
		if line["speaker"] != "dhanpal":
			continue
		assert_lt(
			Strings.t(line["text_id"]).split(" ").size(),
			LINE_WORD_CAP,
			"%s is inside the cap" % line_id
		)
		var cards: Array = line["cards"]
		assert_true(cards.size() == 0 or cards.size() >= 2, "%s: two or three cards" % line_id)
		for card in cards:
			var text: String = Strings.t(card["text_id"])
			assert_false(text.begins_with("["), "no missing card text on %s" % line_id)
			assert_false(text.contains("✓") or text.contains("*"), "no cue on a card")


# -- the pause menu's one line -------------------------------------------------


func test_the_pause_menu_shows_the_current_objective() -> void:
	# The Dry Fountain starts at once and sorts first; it stays active here,
	# so the line is the main quest's only because "main" wins (quest.gd).
	GameState.set_flag("heard_tulu")
	assert_eq(Content.quest("dry_fountain").status(), Quest.Status.ACTIVE, "a side quest competes")
	assert_eq(PAUSE_MENU_SCRIPT.now_line(), Strings.t("quest.forgotten_song.hear_of_it"))
	GameState.set_flag("met_dhanpal")
	assert_eq(PAUSE_MENU_SCRIPT.now_line(), Strings.t("quest.forgotten_song.the_tower_waits"))
	GameState.set_flag("accepted_contest")
	var menu: Control = add_child_autofree(PAUSE_MENU.instantiate())
	await wait_frames(1)
	assert_eq(
		menu.get_node("%Now").text,
		"Rukma keeps the roof key in her bag. She sleeps at the bus stop."
	)
	assert_eq(menu.get_node("%Now").text, Strings.t("quest.forgotten_song.compete_key"))
