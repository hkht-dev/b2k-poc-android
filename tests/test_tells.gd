## Tests the Tells and the *Noticed* list (GDD §6 "Tells", §16a "Noticed"):
## twelve rows of data, each with its sentence; *Look* records a tell once
## and says the sentence; the clock needs the hum; the pause menu lists the
## sentences under *Noticed* with no number; the list survives save and load.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const PAUSE := preload("res://scenes/ui/PauseMenu.tscn")
const GAME_STATE := preload("res://scripts/core/game_state.gd")
const SCRATCH := "user://test_tells_journey.json"
const PUDDLE := "puddle_world"
const CLOCK := "clock_chai_stall"

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


func _tell(street: Node3D, tell_id: String) -> Node3D:
	return street.get_node_or_null("Tells/Tell_" + tell_id)


func _button(street: Node3D) -> Button:
	return street.get_node("%TouchControls").contextual_button()


func _subtitle(street: Node3D) -> String:
	return street.get_node("%TouchControls").subtitle_text()


func _stand_at(street: Node3D, tell_id: String) -> void:
	var tell := _tell(street, tell_id)
	street.get_node("%Player").global_position = tell.global_position + Vector3(0.3, 0.3, 0.3)
	await wait_frames(8)


func test_the_data_has_twelve_tells_each_with_a_sentence_in_the_string_table() -> void:
	var ids := Tells.ids()
	assert_eq(ids.size(), 12)
	for id in ids:
		var sentence_id := Tells.sentence_id_of(id)
		assert_eq(sentence_id, "tell." + id, "sentences are tell.<id>")
		assert_true(Strings.has_id(sentence_id), "%s has its sentence" % id)
		assert_true(Places.has(Tells.place_of(id)), "%s stands in a known place" % id)
	assert_eq(Tells.in_place("street"), ids, "all twelve are the Street's")
	assert_true(Tells.requires_humming(CLOCK), "the clock needs the hum")
	assert_false(Tells.requires_humming(PUDDLE))
	assert_false(Tells.has("not_a_tell"))
	assert_eq(Tells.sentence_id_of("not_a_tell"), "")


func test_every_tell_stands_in_the_street_with_a_prop_beside_it() -> void:
	var street := _street()
	await wait_frames(1)
	for id in Tells.ids():
		var tell := _tell(street, id)
		assert_not_null(tell, "%s is in the street" % id)
		if tell == null:
			continue
		assert_eq(tell.tell_id, id)
		assert_eq(tell.get_node("%Look").verb_id, "verb.look")
	assert_gt(street.get_node("Tells").get_child_count(), 12, "props stand beside the tells")


func test_look_records_the_tell_once_and_says_the_sentence() -> void:
	var street := _street()
	watch_signals(GameState)
	await _stand_at(street, PUDDLE)
	assert_eq(_button(street).current_verb(), "verb.look")
	var flags_before: int = GameState.flags.size()
	var events_before: int = GameState.events.size()
	_button(street).pressed.emit()
	await wait_frames(2)
	assert_eq(PackedStringArray(GameState.noticed), PackedStringArray([PUDDLE]))
	assert_signal_emitted_with_parameters(GameState, "noticed_added", [PUDDLE])
	assert_eq(_subtitle(street), "In the puddle by Gopal Seth's shop a small world was turning.")
	assert_eq(GameState.flags.size(), flags_before, "no flag: nothing counts it")
	assert_eq(GameState.events.size(), events_before, "no event either")
	assert_true(GameState.journey_lines.is_empty(), "its own list, not a journey line")
	_button(street).pressed.emit()
	await wait_frames(2)
	assert_eq(GameState.noticed.size(), 1, "looking twice records it once")
	assert_false(GameState.notice(PUDDLE), "and notice() says so")
	assert_eq(_button(street).current_verb(), "verb.look", "but you may still look")


func test_the_clock_offers_look_only_while_the_player_hums() -> void:
	var street := _street()
	await _stand_at(street, CLOCK)
	assert_ne(_button(street).current_verb(), "verb.look", "silent: no Look")
	assert_false(_tell(street, CLOCK).is_available())
	street.hum()
	await wait_frames(3)
	assert_true(street.is_humming())
	assert_eq(_button(street).current_verb(), "verb.look", "while the hum sounds, Look")
	_button(street).pressed.emit()
	await wait_frames(2)
	assert_eq(PackedStringArray(GameState.noticed), PackedStringArray([CLOCK]))
	assert_eq(_subtitle(street), "The clock over the chai stall stopped while you hummed.")
	await wait_seconds(2.0)
	assert_false(street.is_humming(), "the hum has ended")
	assert_ne(_button(street).current_verb(), "verb.look", "and Look went with it")


func test_the_pause_menu_lists_the_sentences_under_noticed_hidden_until_there_is_one() -> void:
	var empty: Control = add_child_autofree(PAUSE.instantiate())
	await wait_frames(1)
	assert_false(empty.get_node("%NoticedTitle").visible, "hidden with nothing noticed")
	assert_false(empty.get_node("%Noticed").visible)
	assert_eq(empty.noticed_texts(), PackedStringArray())
	GameState.notice("kite_no_string")
	GameState.notice("bird_still")
	var menu: Control = add_child_autofree(PAUSE.instantiate())
	await wait_frames(1)
	assert_true(menu.get_node("%NoticedTitle").visible)
	assert_eq(menu.get_node("%NoticedTitle").text, "Noticed")
	assert_eq(
		menu.noticed_texts(),
		PackedStringArray(
			[
				"A kite hung over the crossing. It had no string.",
				"A bird sat on the wire the whole time you watched. It never once moved.",
			]
		),
		"in the order seen"
	)
	var digits := RegEx.create_from_string("\\d")
	assert_null(digits.search(menu.get_node("%NoticedTitle").text), "no count in the title")
	for text in menu.noticed_texts():
		assert_null(digits.search(text), "no number anywhere: '%s'" % text)


func test_noticed_survives_save_and_load_and_play_again_wipes_it() -> void:
	GameState.notice("jasmine_dust")
	GameState.notice("footprints_wet")
	GameState.notice("jasmine_dust")
	assert_true(GameState.save())
	var loaded: Node = GAME_STATE.new()
	loaded.save_path = SCRATCH
	assert_true(loaded.load_journey())
	assert_eq(
		PackedStringArray(loaded.noticed), PackedStringArray(["jasmine_dust", "footprints_wet"])
	)
	assert_true(loaded.to_dict()["noticed"] is Array, "kept as the list itself, never a number")
	loaded.free()
	GameState.wipe()
	assert_true(GameState.noticed.is_empty(), "Play again forgets them with the rest")
