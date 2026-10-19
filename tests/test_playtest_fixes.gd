## Tests the fixes from the P2 phone playtest: the kerb step, ambience that
## yields and cannot be walked through, the pause button and the minimap.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const MOVER := preload("res://scripts/street/path_mover.gd")
const SCRATCH := "user://test_fixes_journey.json"

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


func _hold_forward(street: Node3D, screen_dir: Vector2) -> void:
	var controls: Control = street.get_node("%TouchControls")
	var stick: Control = controls.joystick()
	controls.size = Vector2(1080, 1920)
	stick.size = controls.size
	stick.try_claim(0, Vector2(220, 1500))
	stick.drag_to(0, Vector2(220, 1500) + screen_dir * stick.radius)


func test_the_player_steps_over_the_kerb_onto_the_road() -> void:
	# On the south pavement (z 21.5..24.5 is the kerb, 16 cm high), facing
	# north toward the road.
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: CharacterBody3D = street.get_node("%Player")
	player.global_position = Vector3(-10.0, 0.3, 26.0)
	await wait_frames(10)
	_hold_forward(street, Vector2(0.0, -1.0))
	await wait_frames(240)
	assert_lt(player.global_position.z, 20.0, "crossed the kerb onto the road")


func test_the_player_steps_up_from_the_road_onto_the_pavement() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: CharacterBody3D = street.get_node("%Player")
	player.global_position = Vector3(-10.0, 0.3, 16.0)
	await wait_frames(10)
	_hold_forward(street, Vector2(0.0, 1.0))
	await wait_frames(240)
	# The kerb strip is z 21.5..24.5 and 16 cm high; standing on it is the proof.
	assert_gt(player.global_position.z, 22.0, "up the kerb")
	assert_gt(player.global_position.y, 0.1, "and standing on it, not wedged below")


func test_a_wall_is_still_a_wall() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: CharacterBody3D = street.get_node("%Player")
	# Inside the basin, walking east into the 1.8 m wall (no climb point there).
	player.global_position = Vector3(5.0, -1.0, 0.0)
	await wait_frames(10)
	_hold_forward(street, Vector2(1.0, 0.0))
	await wait_frames(120)
	assert_lt(player.global_position.x, 6.5, "the step-up does not climb walls")


func test_a_mover_stops_for_the_player_in_its_lane_and_goes_on_after() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var player: CharacterBody3D = street.get_node("%Player")
	var mover: Node3D = autofree(MOVER.new())
	mover.points = PackedVector3Array([Vector3(-20, 0, 40), Vector3(20, 0, 40)])
	mover.speed = 2.0
	mover.yield_distance = 3.0
	mover.yield_width = 1.0
	street.add_child(mover)
	player.global_position = Vector3(-18.0, 0.05, 40.0)
	await wait_frames(40)
	var held := mover.global_position
	await wait_frames(30)
	assert_almost_eq(mover.global_position.x, held.x, 0.3, "it waits while the player blocks it")
	player.global_position = Vector3(-18.0, 0.05, 44.0)
	await wait_frames(60)
	assert_gt(mover.global_position.x, held.x + 0.5, "and goes on once the lane is clear")


func test_pedestrians_cannot_be_walked_through() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var ped: Node3D = street.get_node("Ambience/Pedestrian0")
	assert_not_null(ped.get_node_or_null("Body"), "a pedestrian carries a collision body")
	assert_true(ped.get_node("Body") is StaticBody3D)


func test_the_minimap_is_off_by_default_and_the_pause_menu_turns_it_on() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var minimap: Control = street.get_node("%TouchControls").minimap()
	assert_false(minimap.visible, "no map unless asked (GDD §6)")
	street.pause()
	street._pause_menu.get_node("%MapButton").pressed.emit()
	assert_true(minimap.enabled(), "the setting flipped")
	assert_true(minimap.visible, "and the map shows")
	street.resume()


func test_the_corner_button_pauses() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var controls: Control = street.get_node("%TouchControls")
	controls.pause_button().pressed.emit()
	assert_true(street.is_paused())
	street.resume()
