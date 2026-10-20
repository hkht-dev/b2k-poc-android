## Tests Remembrance and Home (GDD §3 Act 4 and Act 5, §3a Act 4 and Act 5,
## §8 Scene F): the hum held on the fountain steps and the world's answer by
## data, the way into the water, and the embrace that ends the chapter.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const HOME := preload("res://scenes/places/Home.tscn")
const SCRATCH := "user://test_remembrance_home_journey.json"
## The fountain's south-east corner step: Hum here, and the way in.
const STEPS := Vector3(5.55, 0.0, 5.55)
## In the shallows, a step short of Him.
const BEFORE_HIM := Vector3(0.0, 0.05, -10.6)

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


func _home(stand_in: bool = true) -> Node3D:
	var home: Node3D = HOME.instantiate()
	if not stand_in:
		home.stand_in_flags = PackedStringArray()
	add_child_autofree(home)
	home.get_node("%TouchControls").apply_scheme("touch")
	return home


func _button(place: Node3D) -> Button:
	return place.get_node("%TouchControls").contextual_button()


func _put(place: Node3D, where: Vector3) -> void:
	place.get_node("%Player").global_position = where
	await wait_frames(8)


func _press(place: Node3D) -> void:
	_button(place).pressed.emit()
	await wait_frames(2)


## The yaw a body at [param from] has when it faces [param point].
static func _yaw_toward(from: Vector3, point: Vector3) -> float:
	var to := point - from
	return atan2(-to.x, -to.z)


static func _angle_between(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))


static func _is_magenta(colour: Color) -> bool:
	return colour.r > 0.6 and colour.b > 0.6 and colour.g < 0.45


# -- Act 4: the hum on the steps ------------------------------------------------


func test_hum_here_is_absent_until_a_dawn_flag_is_set() -> void:
	var street := _street()
	await _put(street, STEPS)
	assert_ne(_button(street).current_verb(), "verb.hum_here", "no dawn yet, no verb")
	GameState.set_flag("played_for_others")
	await wait_frames(3)
	assert_eq(_button(street).current_verb(), "verb.hum_here", "the tower's flag opens it")
	assert_eq(Strings.t("verb.hum_here"), "Hum here")


func test_with_played_for_others_the_street_stops_to_listen_and_remembers() -> void:
	var street := _street()
	var point: Node3D = street.get_node("%Remembrance")
	point.hum_seconds = 1.5
	GameState.set_flag("played_for_others")
	await _put(street, STEPS)
	var before: Color = street.mood_sun_colour()
	var hums_before: int = GameState.hum_count
	await _press(street)
	assert_true(point.is_holding(), "the hum is held")
	var rig: CharacterRig = street.get_node("%Player/Mesh")
	assert_eq(rig.state(), "pose", "the player holds a pose")
	assert_true(point.bubble().visible, "a bubble passes")
	var ped: Node3D = street.get_node("Ambience/Pedestrian1")
	assert_true(ped.is_paused(), "a pedestrian stops")
	assert_false(street.get_node("Ambience/Vehicle0").is_paused(), "the cars drive on")
	await wait_seconds(0.9)
	var wanted := _yaw_toward(ped.global_position, point.global_position)
	assert_lt(_angle_between(ped.rotation.y, wanted), 0.2, "and faces the fountain steps")
	assert_ne(street.mood_sun_colour(), before, "the sun warms toward rose")
	assert_false(GameState.has_flag("remembered"), "not before the hum is done")
	await wait_seconds(1.0)
	assert_true(GameState.has_flag("remembered"))
	assert_true(GameState.journey_lines.has("journey.act4.street_listened"))
	assert_eq(GameState.hum_count, hums_before + 3, "the hum, three times, counted as hums")
	assert_false(point.is_holding())
	assert_ne(rig.state(), "pose", "and the player is let go")
	await wait_frames(3)
	assert_ne(_button(street).current_verb(), "verb.hum_here", "offered once")


func test_with_kept_veena_nobody_turns_but_the_bubble_and_a_softer_tint_come() -> void:
	var street := _street()
	var point: Node3D = street.get_node("%Remembrance")
	point.hum_seconds = 1.0
	GameState.set_flag("kept_veena")
	await _put(street, STEPS)
	var before: Color = street.mood_sun_colour()
	await _press(street)
	assert_true(point.is_holding())
	assert_true(point.bubble().visible, "the bubble passes anyway")
	for i: int in 5:
		var ped: Node3D = street.get_node("Ambience/Pedestrian%d" % i)
		assert_false(ped.is_paused(), "no crowd on the quiet variant")
	var walker: Node3D = street.get_node("Ambience/Pedestrian1")
	assert_lt(_angle_between(walker.rotation.y, -PI / 2), 0.05, "still walking east")
	await wait_seconds(0.4)
	assert_ne(street.mood_sun_colour(), before, "a softer tint")
	await wait_seconds(1.0)
	assert_true(GameState.has_flag("remembered"))
	assert_true(GameState.journey_lines.has("journey.act4.alone"))


# -- the way in -----------------------------------------------------------------


