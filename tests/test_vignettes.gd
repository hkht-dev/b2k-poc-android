## Tests the dawn vignettes (GDD §16a): the pool loads from data with every
## string present, the day's pick is the calendar's and stable, missed days
## queue oldest first, a spot stands a stranger with Talk, a card finishes a
## vignette with its flag and journey line, and the queue survives save/load.
extends GutTest

const SPOT := preload("res://scenes/quest/VignetteSpot.tscn")
const GAME_STATE := preload("res://scripts/core/game_state.gd")
const SCRATCH := "user://test_vignettes_journey.json"
## GDD §8 "Writing rules": lines under 20 words.
const MAX_WORDS := 19
const A_DATE := "2026-10-20"
const NEXT_DATE := "2026-10-21"
const LATER_DATE := "2026-10-23"

var _real_path := ""


func before_each() -> void:
	_real_path = GameState.save_path
	GameState.save_path = SCRATCH
	GameState.set_autosave(false)
	GameState.wipe()
	Vignettes.reload()


func after_each() -> void:
	GameState.wipe()
	GameState.save_path = _real_path
	GameState.set_autosave(true)


func _spot(letter: String) -> Node3D:
	var spot: Node3D = SPOT.instantiate()
	spot.spot = letter
	add_child_autofree(spot)
	return spot


## A card index on the entry line that sets one of the vignette's outcomes.
func _outcome_card(vignette: Dictionary) -> int:
	var entry: Dictionary = vignette["lines"][Vignettes.entry_line_id(vignette)]
	for index in entry["cards"].size():
		if not entry["cards"][index]["sets"].is_empty():
			return index
	return -1


# -- the pool -----------------------------------------------------------------


func test_ten_vignettes_load_and_every_string_exists() -> void:
	assert_eq(Vignettes.size(), 10, "the slice ships ten")
	for vignette in Vignettes.all():
		var id: String = vignette["id"]
		assert_true(Strings.has_id(vignette["giver_name_id"]), "%s has a name" % id)
		assert_true(Strings.has_id(vignette["journey_line_id"]), "%s has a journey line" % id)
		assert_true(Vignettes.SPOTS.has(vignette["spot"]), "%s stands at a, b or c" % id)
		assert_gt(vignette["outcomes"].size(), 0, "%s has outcomes" % id)
		var set_somewhere := PackedStringArray()
		for line_id in vignette["lines"]:
			assert_true(line_id.begins_with("vignette_%s_" % id), "%s is namespaced" % line_id)
			var line: Dictionary = vignette["lines"][line_id]
			assert_true(Strings.has_id(line["text_id"]), "%s has text" % line_id)
			assert_true(Strings.has_id("speaker." + line["speaker"]), "%s has a speaker" % line_id)
			assert_lte(Strings.t(line["text_id"]).split(" ").size(), MAX_WORDS, line_id)
			var count: int = line["cards"].size()
			assert_true(
				count == 0 or count == 2 or count == 3, "%s offers %d cards" % [line_id, count]
			)
			for card in line["cards"]:
				assert_true(Strings.has_id(card["text_id"]), "%s card has text" % line_id)
				assert_lte(Strings.t(card["text_id"]).split(" ").size(), MAX_WORDS, card["text_id"])
				set_somewhere.append_array(card["sets"])
		for flag in vignette["outcomes"]:
			assert_true(flag.begins_with("vignette_%s_" % id), "%s is namespaced" % flag)
			assert_true(set_somewhere.has(flag), "some card sets %s" % flag)


func test_the_pool_parses_as_dialogue_and_does_not_collide_with_the_table() -> void:
	var base: Dictionary = Strings.read_json_file("res://data/dialogue/en.json")
	for vignette in Vignettes.all():
		var table := Dialogue.from_dict(vignette["lines"], vignette["id"])
		assert_not_null(table, "%s lines parse" % vignette["id"])
		for line_id in vignette["lines"]:
			assert_false(base.has(line_id), "%s is not already a dialogue line" % line_id)


# -- the calendar -------------------------------------------------------------


func test_todays_pick_is_stable_for_a_date_and_walks_the_pool() -> void:
	var first := Vignettes.id_for_date(A_DATE)
	assert_eq(Vignettes.id_for_date(A_DATE), first, "the same date, the same vignette")
	assert_true(Vignettes.has(first), "and it is in the pool")
	assert_ne(Vignettes.id_for_date(NEXT_DATE), first, "the next day is a new one")
	assert_eq(
		Vignettes.id_for_date(Vignettes.date_of_day(Vignettes.day_number(A_DATE) + 10)),
		first,
		"ten days on, the pool has come round"
	)
	assert_eq(Vignettes.today_id(), Vignettes.id_for_date(Time.get_date_string_from_system()))
	assert_eq(Vignettes.date_of_day(Vignettes.day_number(A_DATE)), A_DATE)


func test_the_first_grant_is_today_only() -> void:
	var added := Vignettes.grant_today(GameState, A_DATE)
	assert_eq(Array(added), [A_DATE])
	assert_eq(Array(GameState.vignette_days), [A_DATE])
	assert_eq(Vignettes.grant_today(GameState, A_DATE).size(), 0, "granted once")
	var pending := Vignettes.pending()
	assert_eq(pending.size(), 1)
	assert_eq(pending[0]["id"], Vignettes.id_for_date(A_DATE))


func test_a_missed_date_queues_oldest_first() -> void:
	Vignettes.grant_today(GameState, A_DATE)
	var added := Vignettes.grant_today(GameState, LATER_DATE)
	assert_eq(Array(added), ["2026-10-21", "2026-10-22", LATER_DATE], "the missed days too")
	var pending := Vignettes.pending()
	assert_eq(pending.size(), 4)
	assert_eq(pending[0]["id"], Vignettes.id_for_date(A_DATE), "the oldest first")
	assert_eq(pending[3]["id"], Vignettes.id_for_date(LATER_DATE))


