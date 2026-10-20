## Tests the driveable car: *Drive* at the kerb, boarding, the stick as the
## wheel, *Get out*, the block-edge walls, and a HUD with no meter on it
## (owner request 2026-10-20; GDD §6; CLAUDE.md "never a meter").
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const CAR := preload("res://scenes/vehicles/Car.tscn")
const SCRATCH := "user://test_car_journey.json"
## On the road beside the parked car: inside its *Drive* reach.
const AT_THE_CAR := Vector3(-12.0, 0.2, 13.0)
const MOVE_ACTIONS := ["move_forward", "move_back", "move_left", "move_right"]
## A flag that offers a wisdom card (data/wisdom.json), to offer one at the wheel.
const CARD_FLAG := "gave_dry_fountain"

var _real_path := ""


func before_each() -> void:
	_real_path = GameState.save_path
	GameState.save_path = SCRATCH
	GameState.set_autosave(false)
	GameState.wipe()


func after_each() -> void:
	for action: String in MOVE_ACTIONS:
		Input.action_release(action)
	get_tree().paused = false
	GameState.wipe()
	GameState.save_path = _real_path
	GameState.set_autosave(true)


func _street() -> Node3D:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	return street


func _button(street: Node3D) -> Button:
	return street.get_node("%TouchControls").contextual_button()


## Stands the player at the car and waits for the button to notice.
func _walk_up(street: Node3D) -> void:
	street.get_node("%Player").global_position = AT_THE_CAR
	await wait_frames(6)


## Walks up and uses the button, as the player would.
func _board(street: Node3D) -> DriveableCar:
	await _walk_up(street)
	_button(street).pressed.emit()
	await wait_frames(2)
	return street.car()


## A bare floor for the car on its own: the kinematics without the street.
func _flat_world() -> Node3D:
	var world: Node3D = add_child_autofree(Node3D.new())
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position.y = -0.5
	world.add_child(ground)
	return world


func test_the_car_offers_drive_when_the_player_stands_at_it() -> void:
	var street := _street()
	var car: DriveableCar = street.get_node("%Car")
	assert_not_null(car, "the street parks a driveable car")
	assert_eq(car.enter_area().verb_id, "verb.drive", "the verb is data on the scene")
	await wait_frames(2)
	assert_ne(_button(street).current_verb(), "verb.drive", "not from the fountain")
	await _walk_up(street)
	assert_eq(_button(street).current_verb(), "verb.drive")
	assert_eq(_button(street).text, Strings.t("verb.drive"))


func test_boarding_hides_the_player_and_the_stick_drives_the_car() -> void:
	var street := _street()
	var player: CharacterBody3D = street.get_node("%Player")
	var car := await _board(street)
	assert_not_null(car, "the button boarded the player")
	assert_true(street.is_driving())
	assert_false(player.visible, "the player is inside the car")
	assert_eq(_button(street).current_verb(), car.exit_verb_id, "the button says Get out")
	assert_eq(_button(street).text, Strings.t("verb.exit"))
	var rig: Node3D = street.get_node("%CameraRig")
	assert_eq(rig.follow_profile(), rig.PROFILE_CAR, "the camera steps back to see the car")
	var start := car.global_position
	Input.action_press("move_forward")
	await wait_seconds(1.0)
	Input.action_release("move_forward")
	assert_gt(car.global_position.x, start.x + 1.0, "the car drove off east, its nose's way")
	assert_gt(car.speed(), 1.0, "and is still rolling")
	assert_lt(
		player.global_position.distance_to(car.global_position), 0.5, "the player rides along"
	)
	assert_almost_eq(street.heading(), car.rotation.y, 0.001, "the compass follows the car")


func test_steering_turns_the_car_and_the_engine_rises_with_speed() -> void:
	var world := _flat_world()
	var car: DriveableCar = CAR.instantiate()
	world.add_child(car)
	await wait_frames(2)
	var engine: AudioStreamPlayer3D = car.get_node("%Engine")
	assert_almost_eq(engine.pitch_scale, car.PITCH_IDLE, 0.001, "idle pitch at rest")
	car.start_driving()
	car.set_drive_input(Vector2(0.0, 1.0))
	await wait_seconds(1.0)
	assert_lt(car.global_position.z, -1.0, "forward on the stick is the nose's way, -Z")
	assert_almost_eq(car.global_position.x, 0.0, 0.05, "and straight")
	assert_gt(engine.pitch_scale, car.PITCH_IDLE + 0.1, "the engine rises with speed")
	assert_lte(engine.pitch_scale, car.PITCH_TOP)
	var yaw := car.rotation.y
	car.set_drive_input(Vector2(1.0, 1.0))
	await wait_seconds(0.5)
	assert_lt(wrapf(car.rotation.y - yaw, -PI, PI), -0.1, "right on the stick turns the nose right")
	car.set_drive_input(Vector2.ZERO)
	await wait_seconds(0.2)
	assert_gt(car.speed(), 0.5, "no stick: it coasts")
	car.set_drive_input(Vector2(0.0, -1.0))
	await wait_seconds(2.0)
	assert_between(car.speed(), -car.MAX_REVERSE - 0.1, -0.5, "back on the stick reverses, slowly")


func test_get_out_puts_the_player_beside_the_car_on_their_feet() -> void:
	var street := _street()
	var player: CharacterBody3D = street.get_node("%Player")
	var car := await _board(street)
	Input.action_press("move_forward")
	await wait_seconds(0.5)
	Input.action_release("move_forward")
	_button(street).pressed.emit()
	await wait_frames(3)
	assert_false(street.is_driving())
	assert_false(car.is_driving())
	assert_true(player.visible, "on their feet")
	assert_eq(player.collision_layer, 2, "and solid again")
	var beside := car.to_local(player.global_position)
	assert_almost_eq(absf(beside.x), car.DOOR_OFFSET, 0.3, "a step out from a door")
	assert_lt(absf(beside.z), 0.8, "level with the seat")
	var rig: Node3D = street.get_node("%CameraRig")
	assert_eq(rig.follow_profile(), rig.PROFILE_WALK)
	await wait_frames(4)
	assert_eq(_button(street).current_verb(), "verb.drive", "and could get back in")


