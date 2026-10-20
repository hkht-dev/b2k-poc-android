## Tests the Garden (GDD §6 "The Garden: seeds, fruit and the creeper", §16a
## "Days and lives"): seeds from flags and choices with their sentences,
## growth by play-day and not by the clock, weeds pulled by hand, the
## creeper's climb and its shade, the round trip through the journey file,
## and a screen with no number anywhere on it.
##
## Model tests use bare GameState instances with autosave off and a scratch
## path; screen tests point the autoload at the scratch path the same way.
extends GutTest

const GAME_STATE := preload("res://scripts/core/game_state.gd")
const GARDEN_SCREEN := preload("res://scenes/ui/GardenScreen.tscn")
const PAUSE := preload("res://scenes/ui/PauseMenu.tscn")
const SCRATCH := "user://test_garden_journey.json"
const DAY_ONE := "2100-01-01"
const DAY_TWO := "2100-01-02"
const DAY_THREE := "2100-01-03"
const BITTER := "flag:took_dry_fountain"
const SWEET := "flag:gave_dry_fountain"
const WEED := "flag:accepted_contest"

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
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)


func _fresh() -> Node:
	var state: Node = autofree(GAME_STATE.new())
	state.set_autosave(false)
	state.save_path = SCRATCH
	Garden.advance_day(state, DAY_ONE)
	return state


func _plant(state: Node, id: String) -> Dictionary:
	for plant in Garden.plot(state):
		if plant["id"] == id:
			return plant
	return {}


func _stage(state: Node, id: String) -> String:
	return str(_plant(state, id).get("stage", ""))


# -- seeds --------------------------------------------------------------------


func test_a_bitter_flag_plants_a_bitter_seed_with_its_sentence() -> void:
	var state := _fresh()
	state.set_flag("took_dry_fountain")
	var plant := _plant(state, BITTER)
	assert_eq(plant.get("kind"), "bitter")
	assert_eq(plant.get("stage"), Garden.STAGE_SEED, "a seed on the day it is planted")
	assert_eq(Strings.t(plant.get("sentence_id", "")), "You took a can that was not yours.")


func test_a_sweet_flag_plants_a_sweet_seed_with_its_sentence() -> void:
	var state := _fresh()
	state.set_flag("gave_dry_fountain")
	var plant := _plant(state, SWEET)
	assert_eq(plant.get("kind"), "sweet")
	assert_eq(Strings.t(plant.get("sentence_id", "")), "You carried water with Gopal.")


func test_a_choice_plants_and_a_flag_the_data_does_not_name_plants_nothing() -> void:
	var state := _fresh()
	state.set_flag("heard_tulu")
	assert_true(Garden.plot(state).is_empty(), "hearing Tulu is not a seed")
	state.record_choice("gopal_admit", 0, PackedStringArray(["gopal_will_carry"]))
	assert_eq(Garden.plot(state).size(), 1)
	var plant := _plant(state, "choice:gopal_admit:0")
	assert_eq(plant.get("kind"), "sweet")
	assert_eq(Strings.t(plant.get("sentence_id", "")), "You asked Gopal to carry one can with you.")
	state.record_choice("gopal_admit", 0, PackedStringArray(["gopal_will_carry"]))
	assert_eq(Garden.plot(state).size(), 2, "a repeated choice plants again")
	assert_ne(Garden.plot(state)[1]["id"], "choice:gopal_admit:0", "with its own id")


func test_the_wish_to_be_seen_is_a_weed() -> void:
	var state := _fresh()
	state.set_flag("accepted_contest")
	var plant := _plant(state, WEED)
	assert_eq(plant.get("kind"), "weed")
	assert_eq(plant.get("stage"), Garden.STAGE_WEED)
	assert_eq(Strings.t(plant.get("sentence_id", "")), "You wanted the tower to see you.")
	assert_eq(Garden.weeds(state).size(), 1)


func test_repeating_a_kind_thickens_that_kind_only() -> void:
	var state := _fresh()
	state.set_flag("took_dry_fountain")
	state.set_flag("gave_dry_fountain")
	var one: int = _plant(state, BITTER)["thickness"]
	state.set_flag("rukma_key_taken")
	assert_gt(_plant(state, BITTER)["thickness"], one, "a habit is a thicker trunk")
	assert_eq(
		_plant(state, "flag:rukma_key_taken")["thickness"], _plant(state, BITTER)["thickness"]
	)
	assert_eq(_plant(state, SWEET)["thickness"], one, "the other kind is untouched")


# -- days ---------------------------------------------------------------------


