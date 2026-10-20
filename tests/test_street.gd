## Tests the street scene itself: that it loads, that the player starts where
## the story says, and that walking at the fountain wall climbs them out.
##
## CLAUDE_CODE_BRIEF.md §4.1: the player spawns inside the basin and climbs out.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const MOVER := preload("res://scripts/street/path_mover.gd")


func test_the_street_loads_with_its_landmarks() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	for landmark: String in [
		"Fountain", "Shop", "ChaiStall", "TrafficLight", "Tower", "Flats", "BusStop"
	]:
		assert_not_null(street.get_node_or_null(landmark), "the street has a %s" % landmark)


func test_the_player_starts_inside_the_fountain_basin() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: Node3D = street.get_node("%Player")
	assert_lt(player.global_position.y, 0.0, "the player surfaces from below street level")
	assert_lt(
		Vector2(player.global_position.x, player.global_position.z).length(),
		7.0,
		"and starts within the basin's footprint"
	)


func test_the_climb_exit_is_outside_the_basin() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var exit: Node3D = street.get_node("ClimbOutExit")
	assert_gt(absf(exit.global_position.z), 7.0, "the exit clears the fountain wall")
	assert_almost_eq(exit.global_position.y, 0.05, 0.2, "and lands at street level")


func test_walking_at_the_wall_climbs_the_player_out() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: CharacterBody3D = street.get_node("%Player")

	# Stand at the basin's north lip and walk into it.
	player.global_position = Vector3(0.0, -0.4, -5.1)
	player.velocity = Vector3(0.0, 0.0, -2.0)
	await wait_frames(6)

	assert_true(player.is_climbing() or player.global_position.y > 0.0, "the climb was triggered")


func test_brushing_sideways_past_the_wall_does_not_climb() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: CharacterBody3D = street.get_node("%Player")

	player.global_position = Vector3(0.0, -0.4, -5.1)
	player.velocity = Vector3(2.5, 0.0, 0.0)
	await wait_frames(6)

	assert_false(player.is_climbing(), "walking along the wall is not a climb")


func test_the_ambience_is_on_loops_not_a_simulation() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var ambience: Node3D = street.get_node("Ambience")
	assert_gt(ambience.get_child_count(), 6, "there are pedestrians and vehicles")
	for mover: Node in ambience.get_children():
		assert_false(mover is PhysicsBody3D, "%s moves on a loop, not by physics" % mover.name)
		assert_gt(mover.points.size(), 1, "%s has a loop to follow" % mover.name)


func test_a_path_mover_loops_back_to_where_it_started() -> void:
	var mover: Node3D = autofree(MOVER.new())
	mover.points = PackedVector3Array(
		[Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(4, 0, 4), Vector3(0, 0, 4)]
	)
	mover.speed = 4.0
	add_child_autofree(mover)

	var start := mover.position
	# The loop is 16 m at 4 m/s, so four seconds returns it to the start.
	for _i in 40:
		mover._process(0.1)
	assert_almost_eq(mover.position.distance_to(start), 0.0, 0.05, "it comes back round")


func test_a_path_mover_with_too_few_points_stays_put() -> void:
	var mover: Node3D = autofree(MOVER.new())
	mover.points = PackedVector3Array([Vector3(3, 0, 3)])
	add_child_autofree(mover)
	var before := mover.position
	mover._process(1.0)
	assert_eq(mover.position, before, "a degenerate path cannot divide by zero")


func test_the_opening_shot_is_not_jammed_against_the_basin_wall() -> void:
	# The basin is 14 m across precisely so the 3.5 m arm fits inside it. A
	# narrower fountain put the camera in the wall and filled the screen with
	# the player's capsule.
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var rig: Node3D = street.get_node("%CameraRig")
	await wait_frames(6)
	assert_almost_eq(rig.camera_distance(), rig.DISTANCE, 0.05, "the opening shot has its full arm")


func test_the_camera_pulls_in_when_a_building_is_behind_it() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var rig: Node3D = street.get_node("%CameraRig")
	var player: Node3D = street.get_node("%Player")
	# Stand just north of a flat, so the camera's default +Z arm runs into it.
	player.global_position = Vector3(-10.0, 0.0, -30.5)
	await wait_frames(12)
	assert_lt(rig.camera_distance(), rig.DISTANCE, "the arm shortens rather than clipping")
	assert_gte(rig.camera_distance(), rig.MIN_DISTANCE, "but never collapses onto the player")


func test_the_camera_opens_back_up_in_the_open_street() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var rig: Node3D = street.get_node("%CameraRig")
	var player: Node3D = street.get_node("%Player")
	# Stand in the middle of the road, where nothing is behind the camera.
	player.global_position = Vector3(0.0, 0.0, 40.0)
	await wait_frames(40)
	assert_almost_eq(
		rig.camera_distance(), rig.DISTANCE, 0.3, "the arm returns to 3.5 m in the open"
	)


## End-to-end for P1's gate: "Player climbs out of the fountain and walks the
## block." Drives the real chain — joystick, Street, camera, player — rather
## than calling the controller directly, because Street overwrites the move
## input every physics frame and a direct call would be silently discarded.
func _hold_stick_forward(street: Node3D) -> void:
	var controls: Control = street.get_node("%TouchControls")
	controls.apply_scheme("touch")
	var stick: Control = controls.joystick()
	controls.size = Vector2(1080, 1920)
	stick.size = controls.size
	assert_true(stick.try_claim(0, Vector2(220, 1500)), "the left thumb lands on the stick")
	stick.drag_to(0, Vector2(220, 1500 - stick.radius))


func test_holding_the_stick_forward_walks_the_player_north() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: CharacterBody3D = street.get_node("%Player")
	var start := player.global_position
	_hold_stick_forward(street)
	await wait_frames(30)
	assert_lt(player.global_position.z, start.z - 0.5, "forward on the stick is north")


func test_holding_the_stick_forward_eventually_climbs_out_of_the_basin() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: CharacterBody3D = street.get_node("%Player")
	_hold_stick_forward(street)
	# Long enough to cross the basin, trigger the ledge and finish the climb.
	await wait_frames(260)
	assert_gt(player.global_position.y, -0.1, "the player is out of the basin at street level")
	assert_lt(player.global_position.z, -7.0, "and standing on the street beyond the wall")


func test_the_player_reaches_running_speed_while_crossing_the_block() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: CharacterBody3D = street.get_node("%Player")
	player.global_position = Vector3(0.0, 0.05, 30.0)
	_hold_stick_forward(street)
	await wait_frames(60)
	assert_true(player.is_running(), "a held full tilt becomes a run (GDD §6)")


func test_a_mover_faces_forward_along_its_travel() -> void:
	# The rig's body faces -Z, like the player's; a mover that turned +Z
	# toward its travel made every pedestrian walk backwards (owner report).
	var mover: Node3D = Node3D.new()
	mover.set_script(MOVER)
	mover.points = PackedVector3Array([Vector3(0, 0, 0), Vector3(10, 0, 0)])
	mover.speed = 1.0
	add_child_autofree(mover)
	await wait_frames(2)
	var forward: Vector3 = -mover.global_transform.basis.z
	assert_almost_eq(forward.x, 1.0, 0.01, "forward (-Z) points along the travel (+X)")