func test_at_the_wheel_the_contextual_key_leaves_the_car_and_opens_no_card() -> void:
	var street := _street()
	await _board(street)
	assert_true(street.is_driving())
	GameState.set_flag(CARD_FLAG)
	await wait_frames(2)
	var lotus: Control = street.get_node("%TouchControls").lotus()
	assert_true(lotus.is_showing(), "a card is offered while driving")
	var press := InputEventAction.new()
	press.action = "contextual"
	press.pressed = true
	street._unhandled_input(press)
	assert_null(street.wisdom_card(), "the key is the car's: no card opens")
	assert_false(get_tree().paused)
	await wait_frames(3)
	assert_false(street.is_driving(), "the player got out")
	assert_true(lotus.is_showing(), "the offer stands")


func test_the_car_cannot_leave_the_block() -> void:
	var street := _street()
	var car: DriveableCar = street.get_node("%Car")
	# From the block's south-west, nose to the west edge, and floor it.
	car.global_position = Vector3(-58.0, 0.0, 40.0)
	car.rotation.y = PI / 2
	await wait_frames(2)
	street.board(car)
	Input.action_press("move_forward")
	await wait_seconds(3.0)
	Input.action_release("move_forward")
	assert_true(street.is_driving())
	assert_gt(car.global_position.x, -65.0, "the west wall held")
	assert_lt(absf(car.global_position.z), 45.0, "and the car is still on the block")
	assert_lt(absf(car.speed()), 0.5, "stopped against the wall")


func test_nothing_on_the_hud_is_a_meter_while_driving() -> void:
	var street := _street()
	var car := await _board(street)
	Input.action_press("move_forward")
	await wait_seconds(0.5)
	Input.action_release("move_forward")
	var digits := RegEx.create_from_string("[0-9]")
	for node: Node in street.get_node("UI").find_children("*", "Control", true, false):
		assert_false(node is Range, "%s is a meter" % node.get_path())
		if node is Label and node.is_visible_in_tree():
			assert_null(digits.search(node.text), "%s shows a number: %s" % [node.name, node.text])
		if node is Button and node.is_visible_in_tree():
			assert_null(digits.search(node.text), "%s shows a number: %s" % [node.name, node.text])
	assert_true(car.find_children("*", "Label3D", true, false).is_empty(), "no number on the car")


func test_no_hum_from_the_seat_and_pause_still_works() -> void:
	var street := _street()
	var car := await _board(street)
	assert_not_null(car)
	var hums: int = GameState.hum_count
	street.hum()
	assert_eq(GameState.hum_count, hums, "no hum while driving")
	assert_eq(street.get_node("%TouchControls").subtitle_text(), "")
	street.pause()
	assert_true(street.is_paused())
	assert_true(get_tree().paused, "the street stands still")
	# No awaits while paused: the tree is paused and GUT's frame waiter with it.
	_button(street).pressed.emit()
	assert_true(street.is_driving(), "Get out waits for the game to resume")
	street.resume()
	await wait_frames(1)
	assert_false(get_tree().paused)
	assert_true(street.is_driving())


func test_the_journey_records_no_seat() -> void:
	var street := _street()
	var before: Dictionary = GameState.to_dict()
	var car := await _board(street)
	assert_not_null(car)
	var after: Dictionary = GameState.to_dict()
	before.erase("play_seconds")
	after.erase("play_seconds")
	assert_eq(after, before, "boarding changes nothing in the journey (GDD §12)")


func test_the_verbs_and_the_controls_lines_are_in_the_string_table() -> void:
	assert_eq(Strings.t("verb.drive"), "Drive")
	assert_eq(Strings.t("verb.exit"), "Get out")
	for scheme: String in ["touch", "desktop", "gamepad"]:
		assert_true(Strings.has_id("controls.%s.drive" % scheme), "%s has a drive line" % scheme)


# -- where the player is put down (owner review 2026-10-20) --------------------


## Every candidate door point has to be clear of walls *and* over ground.
## Before the review the fallback was the left door whether or not anything
## was there, so getting out with the left side over a drop put the player
## into the fall they had just driven away from.
func test_the_door_point_is_over_ground_and_never_a_blind_fallback() -> void:
	var street := _street()
	var car: DriveableCar = street.get_node_or_null("%Car")
	assert_not_null(car, "the street has its car")
	await wait_frames(3)
	var point := car.door_point()
	var space := car.get_world_3d().direct_space_state
	var from := point + Vector3.UP * car.GROUND_PROBE_UP
	var down := PhysicsRayQueryParameters3D.create(
		from, from + Vector3.DOWN * (car.GROUND_PROBE_UP + car.GROUND_PROBE_DOWN), 1
	)
	down.exclude = [car.get_rid()]
	assert_false(space.intersect_ray(down).is_empty(), "there is road under the door point")


## With nothing under it at all, the car's own middle is the only place it
## can honestly put someone: it is standing there itself.
func test_with_no_ground_anywhere_the_player_is_put_where_the_car_is() -> void:
	var car: DriveableCar = add_child_autofree(CAR.instantiate())
	car.global_position = Vector3(0.0, 400.0, 0.0)
	await wait_frames(3)
	assert_eq(car.door_point(), car.global_position, "not a step out into nothing")
