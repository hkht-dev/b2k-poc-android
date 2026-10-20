## Tests the optional wisdom cards (GDD §6 "Optional wisdom", §9 "Wisdom
## encounters", §11): the data loads with every string; a trigger flag
## pulses the lotus for eight seconds and nothing else; tapping opens the
## card with the right verse; Read more unfolds the note; a card is offered
## once per journey, the record survives save and load, and a wipe resets it.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const GAME_STATE := preload("res://scripts/core/game_state.gd")
const SCRATCH := "user://test_wisdom_journey.json"
## The slice's give and take choices offer the cards on Bg 3.9 and Bg
## 2.62-63 (GDD §9 rows 4 and 3). The ids and flags are data/wisdom.json's.
const GIVE_FLAG := "gave_dry_fountain"
const GIVE_CARD := "give"
const TAKE_FLAG := "took_dry_fountain"
const TAKE_CARD := "take"
## A spot on the south pavement with nothing usable in reach.
const EMPTY_SPOT := Vector3(0.0, 0.05, 30.0)

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


func _lotus(street: Node3D) -> Control:
	return street.get_node("%TouchControls").lotus()


## A finger on the lotus, as the GUI delivers it.
func _tap(lotus: Control) -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = lotus.get_global_rect().get_center()
	lotus._gui_input(touch)


func test_the_cards_load_with_every_string_and_a_well_formed_trigger() -> void:
	var ids := Wisdom.ids()
	assert_eq(ids.size(), 7, "GDD §9 lists seven cards")
	assert_eq(
		Array(ids),
		["whisper", "arrival", "take", "give", "shrine_water", "melody", "embrace"],
		"in the GDD's order"
	)
	for id in ids:
		var card := Wisdom.card(id)
		assert_true(Condition.is_well_formed(card["trigger"]), "%s: the trigger parses" % id)
		for string_id in Wisdom.string_ids(id):
			assert_true(Strings.has_id(string_id), "the string '%s' exists" % string_id)
		var meaning: String = Strings.t(card["meaning_id"])
		var sentences := meaning.count(".") + meaning.count("!") + meaning.count("?")
		assert_lte(sentences, 2, "%s: the meaning is two sentences (GDD §9)" % id)
		var words := Strings.t(card["more_id"]).replace("\n", " ").split(" ", false).size()
		assert_between(words, 200, 300, "%s: Read more is 200-300 words (GDD §9)" % id)
		for field in ["verse_id", "meaning_id", "more_id"]:
			assert_false(
				Strings.t(card[field]).to_lower().contains("you chose"),
				"%s: a card comments on the situation, never on the choice (GDD §9)" % id
			)
		assert_true(
			Strings.t(card["source_id"]).begins_with(card["reference"]),
			"%s: the source line names the verse" % id
		)
	assert_eq(Wisdom.cards_for_flag(GIVE_FLAG), PackedStringArray([GIVE_CARD]))
	assert_eq(Wisdom.cards_for_flag(TAKE_FLAG), PackedStringArray([TAKE_CARD]))
	assert_true(Wisdom.cards_for_flag("carrying_can").is_empty(), "a flag no card names")
	assert_true(Wisdom.known_flags().has("heard_tulu"), "the debug panel can list the flags")
	assert_true(Wisdom.card("no_such_card").is_empty())
	assert_false(Wisdom.is_triggered("no_such_card", GameState.flags, GameState.events))


func test_setting_a_trigger_flag_pulses_the_lotus_and_records_the_offer() -> void:
	var street := _street()
	var lotus := _lotus(street)
	await wait_frames(2)
	assert_false(lotus.visible, "the HUD is empty by default (GDD §11)")
	GameState.set_flag(GIVE_FLAG)
	await wait_frames(2)
	assert_true(lotus.is_showing(), "the lotus pulses")
	assert_eq(lotus.card_id(), GIVE_CARD)
	assert_eq(lotus.SHOW_SECONDS, 8.0, "offered for eight seconds (GDD §6)")
	assert_gt(lotus.seconds_left(), 7.0)
	assert_lte(lotus.PULSE_HZ, 3.0, "never faster than the 3 Hz flashing limit (GDD §11)")
	assert_true(GameState.has_seen_wisdom(GIVE_CARD), "the offer is on the journey")
	assert_null(street.wisdom_card(), "the lotus alone opens nothing")
	assert_false(get_tree().paused, "and stops nothing")
	assert_false(street.is_paused())


