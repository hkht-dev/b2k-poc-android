## Tests the stray cows (GDD §3a Act 3 "Walk ahead of two cows and hum to
## steer them through traffic"; §16a "Stray cows"): two stand on the street,
## a hum calls one, it waits at the kerb while a car is near, the fountain's
## step fires its event, both events end the quest, and the traffic stops
## for a cow as it does for the player.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const COW := preload("res://scenes/street/Cow.tscn")
const MOVER := preload("res://scripts/street/path_mover.gd")
const SCRATCH := "user://test_cows_journey.json"
## The east-west road of the street: z = 16, 5.5 m either side.
const ROAD_NORTH_EDGE := 10.5

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


## A flat ground for the cows to stand on when the street is not needed.
func _floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = Vector3(0, -0.5, 0)


func _cow_at(where: Vector3) -> Cow:
	var cow: Cow = COW.instantiate()
	add_child_autofree(cow)
	cow.global_position = where
	return cow


## Something in the player group standing somewhere: where the hum comes from.
func _player_at(where: Vector3) -> Node3D:
	var stub := Node3D.new()
	stub.add_to_group("player")
	add_child_autofree(stub)
	stub.global_position = where
	return stub


## A vehicle as the street has them: a path mover that brakes early, parked
## at a point on its loop.
func _vehicle(from: Vector3, to: Vector3, parked_at: Vector3) -> Node3D:
	var mover: Node3D = MOVER.new()
	mover.points = PackedVector3Array([from, to])
	mover.speed = 7.0
	mover.yield_distance = 9.0
	mover.yield_width = 2.2
	add_child_autofree(mover)
	mover.set_process(false)
	mover.global_position = parked_at
	return mover


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


# -- on the street --------------------------------------------------------------


func test_two_cows_stand_on_the_north_pavement_east_of_the_fountain() -> void:
	var street := _street()
	var cows := get_tree().get_nodes_in_group("cow")
	assert_eq(cows.size(), 2, "two cows (GDD §3a)")
	var events := []
	for node: Node in cows:
		var cow := node as Cow
		assert_not_null(cow, "%s is a Cow" % node.name)
		assert_true(cow.is_in_group("sound_source"), "a hum reaches it")
		assert_eq(cow.collision_layer, 1, "on the world layer: the player bumps into it")
		assert_gt(cow.global_position.x, 36.0, "east of the north-south road")
		assert_between(cow.global_position.z, -7.0, 8.0, "on the north pavement")
		assert_false(cow.is_at_fountain())
		events.append(cow.reached_event)
	assert_has(events, "cow_reached_fountain_0")
	assert_has(events, "cow_reached_fountain_1")
	assert_null(street.get_node("Ambience").get_node_or_null("Cow0"), "not an ambience loop")


func test_the_street_has_three_vehicles_and_they_are_the_lanes() -> void:
	_street()
	var vehicles := get_tree().get_nodes_in_group("vehicle")
	assert_eq(vehicles.size(), 3, "the three cars are traffic")
	for vehicle: Node in vehicles:
		assert_true(vehicle.name.begins_with("Vehicle"), "%s brakes early" % vehicle.name)
	for pedestrian: Node in get_tree().get_nodes_in_group("vehicle"):
		assert_false(pedestrian.name.begins_with("Pedestrian"))


func test_a_hum_from_five_metres_pulls_a_cow_toward_where_the_player_stood() -> void:
	var street := _street()
	var cow: Cow = street.get_node("Cows/Cow0")
	var player: Node3D = street.get_node("%Player")
	await wait_frames(2)
	var hum_spot := cow.global_position + Vector3(0, 0, -5)
	player.global_position = hum_spot + Vector3(0, 0.3, 0)
	await wait_frames(2)
	var before := _flat(cow.global_position, hum_spot)
	watch_signals(cow)
	street.hum()
	assert_signal_emitted(cow, "called")
	assert_true(cow.is_called(), "it set off")
	assert_lt(_flat(cow.call_target(), hum_spot), 0.1, "toward where the player stood")
	await wait_frames(60)
	var after := _flat(cow.global_position, hum_spot)
	assert_lt(after, before - 0.4, "a second later it is nearer (%.2f -> %.2f)" % [before, after])


# -- a cow on its own --------------------------------------------------------------


func test_a_hum_walks_a_cow_at_most_eight_metres() -> void:
	_floor()
	var cow := _cow_at(Vector3(30, 0, 0))
	_player_at(Vector3(0, 0, 0))
	await wait_frames(2)
	assert_true(cow.hear_hum())
	assert_almost_eq(cow.call_target().x, 22.0, 0.05, "8 m toward the hum and no further")
	assert_almost_eq(cow.call_target().z, 0.0, 0.05)