## GDD §3 Act 5 is "Rising" and then "Home": the water leads into the ascent
## through the Pool of Worlds, which hands the player on to the riverbank.
func test_the_basin_door_needs_remembered_and_leads_into_the_ascent() -> void:
	var street := _street()
	watch_signals(street)
	await _put(street, STEPS)
	assert_ne(_button(street).current_verb(), "verb.step_in", "not before remembering")
	GameState.set_flag("remembered")
	await wait_frames(3)
	assert_eq(_button(street).current_verb(), "verb.step_in")
	assert_eq(Strings.t("verb.step_in"), "Step into the water")
	await _press(street)
	assert_true(street.is_leaving())
	assert_eq(GameState.place, "veil_up", "the rise, not the bank straight away")
	assert_eq(GameState.spawn, "bank")
	await wait_seconds(street.DOOR_FADE_SECONDS + 0.2)
	assert_signal_emitted_with_parameters(street, "place_requested", ["veil_up", "bank"])


## The ascent was orphaned until the owner's second review: nothing anywhere
## named "veil_up", so Act 5's rise could not be reached at all.
func test_the_ascent_is_reachable_and_hands_the_player_on_to_the_bank() -> void:
	var ascent: Node3D = add_child_autofree(
		(load(Places.scene_of("veil_up")) as PackedScene).instantiate()
	)
	await wait_frames(2)
	assert_false(ascent.is_down(), "it rises")
	assert_eq(ascent.next_place, "home", "it ends on the riverbank")
	assert_eq(ascent.next_spawn, "bank")
	var street_text := FileAccess.get_file_as_string("res://scenes/street/Street.tscn")
	assert_true(
		street_text.contains('place_id = "veil_up"'), "a door in the street leads into the ascent"
	)


# -- Act 5: Home ----------------------------------------------------------------


func test_home_loads_as_a_place_the_journey_knows() -> void:
	assert_eq(Places.scene_of("home"), HOME.resource_path)
	var home := _home()
	await wait_frames(2)
	assert_true(home is Place, "Home extends Place")
	assert_eq(home.place_id, "home")
	assert_not_null(home.get_node_or_null("%Figure"), "He stands in the shallows")
	var bank: SpawnPoint = null
	for node: Node in get_tree().get_nodes_in_group(SpawnPoint.GROUP):
		if node.spawn_id == "bank":
			bank = node
	assert_not_null(bank, "the door from the street lands on 'bank'")


func test_the_garland_verb_needs_garland_made() -> void:
	var home := _home(false)
	await _put(home, BEFORE_HIM)
	assert_ne(_button(home).current_verb(), "verb.garland", "nothing to give yet")
	var rig: CharacterRig = home.get_node("%Player/Mesh")
	assert_false(rig.is_carrying())
	GameState.set_flag("garland_made")
	await wait_frames(3)
	assert_eq(_button(home).current_verb(), "verb.garland")
	assert_eq(Strings.t("verb.garland"), "Garland")


func test_garlanding_him_sets_embraced_and_ends_the_chapter_in_white() -> void:
	var home := _home()
	watch_signals(home)
	await wait_frames(2)
	assert_true(GameState.has_flag("garland_made"), "the stand-in flag, data on the scene")
	var rig: CharacterRig = home.get_node("%Player/Mesh")
	assert_true(rig.is_carrying(), "the garland is in the hands")
	await _put(home, BEFORE_HIM)
	assert_eq(_button(home).current_verb(), "verb.garland")
	var head: Node3D = home.head()
	var stood: Vector3 = home.figure().global_position
	await _press(home)
	assert_true(home.is_ending())
	await wait_seconds(0.5)
	assert_lt(head.rotation.x, -0.1, "He bows")
	await wait_seconds(home.BOW_SECONDS)
	assert_false(rig.is_carrying(), "the garland left the hands")
	assert_true(home.garland().visible, "and is round His neck")
	await wait_seconds(home.PLACE_SECONDS + home.STEP_SECONDS + home.FADE_SECONDS + 0.4)
	assert_gt(home.figure().global_position.distance_to(stood), 0.5, "He stepped forward")
	assert_true(GameState.has_flag("embraced"))
	assert_true(GameState.journey_lines.has("journey.act5.home"))
	assert_signal_emitted_with_parameters(home, "slice_ended", ["home"])
	assert_almost_eq(home.fade_alpha(), 1.0, 0.01, "the view is gone")
	assert_eq(home.fade_colour().r, 1.0, "to white, not black (GDD §8 Scene F)")


## GDD §10 gives the Grove a magenta sky; this slice keeps Home in rose-gold
## and indigo (docs/DECISIONS.md "Remembrance and Home"), so no material here
## is magenta. His indigo is allowed and documented.
func test_no_material_in_home_is_magenta() -> void:
	var home := _home()
	await wait_frames(1)
	var checked := 0
	for node: Node in home.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if material == null:
				continue
			checked += 1
			assert_false(_is_magenta(material.albedo_color), "%s is magenta" % node.name)
	for node: Node in home.find_children("*", "MultiMeshInstance3D", true, false):
		var material := (node as MultiMeshInstance3D).material_override as StandardMaterial3D
		if material != null:
			checked += 1
			assert_false(_is_magenta(material.albedo_color), "%s is magenta" % node.name)
	var environment: Environment = home.get_node("Environment").environment
	var sky := environment.sky.sky_material as ProceduralSkyMaterial
	assert_false(_is_magenta(sky.sky_top_color), "the sky's top")
	assert_false(_is_magenta(sky.sky_horizon_color), "the horizon")
	assert_gt(checked, 5, "the figure, the water, the garland and the stars were looked at")
	var indigo: StandardMaterial3D = home.get_node("%Figure/Torso").get_active_material(0)
	assert_lt(indigo.albedo_color.r, 0.3, "His indigo is deep, not magenta")