func test_a_flag_no_card_names_offers_nothing() -> void:
	var street := _street()
	GameState.set_flag("hummed")
	await wait_frames(2)
	assert_false(_lotus(street).is_showing())
	assert_true(GameState.wisdom_seen.is_empty())


func test_untouched_the_lotus_fades_after_eight_seconds_and_nothing_changes() -> void:
	var street := _street()
	var lotus := _lotus(street)
	watch_signals(lotus)
	GameState.set_flag(TAKE_FLAG)
	await wait_frames(4)
	assert_true(lotus.is_showing())
	var flags_before := GameState.flags.all()
	var events_before := GameState.events.all()
	var lines_before := GameState.journey_lines.duplicate()
	await wait_seconds(lotus.SHOW_SECONDS + lotus.FADE_SECONDS + 0.4)
	assert_false(lotus.is_showing(), "gone")
	assert_false(lotus.visible)
	assert_signal_emitted_with_parameters(lotus, "faded", [TAKE_CARD])
	assert_signal_not_emitted(lotus, "opened")
	assert_null(street.wisdom_card(), "no card opened on its own")
	assert_eq(GameState.flags.all(), flags_before, "no flag changed")
	assert_eq(GameState.events.all(), events_before, "no event fired")
	assert_eq(GameState.journey_lines, lines_before, "nothing recorded")
	assert_false(get_tree().paused)
	assert_eq(GameState.wisdom_seen, [TAKE_CARD], "ignoring it still counts as offered")


func test_tapping_the_lotus_opens_the_card_with_the_right_verse_and_pauses() -> void:
	var street := _street()
	var lotus := _lotus(street)
	watch_signals(lotus)
	GameState.set_flag(GIVE_FLAG)
	await wait_frames(2)
	_tap(lotus)
	assert_signal_emitted_with_parameters(lotus, "opened", [GIVE_CARD])
	assert_false(lotus.visible, "the lotus is gone once tapped")
	var card: Control = street.wisdom_card()
	assert_not_null(card, "the card opened")
	if card == null:
		return
	assert_true(get_tree().paused, "the game pauses while a card is open (GDD §9)")
	assert_true(street.is_paused())
	assert_eq(card.process_mode, Node.PROCESS_MODE_ALWAYS, "and the card still works")
	assert_eq(card.card_id(), GIVE_CARD)
	assert_eq(card.verse_text(), Strings.t("wisdom.give.verse"))
	assert_eq(card.source_text(), Strings.t("wisdom.give.source"))
	assert_eq(card.meaning_text(), Strings.t("wisdom.give.meaning"))
	assert_true(card.source_text().begins_with("Bhagavad-gita 3.9"))
	var verse: Label = card.get_node("%Verse")
	assert_eq(verse.get_theme_font("font").resource_path, "res://assets/ui/font_heading.tres")
	assert_false(card.is_expanded(), "the note waits behind Read more")
	assert_true(card.get_node("%ReadMoreButton").has_focus(), "keys and gamepad land on it")
	street.hum()
	assert_eq(GameState.hum_count, 0, "nothing in the world answers while a card is open")
	# No awaits while the tree is paused: close synchronously.
	card.get_node("%CloseButton").pressed.emit()
	assert_null(street.wisdom_card())
	assert_false(get_tree().paused, "closing resumes")
	await wait_frames(1)