func test_a_cow_waits_at_the_kerb_while_a_vehicle_is_near_its_lane() -> void:
	_floor()
	# The street's two east-west lanes, z = 14.5 and z = 17.5; one car near.
	# Everything stands at x = 20, well clear of the fountain's 9 m.
	var near := _vehicle(Vector3(-60, 0, 14.5), Vector3(60, 0, 14.5), Vector3(21, 0, 14.5))
	_vehicle(Vector3(60, 0, 17.5), Vector3(-60, 0, 17.5), Vector3(50, 0, 17.5))
	var cow := _cow_at(Vector3(20, 0, 9))
	_player_at(Vector3(20, 0, 24))
	await wait_frames(2)
	assert_true(cow.hear_hum(), "the hum reaches it")
	assert_gt(cow.call_target().z, ROAD_NORTH_EDGE, "the hum asks it across the road")
	await wait_frames(120)
	assert_lt(cow.global_position.z, ROAD_NORTH_EDGE, "two seconds on, it has not stepped off")
	assert_true(cow.is_waiting(), "it is waiting for the car")
	near.global_position.x = 50.0
	await wait_frames(100)
	assert_false(cow.is_waiting())
	assert_gt(cow.global_position.z, ROAD_NORTH_EDGE, "the car gone, it crosses")


func test_a_cow_already_in_the_road_keeps_going_so_car_and_cow_never_wait_on_each_other() -> void:
	_floor()
	_vehicle(Vector3(-60, 0, 14.5), Vector3(60, 0, 14.5), Vector3(21, 0, 14.5))
	var cow := _cow_at(Vector3(20, 0, 12))
	_player_at(Vector3(20, 0, 24))
	await wait_frames(2)
	cow.hear_hum()
	await wait_frames(60)
	assert_false(cow.is_waiting(), "in the lane it does not stop")
	assert_gt(cow.global_position.z, 12.3, "it walks on")


func test_reaching_the_fountain_step_fires_its_event_and_the_cow_stays() -> void:
	_floor()
	var cow := _cow_at(Vector3(10.0, 0, 0))
	_player_at(Vector3(0, 0, 0))
	watch_signals(cow)
	await wait_frames(2)
	assert_false(GameState.has_event("cow_reached_fountain_0"), "10 m out is not the step")
	assert_true(cow.hear_hum())
	await wait_frames(120)
	assert_true(GameState.has_event("cow_reached_fountain_0"), "within 9 m the event fires")
	assert_signal_emitted(cow, "reached_fountain")
	assert_true(cow.is_at_fountain())
	assert_false(cow.hear_hum(), "it has arrived; hums move it no more")


func test_a_cow_whose_event_has_fired_starts_at_its_rest() -> void:
	_floor()
	GameState.fire_event("cow_reached_fountain_1")
	var cow: Cow = COW.instantiate()
	cow.reached_event = "cow_reached_fountain_1"
	cow.rest_position = Vector3(8.4, 0, -2.4)
	add_child_autofree(cow)
	assert_almost_eq(cow.global_position.x, 8.4, 0.01, "a loaded journey finds it there")
	assert_almost_eq(cow.global_position.z, -2.4, 0.01)
	assert_true(cow.is_at_fountain())


# -- the quest and the traffic --------------------------------------------------------


func test_both_cows_at_the_fountain_end_the_quest_with_its_line() -> void:
	var quest: Quest = Content.quest("stray_cows")
	assert_not_null(quest, "data/quests/stray_cows.json loaded")
	assert_eq(quest.status(), Quest.Status.INACTIVE, "nothing until Tulu has been heard")
	GameState.set_flag("heard_tulu")
	assert_eq(quest.status(), Quest.Status.ACTIVE)
	assert_eq(quest.current_step_id(), "both_at_fountain")
	assert_eq(
		Strings.t(quest.current_objective_text_id()),
		"Two cows nobody sees. Hum, and walk them to the fountain."
	)
	GameState.fire_event("cow_reached_fountain_0")
	assert_eq(quest.status(), Quest.Status.ACTIVE, "one cow is not two")
	GameState.fire_event("cow_reached_fountain_1")
	assert_eq(quest.status(), Quest.Status.ENDED)
	assert_true(GameState.has_flag("cows_home"))
	assert_true(GameState.journey_lines.has("journey.stray_cows"))
	assert_eq(
		Strings.t("journey.stray_cows"), "You walked two cows through the traffic to the fountain."
	)


func test_a_path_mover_stops_for_a_cow_in_its_way() -> void:
	var mover: Node3D = MOVER.new()
	mover.points = PackedVector3Array([Vector3(0, 0, 0), Vector3(40, 0, 0)])
	mover.speed = 7.0
	mover.yield_distance = 9.0
	mover.yield_width = 2.2
	add_child_autofree(mover)
	var cow := _cow_at(Vector3(5, 0, 0.5))
	cow.set_physics_process(false)
	for _i in 30:
		mover._process(0.1)
	assert_true(mover.is_yielding(), "it brakes for the cow")
	assert_lt(mover.position.x, 4.0, "and does not drive through it")
	cow.global_position = Vector3(5, 0, 6)
	for _i in 30:
		mover._process(0.1)
	assert_false(mover.is_yielding(), "the cow off the lane, it goes on")
	assert_gt(mover.position.x, 5.0)
