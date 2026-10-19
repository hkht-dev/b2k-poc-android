## Tests the journey object: one thing to save, inspect and reset.
##
## CLAUDE_CODE_BRIEF.md §5 and GDD §12. Uses bare instances with autosave off
## and a scratch save path, so the real journey file is never touched.
extends GutTest

const GAME_STATE := preload("res://scripts/core/game_state.gd")
const SCRATCH := "user://test_journey.json"


func _fresh() -> Node:
	var state: Node = autofree(GAME_STATE.new())
	state.set_autosave(false)
	state.save_path = SCRATCH
	return state


func after_each() -> void:
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)


func test_flags_announce_through_the_journey() -> void:
	var state := _fresh()
	watch_signals(state)
	state.set_flag("heard_tulu")
	assert_signal_emitted_with_parameters(state, "flag_changed", ["heard_tulu", true])
	assert_true(state.has_flag("heard_tulu"))


func test_an_event_fires_once() -> void:
	var state := _fresh()
	watch_signals(state)
	assert_true(state.fire_event("can_placed_at_fountain"))
	assert_false(state.fire_event("can_placed_at_fountain"), "what happened cannot happen again")
	assert_signal_emit_count(state, "event_fired", 1)


func test_journey_lines_are_ids_and_never_repeat() -> void:
	var state := _fresh()
	assert_true(state.add_journey_line("journey.dry_fountain.gave"))
	assert_false(
		state.add_journey_line("journey.dry_fountain.gave"), "a quest ending twice says so once"
	)
	assert_false(state.add_journey_line(""))
	assert_eq(state.journey_lines, ["journey.dry_fountain.gave"])


func test_choices_are_recorded_as_ids_not_text() -> void:
	var state := _fresh()
	state.record_choice("gopal_admit", 0, PackedStringArray(["gopal_will_carry"]))
	assert_eq(state.choice_history.size(), 1)
	assert_eq(state.choice_history[0]["line"], "gopal_admit")
	assert_eq(state.choice_history[0]["card"], 0)


func test_a_round_trip_through_the_file_loses_nothing() -> void:
	var state := _fresh()
	state.set_autosave(true)
	state.set_beat("street")
	state.set_flag("heard_tulu")
	state.fire_event("can_placed_at_fountain")
	state.record_choice("gopal_admit", 1, PackedStringArray(["gopal_admitted_fear"]))
	state.add_journey_line("journey.dry_fountain.gave")
	state.settings = {"large_text": true}
	state.save()

	var loaded := _fresh()
	assert_true(loaded.load_journey(), "the slot was there")
	assert_eq(loaded.beat, "street")
	assert_true(loaded.has_flag("heard_tulu"))
	assert_true(loaded.has_event("can_placed_at_fountain"))
	assert_eq(loaded.choice_history.size(), 1)
	assert_eq(loaded.journey_lines, ["journey.dry_fountain.gave"])
	assert_eq(loaded.settings.get("large_text"), true)


func test_loading_announces_nothing_per_flag() -> void:
	var state := _fresh()
	state.set_flag("a")
	state.save()
	var loaded := _fresh()
	watch_signals(loaded)
	loaded.load_journey()
	assert_signal_not_emitted(loaded, "flag_changed", "restoring what already was is not a change")


func test_every_flag_change_autosaves() -> void:
	var state := _fresh()
	state.set_autosave(true)
	state.set_flag("heard_tulu")
	assert_true(FileAccess.file_exists(SCRATCH), "the slot is written on a flag change")
	var on_disk: Variant = Strings.read_json_file(SCRATCH)
	assert_true(on_disk is Dictionary and Array(on_disk.get("flags", [])).has("heard_tulu"))


func test_a_missing_file_is_a_new_journey_not_an_error() -> void:
	var state := _fresh()
	assert_false(state.load_journey())
	assert_eq(state.flags.size(), 0)


func test_a_corrupt_file_is_ignored_and_the_title_still_loads() -> void:
	var file := FileAccess.open(SCRATCH, FileAccess.WRITE)
	file.store_string("this is not json")
	file.close()
	var state := _fresh()
	assert_false(state.load_journey())
	assert_eq(state.flags.size(), 0, "nothing half-loaded")


func test_play_again_wipes_everything_including_the_file() -> void:
	var state := _fresh()
	state.set_autosave(true)
	state.set_flag("a")
	state.fire_event("b")
	state.add_journey_line("c")
	state.set_beat("street")
	watch_signals(state)
	state.wipe()
	assert_signal_emitted(state, "wiped")
	assert_eq(state.flags.size(), 0)
	assert_eq(state.events.size(), 0)
	assert_eq(state.journey_lines.size(), 0)
	assert_eq(state.beat, "")
	assert_false(FileAccess.file_exists(SCRATCH), "the slot is gone too")
