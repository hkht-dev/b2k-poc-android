## Tests the daylight: the Street's light moves with the story (GDD §5,
## Hollow Vale row), from data/daylight.json, by flags and nothing else.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_daylight_journey.json"
## Where the generator's hand-placed sun sent its light before the stages
## existed (scenes/street/Street.tscn, Sun). The arrival stage reproduces it.
const GENERATOR_SUN_TRAVEL := Vector3(-0.357, -0.7, -0.618)
const LAMP_ENERGY := 1.5
const LAMP_COUNT := 6

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


func _lamps(street: Node3D) -> Array[Node]:
	return street.get_tree().get_nodes_in_group(Daylight.LAMP_GROUP)


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_the_data_loads_ordered_stages_with_well_formed_conditions() -> void:
	assert_eq(
		Array(Daylight.stage_ids()),
		["arrival", "after_fountain", "evening", "dawn", "remembrance"],
		"the stages, in story order"
	)
	assert_eq(str(Daylight.stages()[0]["when"]), "true", "the first stage always holds")
	for entry: Dictionary in Daylight.stages():
		assert_true(Condition.is_well_formed(str(entry["when"])), "%s: condition" % entry["id"])
		for key in ["sun_colour", "fog_colour", "sky_tint"]:
			assert_eq((entry[key] as Array).size(), 3, "%s: %s is [r, g, b]" % [entry["id"], key])
		for key in [
			"sun_energy",
			"sun_elevation_degrees",
			"sun_azimuth_degrees",
			"ambient_energy",
			"fog_density"
		]:
			assert_true(entry[key] is float, "%s: %s is a number" % [entry["id"], key])
		assert_true(entry["lamps_on"] is bool, "%s: lamps_on is a bool" % entry["id"])
	assert_almost_eq(Daylight.transition_seconds(), 6.0, 0.001)


func test_no_pink_before_remembrance_and_no_peacock_blue_anywhere() -> void:
	for entry: Dictionary in Daylight.stages():
		for key in ["sky_tint", "sun_colour", "fog_colour"]:
			var c := Daylight.colour_of(entry, key)
			# Rose: red stands away from blue while green stays beside blue.
			var rose := c.r - c.b > 0.1 and c.g - c.b < (c.r - c.b) * 0.5
			if str(entry["id"]) != "remembrance":
				assert_false(
					rose, "%s %s is not pink (GDD §5: none before Act 4)" % [entry["id"], key]
				)
			assert_lt(c.b - c.r, 0.25, "%s %s is no saturated blue (GDD §10)" % [entry["id"], key])
	assert_true(
		(
			Daylight.colour_of(Daylight.stage("remembrance"), "sky_tint").r
			> Daylight.colour_of(Daylight.stage("remembrance"), "sky_tint").b
		),
		"remembrance lets the first rose in"
	)


func test_arrival_applies_at_start_and_the_lamps_are_off() -> void:
	var street := _street()
	await wait_frames(2)
	var daylight: Daylight = street.daylight()
	assert_eq(daylight.stage_id(), "arrival")
	var arrival := Daylight.stage("arrival")
	assert_eq(street.mood_sun_colour(), Daylight.colour_of(arrival, "sun_colour"), "set at once")
	var sun: DirectionalLight3D = street.get_node("Sun")
	assert_almost_eq(sun.light_energy, float(arrival["sun_energy"]), 0.001)
	var travel := -sun.global_transform.basis.z
	assert_lt(travel.y, 0.0, "the light comes down")
	assert_almost_eq(
		travel.distance_to(GENERATOR_SUN_TRAVEL), 0.0, 0.02, "arrival is the generator's sun"
	)
	var env: Environment = street.get_node("Environment").environment
	assert_almost_eq(env.ambient_light_energy, float(arrival["ambient_energy"]), 0.001)
	assert_eq(env.fog_light_color, Daylight.colour_of(arrival, "fog_colour"))
	assert_almost_eq(env.fog_density, float(arrival["fog_density"]), 0.00001)
	assert_ne(env.ambient_light_source, Environment.AMBIENT_SOURCE_DISABLED, "ambient counts")
	var sky_material := env.sky.sky_material as ShaderMaterial
	assert_not_null(sky_material, "the sky is the tinted panorama")
	assert_eq(sky_material.get_shader_parameter(Daylight.SKY_TINT_PARAMETER), Color.WHITE)
	assert_false(daylight.lamps_on())
	var lamps := _lamps(street)
	assert_eq(lamps.size(), LAMP_COUNT, "six lamps: the mobile budget")
	for lamp: OmniLight3D in lamps:
		assert_false(lamp.visible, "off at arrival")
		assert_false(lamp.shadow_enabled, "no shadow")
		assert_almost_eq(lamp.omni_range, 9.0, 0.001)
		var flat := Vector2(lamp.global_position.x, lamp.global_position.z)
		assert_lt(flat.length(), 25.0, "on a post near the fountain")