func test_read_more_unfolds_the_note_and_close_resumes() -> void:
	var street := _street()
	GameState.set_flag(GIVE_FLAG)
	await wait_frames(2)
	assert_true(_lotus(street).open())
	var card: Control = street.wisdom_card()
	assert_not_null(card)
	if card == null:
		return
	watch_signals(card)
	card.get_node("%ReadMoreButton").pressed.emit()
	assert_true(card.is_expanded())
	assert_signal_emitted(card, "expanded")
	assert_eq(card.more_text(), Strings.t("wisdom.give.more"))
	assert_true(card.get_node("%More").visible, "the note scrolls in place")
	assert_false(card.get_node("%ReadMoreButton").visible)
	assert_true(card.get_node("%CloseButton").has_focus())
	card.get_node("%CloseButton").pressed.emit()
	assert_signal_emitted(card, "closed")
	assert_null(street.wisdom_card())
	assert_false(get_tree().paused)
	await wait_frames(1)


func test_the_contextual_action_opens_the_card_when_nothing_usable_is_near() -> void:
	var street := _street()
	street.get_node("%Player").global_position = EMPTY_SPOT
	GameState.set_flag(GIVE_FLAG)
	await wait_frames(8)
	assert_null(street.near(), "nothing usable where the player stands")
	assert_true(_lotus(street).is_showing())
	var press := InputEventAction.new()
	press.action = "contextual"
	press.pressed = true
	street._unhandled_input(press)
	assert_not_null(street.wisdom_card(), "E or A opens the offered card")
	assert_true(get_tree().paused)
	assert_false(_lotus(street).is_showing())
	street.wisdom_card().close()
	assert_null(street.wisdom_card())
	await wait_frames(1)


func test_a_card_is_offered_once_per_journey_and_the_record_survives_save_and_load() -> void:
	var street := _street()
	var lotus := _lotus(street)
	GameState.set_flag(GIVE_FLAG)
	await wait_frames(2)
	assert_true(lotus.is_showing())
	lotus.dismiss()
	assert_false(lotus.is_showing())
	GameState.clear_flag(GIVE_FLAG)
	GameState.set_flag(GIVE_FLAG)
	await wait_frames(2)
	assert_false(lotus.is_showing(), "the same beat never offers the card again")
	assert_eq(GameState.wisdom_seen, [GIVE_CARD])
	GameState.save()
	var loaded: Node = GAME_STATE.new()
	loaded.save_path = SCRATCH
	loaded.set_autosave(false)
	assert_true(loaded.load_journey(), "the slot was there")
	assert_true(loaded.has_seen_wisdom(GIVE_CARD), "and remembers the offer")
	assert_eq(loaded.to_dict()["wisdom_seen"], [GIVE_CARD])
	loaded.free()


func test_loading_a_journey_offers_nothing_for_what_already_was() -> void:
	var street := _street()
	var lotus := _lotus(street)
	await wait_frames(2)
	GameState.from_dict({"version": 1, "flags": [GIVE_FLAG, "glimpsed_traffic_light"]})
	await wait_frames(2)
	assert_true(GameState.has_flag(GIVE_FLAG))
	assert_false(lotus.is_showing(), "the moment has passed; loading announces nothing")
	assert_true(GameState.wisdom_seen.is_empty())


func test_wiping_the_journey_lets_the_card_be_offered_again() -> void:
	var street := _street()
	var lotus := _lotus(street)
	GameState.set_flag(GIVE_FLAG)
	await wait_frames(2)
	lotus.dismiss()
	GameState.wipe()
	assert_true(GameState.wisdom_seen.is_empty(), "Play again forgets what was offered")
	GameState.set_flag(GIVE_FLAG)
	await wait_frames(2)
	assert_true(lotus.is_showing(), "a new journey meets the card afresh")


func test_the_lotus_is_drawn_not_loaded_and_in_no_forbidden_colour() -> void:
	var street := _street()
	var lotus := _lotus(street)
	assert_eq(lotus.get_child_count(), 0, "drawn with _draw: no texture, no child node")
	assert_eq(lotus.get_parent(), street.get_node("%TouchControls"), "it is part of the HUD")
	assert_eq(lotus.tooltip_text, Strings.t("wisdom.lotus"), "labelled for a screen reader")
	for colour: Color in lotus.colours():
		var saturated := colour.s > 0.25
		assert_false(saturated and colour.h > 0.5 and colour.h < 0.72, "no peacock blue (GDD §10)")
		assert_false(saturated and colour.h > 0.78 and colour.h < 0.97, "no magenta (GDD §10)")