func test_seeds_grow_by_play_day_not_by_the_clock() -> void:
	var state := _fresh()
	state.set_flag("gave_dry_fountain")
	assert_false(Garden.advance_day(state, DAY_ONE), "the same date is the same day")
	assert_eq(_stage(state, SWEET), Garden.STAGE_SEED)
	assert_true(Garden.advance_day(state, DAY_TWO))
	assert_eq(_stage(state, SWEET), Garden.STAGE_SAPLING)
	assert_true(Garden.ripe_fruit(state).is_empty())
	Garden.advance_day(state, DAY_THREE)
	assert_eq(_stage(state, SWEET), Garden.STAGE_FRUITING)
	assert_eq(Garden.ripe_fruit(state).size(), 1)
	assert_eq(Garden.ripe_fruit(state)[0]["id"], SWEET)


func test_a_weed_never_fruits_and_a_later_seed_is_younger() -> void:
	var state := _fresh()
	state.set_flag("accepted_contest")
	Garden.advance_day(state, DAY_TWO)
	Garden.advance_day(state, DAY_THREE)
	state.set_flag("took_dry_fountain")
	assert_eq(_stage(state, WEED), Garden.STAGE_WEED)
	assert_eq(_stage(state, BITTER), Garden.STAGE_SEED, "planted today")
	assert_true(Garden.ripe_fruit(state).is_empty())


func test_a_journey_saved_before_the_garden_existed_still_grows_one() -> void:
	var state := _fresh()
	(
		state
		. from_dict(
			{
				"flags": ["gave_dry_fountain", "creeper_given"],
				"choice_history": [{"line": "gopal_admit", "card": 0, "sets": []}],
			}
		)
	)
	assert_true(Garden.plot(state).is_empty(), "loading plants nothing by itself")
	Garden.advance_day(state, DAY_ONE)
	assert_eq(Garden.plot(state).size(), 2, "the next play-day notices what was there")
	assert_true(Garden.creeper_given(state))


# -- weeds --------------------------------------------------------------------


func test_pulling_a_weed_removes_it_and_leaves_the_scar() -> void:
	var state := _fresh()
	state.set_flag("accepted_contest")
	state.set_flag("gave_dry_fountain")
	assert_false(Garden.pull(state, SWEET), "only a weed is pulled by hand")
	assert_true(Garden.pull(state, WEED))
	assert_false(Garden.pull(state, WEED), "once")
	assert_true(Garden.weeds(state).is_empty())
	assert_eq(_stage(state, WEED), Garden.STAGE_PULLED, "the scar stays")
	Garden.advance_day(state, DAY_TWO)
	assert_eq(Garden.plot(state).size(), 2, "a pulled weed is not planted again")
	assert_eq(_plant(state, SWEET)["thickness"], 1)


# -- the creeper --------------------------------------------------------------


func test_the_creeper_climbs_only_on_watered_days_after_its_seed_is_given() -> void:
	var state := _fresh()
	state.set_flag("hummed")
	assert_false(Garden.creeper_given(state))
	assert_eq(Garden.creeper_steps(state), 0, "water before the seed is given does nothing")
	state.set_flag("creeper_given")
	assert_true(Garden.creeper_given(state))
	assert_eq(Garden.creeper_steps(state), 0, "a seed at the foot of the wall")
	state.set_flag("heard_tulu")
	assert_eq(Garden.creeper_steps(state), 1, "a watering flag climbs one step")
	state.set_flag("glimpsed_traffic_light")
	assert_eq(Garden.creeper_steps(state), 1, "a day is watered once")
	Garden.advance_day(state, DAY_TWO)
	assert_eq(Garden.creeper_steps(state), 1, "an unwatered day does nothing")
	Garden.advance_day(state, DAY_THREE)
	assert_true(Garden.water(state))
	assert_false(Garden.water(state))
	assert_eq(Garden.creeper_steps(state), 2)


func test_hearing_a_tale_a_glimpse_and_a_lesson_each_water_the_creeper() -> void:
	var state := _fresh()
	state.set_flag("creeper_given")
	state.set_flag(Tales.sitting_flag("puranjana", 1))
	assert_eq(Garden.creeper_steps(state), 1, "a sitting heard waters (GDD §6: hearing)")
	Garden.advance_day(state, DAY_TWO)
	state.set_flag("glimpsed_tower")
	assert_eq(Garden.creeper_steps(state), 2, "a Glimpse waters (remembering)")
	Garden.advance_day(state, DAY_THREE)
	state.set_flag("sarang_taught_bar")
	assert_eq(Garden.creeper_steps(state), 3, "a bar of the Song waters (chanting)")


func test_madhuri_gives_the_creeper_its_seed_with_the_lamp_water() -> void:
	var lines: Variant = Strings.read_json_file("res://data/dialogue/en.json")
	var line: Dictionary = lines.get("madhuri_after_water", {})
	assert_true(
		Array(line.get("sets", [])).has(Garden.creeper_data()["given_flag"]),
		"her line after the water sets the creeper's given_flag (GDD §6, beat 14)"
	)