func test_giving_the_can_moves_the_light_toward_after_fountain_over_time() -> void:
	var street := _street()
	await wait_frames(2)
	var daylight: Daylight = street.daylight()
	var sun: DirectionalLight3D = street.get_node("Sun")
	var before: Color = street.mood_sun_colour()
	var before_rotation := sun.quaternion
	watch_signals(daylight)
	GameState.set_flag("gave_dry_fountain")
	assert_eq(daylight.stage_id(), "after_fountain")
	assert_signal_emitted_with_parameters(daylight, "stage_changed", ["after_fountain"])
	var target := daylight.target_sun_colour()
	var expected: Color = (
		Daylight.colour_of(Daylight.stage("after_fountain"), "sun_colour")
		* street.MOODS["gave_dry_fountain"][0]
	)
	assert_eq(target, expected, "the stage's colour under the P4 mood")
	await wait_seconds(0.6)
	var now: Color = street.mood_sun_colour()
	assert_ne(now, before, "the colour has begun to move")
	assert_ne(now, target, "and has not arrived: it eases over seconds")
	assert_lt(_distance(now, target), _distance(before, target), "toward the data")
	assert_false(sun.quaternion.is_equal_approx(before_rotation), "the sun is moving too")
	assert_false(daylight.lamps_on(), "no lamps in the afternoon")


func test_evening_needs_two_of_the_four_and_lights_the_lamps() -> void:
	var street := _street()
	await wait_frames(2)
	var daylight: Daylight = street.daylight()
	GameState.set_flag("garden_open")
	assert_eq(daylight.stage_id(), "arrival", "one quest is not an evening")
	assert_false(daylight.lamps_on())
	GameState.set_flag("rukma_heard")
	assert_eq(daylight.stage_id(), "evening", "two are")
	# The lamps fade in by a tween; under a loaded machine give it frames.
	await wait_frames(10)
	assert_true(daylight.lamps_on())
	for lamp: OmniLight3D in _lamps(street):
		assert_true(lamp.visible, "the lamps are coming on")
		assert_gt(lamp.light_energy, 0.0)
		assert_lt(lamp.light_energy, LAMP_ENERGY, "fading in, not switched")
	GameState.set_flag("gave_dry_fountain")
	assert_eq(daylight.stage_id(), "evening", "the later stage wins over after_fountain")
	GameState.set_flag("on_the_tower")
	assert_eq(daylight.stage_id(), "dawn")
	assert_true(daylight.lamps_on(), "still lamplit at dawn")


func test_a_loaded_journey_starts_in_its_hour_without_easing() -> void:
	GameState.set_flag("garden_open")
	GameState.set_flag("counting_man_freed")
	var street := _street()
	await wait_frames(2)
	var daylight: Daylight = street.daylight()
	assert_eq(daylight.stage_id(), "evening")
	var evening := Daylight.stage("evening")
	assert_eq(street.mood_sun_colour(), Daylight.colour_of(evening, "sun_colour"), "at once")
	assert_eq(daylight.sky_tint(), Daylight.colour_of(evening, "sky_tint"))
	for lamp: OmniLight3D in _lamps(street):
		assert_true(lamp.visible)
		assert_almost_eq(lamp.light_energy, LAMP_ENERGY, 0.001, "fully lit, no fade on load")


func test_the_p4_mood_still_darkens_on_a_taken_can() -> void:
	var street := _street()
	await wait_frames(2)
	var before: Color = street.mood_sun_colour()
	GameState.set_flag("took_dry_fountain")
	var target: Color = street.daylight().target_sun_colour()
	var hour := Daylight.colour_of(Daylight.stage("after_fountain"), "sun_colour")
	assert_lte(target.r, hour.r + 0.0001, "the took mood steps the hour darker")
	assert_lte(target.g, hour.g + 0.0001)
	assert_lte(target.b, hour.b + 0.0001)
	assert_ne(target, hour, "the mood is still a step on top of the stage")
	# A loaded CI runner can take a few frames to start the tween.
	await wait_frames(10)
	assert_ne(street.mood_sun_colour(), before, "a taken can steps the light")


func test_no_clock_drives_the_light() -> void:
	var street := _street()
	await wait_frames(2)
	var daylight: Daylight = street.daylight()
	assert_eq(daylight.find_children("*", "Timer", true, false).size(), 0, "no timer")
	assert_false(daylight.is_processing())
	assert_false(daylight.is_physics_processing())
	await wait_seconds(0.5)
	assert_eq(daylight.stage_id(), "arrival", "time alone changes nothing")
	assert_eq(street.mood_sun_colour(), Daylight.colour_of(Daylight.stage("arrival"), "sun_colour"))


func test_the_remembrance_tint_outlasts_a_later_mood_and_stage() -> void:
	var street := _street()
	await wait_frames(2)
	var daylight: Daylight = street.daylight()
	var rose := Color(1.0, 0.74, 0.66)
	street.tint_sun(rose, 0.0)
	assert_eq(street.mood_sun_colour(), rose, "set at once")
	assert_true(daylight.is_sun_tinted())
	GameState.set_flag("took_dry_fountain")
	assert_eq(daylight.stage_id(), "after_fountain", "the stage still moves")
	assert_eq(
		daylight.target_sun_colour(),
		rose * street.MOODS["took_dry_fountain"][0],
		"but the mood tints from the rose, not from the stage's colour"
	)
	await wait_frames(10)
	assert_ne(
		street.mood_sun_colour(),
		Daylight.colour_of(Daylight.stage("after_fountain"), "sun_colour"),
		"the dawn is not undone"
	)