func test_a_long_absence_queues_no_more_than_the_pool() -> void:
	Vignettes.grant_today(GameState, A_DATE)
	var far := Vignettes.date_of_day(Vignettes.day_number(A_DATE) + 400)
	Vignettes.grant_today(GameState, far)
	assert_lte(GameState.vignette_days.size(), Vignettes.size() + 1)
	assert_eq(Vignettes.pending().size(), Vignettes.size(), "every vignette waits, each once")


func test_the_done_flag_removes_it_from_pending() -> void:
	Vignettes.grant_today(GameState, A_DATE)
	var id := Vignettes.id_for_date(A_DATE)
	GameState.set_flag(Vignettes.done_flag(id))
	assert_eq(Vignettes.pending().size(), 0)
	assert_true(Vignettes.pending_for_spot(Vignettes.get_vignette(id)["spot"]).is_empty())


# -- the spot -----------------------------------------------------------------


func test_a_spot_stands_a_stranger_with_talk() -> void:
	Vignettes.grant_today(GameState, A_DATE)
	var wanted: Dictionary = Vignettes.pending()[0]
	var spot := _spot(wanted["spot"])
	await wait_frames(1)
	assert_eq(spot.vignette_id(), wanted["id"], "the oldest pending vignette for its letter")
	assert_true(spot.has_stranger())
	var figure: CharacterRig = spot.figure()
	assert_not_null(figure)
	assert_eq(figure.skin, spot.SKINS[wanted["skin"]], "wearing the vignette's skin")
	var talk: Interactable = spot.get_node("%Talk")
	assert_true(talk.is_available(), "Talk is offered")
	assert_eq(talk.verb_id, "verb.talk")
	assert_true(Content.dialogue.has_line(Vignettes.entry_line_id(wanted)), "lines were added")


func test_an_empty_spot_stands_nobody() -> void:
	# Granting happens at ready, so today's vignette is pending; a spot with
	# another letter stands empty.
	var today := Vignettes.get_vignette(Vignettes.today_id())
	var other := "b" if today["spot"] == "a" else "a"
	var spot := _spot(other)
	await wait_frames(1)
	assert_true(spot.vignette().is_empty())
	assert_false(spot.has_stranger())
	assert_false(spot.get_node("%Talk").is_available())


func test_talking_opens_the_first_line_and_a_card_sets_its_flag_and_the_journey_line() -> void:
	Vignettes.grant_today(GameState, A_DATE)
	var wanted: Dictionary = Vignettes.pending()[0]
	var spot := _spot(wanted["spot"])
	watch_signals(spot)
	await wait_frames(1)
	spot.get_node("%Talk").used.emit(null)
	var entry := Vignettes.entry_line_id(wanted)
	assert_eq(Content.dialogue.current_line_id(), entry, "Talk opens the first line")
	assert_signal_emitted_with_parameters(spot, "talked", [entry])
	var index := _outcome_card(wanted)
	assert_gte(index, 0, "the first line offers an outcome")
	var flag: String = wanted["lines"][entry]["cards"][index]["sets"][0]
	Content.dialogue.choose(index)
	assert_true(GameState.has_flag(flag), "the card set its flag")
	assert_true(GameState.has_flag(Vignettes.done_flag(wanted["id"])), "and the vignette is done")
	assert_eq(Array(GameState.journey_lines), [wanted["journey_line_id"]])
	assert_signal_emitted_with_parameters(spot, "completed", [wanted["id"]])
	assert_false(spot.get_node("%Talk").is_available(), "Talk closes")
	assert_true(Content.dialogue.is_running(), "the stranger's closing line is still up")
	Content.dialogue.dismiss()
	assert_eq(Vignettes.pending_for_spot(wanted["spot"]).size(), 0, "nothing more at this spot")


func test_walking_away_without_an_outcome_leaves_it_pending() -> void:
	Vignettes.grant_today(GameState, A_DATE)
	var wanted: Dictionary = Vignettes.pending()[0]
	var spot := _spot(wanted["spot"])
	await wait_frames(1)
	spot.get_node("%Talk").used.emit(null)
	Content.dialogue.dismiss()
	assert_false(GameState.has_flag(Vignettes.done_flag(wanted["id"])))
	assert_eq(Vignettes.pending()[0]["id"], wanted["id"], "still waiting")
	assert_true(spot.get_node("%Talk").is_available(), "and Talk is still offered")


# -- persistence --------------------------------------------------------------


func test_the_queue_survives_save_and_load() -> void:
	Vignettes.grant_today(GameState, A_DATE)
	Vignettes.grant_today(GameState, LATER_DATE)
	var played := Vignettes.id_for_date(NEXT_DATE)
	GameState.set_flag(Vignettes.done_flag(played))
	GameState.save()
	var loaded: Node = GAME_STATE.new()
	loaded.save_path = SCRATCH
	assert_true(loaded.load_journey())
	assert_eq(loaded.vignette_days, GameState.vignette_days)
	var pending := Vignettes.pending(loaded)
	assert_eq(pending.size(), 3, "three of four days still wait")
	for vignette in pending:
		assert_ne(vignette["id"], played, "the played one is gone")
	assert_eq(pending[0]["id"], Vignettes.id_for_date(A_DATE))
	loaded.free()


func test_play_again_forgets_the_granted_days() -> void:
	Vignettes.grant_today(GameState, A_DATE)
	GameState.wipe()
	assert_true(GameState.vignette_days.is_empty())
	assert_eq(Vignettes.pending().size(), 0)