func test_shade_stops_fruiting() -> void:
	var state := _fresh()
	state.set_flag("gave_dry_fountain")
	state.set_flag("creeper_given")
	state.set_flag("hummed")
	Garden.advance_day(state, DAY_TWO)
	Garden.water(state)
	assert_false(Garden.is_shading(state))
	Garden.advance_day(state, DAY_THREE)
	assert_eq(_stage(state, SWEET), Garden.STAGE_FRUITING, "two steps do not shade")
	Garden.water(state)
	assert_true(Garden.is_shading(state))
	assert_eq(_stage(state, SWEET), Garden.STAGE_SHADED)
	assert_true(Garden.ripe_fruit(state).is_empty())


# -- persistence --------------------------------------------------------------


func test_everything_survives_save_and_load() -> void:
	var state := _fresh()
	state.set_flag("took_dry_fountain")
	state.set_flag("accepted_contest")
	state.set_flag("creeper_given")
	state.set_flag("hummed")
	state.record_choice("gopal_admit", 0, PackedStringArray())
	Garden.pull(state, WEED)
	Garden.advance_day(state, DAY_TWO)
	Garden.water(state)
	state.save()

	var loaded := _fresh()
	assert_true(loaded.load_journey())
	assert_eq(loaded.garden, state.garden)
	assert_eq(Garden.plot(loaded), Garden.plot(state))
	assert_eq(Garden.days(loaded), 1)
	assert_eq(Garden.creeper_steps(loaded), 2)
	assert_true(Garden.is_pulled(loaded, WEED))
	assert_eq(_stage(loaded, BITTER), Garden.STAGE_SAPLING)


func test_play_again_clears_the_plot() -> void:
	var state := _fresh()
	state.set_flag("took_dry_fountain")
	state.wipe()
	assert_eq(state.garden, Garden.empty())


# -- the screen ---------------------------------------------------------------


func _grown_screen() -> Control:
	GameState.set_flag("took_dry_fountain")
	GameState.set_flag("gave_dry_fountain")
	GameState.set_flag("accepted_contest")
	GameState.set_flag("creeper_given")
	GameState.set_flag("hummed")
	return add_child_autofree(GARDEN_SCREEN.instantiate())


func test_the_screen_draws_without_a_number_anywhere() -> void:
	var screen := _grown_screen()
	await wait_frames(2)
	var digits := RegEx.create_from_string("\\d")
	for id in [WEED, BITTER, SWEET, screen.CREEPER_ID, ""]:
		screen.focus_plant(id)
		for label: Label in screen.find_children("*", "Label", true, false):
			assert_null(digits.search(label.text), "no digit in '%s'" % label.text)
		for button: Button in screen.find_children("*", "Button", true, false):
			assert_null(digits.search(button.text), "no digit on '%s'" % button.text)
	screen.focus_plant(BITTER)
	assert_eq(screen.sentence_text(), "You took a can that was not yours.")
	assert_false(screen.pull_button().visible, "a sapling is not pulled")
	screen.focus_plant(screen.CREEPER_ID)
	assert_eq(screen.sentence_text(), "The creeper. Its seed was given to you, not found.")


func test_tapping_a_weed_offers_pull_and_pulling_it_works() -> void:
	var screen := _grown_screen()
	await wait_frames(2)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = screen.plant_position(WEED) + Vector2(0.0, -20.0)
	screen.plot_control().gui_input.emit(touch)
	assert_eq(screen.focused_id(), WEED)
	assert_eq(screen.sentence_text(), "You wanted the tower to see you.")
	assert_true(screen.pull_button().visible)
	screen.pull_button().pressed.emit()
	assert_true(Garden.weeds(GameState).is_empty())
	assert_false(screen.pull_button().visible)
	assert_true(screen.sentence_text().ends_with("The scar stays."))


func test_the_empty_plot_says_so_and_a_tap_on_soil_clears_the_focus() -> void:
	var screen: Control = add_child_autofree(GARDEN_SCREEN.instantiate())
	await wait_frames(2)
	assert_eq(screen.sentence_text(), "Bare soil. Nothing has been planted here yet.")
	GameState.set_flag("gave_dry_fountain")
	screen.refresh()
	screen.focus_plant(SWEET)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(2.0, 2.0)
	screen.plot_control().gui_input.emit(touch)
	assert_eq(screen.focused_id(), "")
	assert_eq(screen.sentence_text(), "Touch a plant to read what planted it.")


func test_the_pause_menu_opens_and_closes_the_garden() -> void:
	var menu: Control = add_child_autofree(PAUSE.instantiate())
	await wait_frames(1)
	var button: Button = menu.get_node("%GardenButton")
	assert_eq(button.text, "The garden")
	button.pressed.emit()
	var overlay: Control = menu.garden_overlay()
	assert_not_null(overlay, "the garden opened over the pause menu")
	button.pressed.emit()
	assert_eq(menu.garden_overlay(), overlay, "one at a time")
	overlay.get_node("%CloseButton").pressed.emit()
	assert_null(menu.garden_overlay())
	await wait_frames(1)
