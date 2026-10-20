## Nothing is carried for ever, and the can goes back into the fountain.
##
## Owner report 2026-10-20: "after taking up a can of water, there is no way
## to put the can back into the fountain. The loops are not complete." The
## fountain's reach stopped at the water, which only the first minute of the
## game can stand in; and `put_down()` was called by four destinations, so a
## feather, a flower, a gift fruit or a kept Veena stayed in the hand and
## withdrew every verb that wants an empty one.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_carry_loops_journey.json"
## Due east of the fountain on the pavement, outside the lip; the nearest
## other usable thing is six metres away.
const BESIDE_THE_FOUNTAIN := Vector3(8.0, 0.1, 0.0)
## Open road, far from anything usable.
const NOWHERE := Vector3(0.0, 0.05, 30.0)
## Every id in the player scene's `carryables`.
const ITEMS: Array[String] = ["can", "feather", "jasmine", "string", "fruit", "veena", "pot"]

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


func _button(street: Node3D) -> Button:
	return street.get_node("%TouchControls").contextual_button()


func _stand(street: Node3D, at: Vector3) -> CharacterBody3D:
	var player: CharacterBody3D = street.get_node("%Player")
	player.global_position = at
	await wait_frames(8)
	return player


# -- the can and the fountain -------------------------------------------------


func test_a_can_goes_into_the_fountain_from_the_pavement() -> void:
	var street := _street()
	GameState.set_flag("gopal_will_carry")
	var player: CharacterBody3D = await _stand(street, BESIDE_THE_FOUNTAIN)
	assert_true(player.carry("can"), "walking up with a can")
	await wait_frames(6)
	assert_eq(
		_button(street).current_verb(),
		"verb.place",
		"the fountain is within reach from outside its lip"
	)
	_button(street).pressed.emit()
	await wait_frames(2)
	assert_false(player.is_carrying(), "the can left the hand")
	assert_true(GameState.has_event("can_placed_at_fountain"), "the fountain took it")


func test_the_basin_cannot_be_climbed_back_into_so_the_reach_has_to_leave_it() -> void:
	# The lip stands 0.6 m above the pavement, over the player's 0.36 m step,
	# and the one ClimbPoint faces out. If the reach stopped at the water the
	# verb could never be used again, which is what the owner met.
	var street := _street()
	var player: CharacterBody3D = street.get_node("%Player")
	var place: Area3D = street.get_node("%FountainPoint/Place")
	var shape: CollisionShape3D = place.get_node("Shape")
	assert_gt(
		(shape.shape as CylinderShape3D).radius,
		7.0,
		"the reach passes the lip at 7 m, so a player outside can use it"
	)
	player.global_position = BESIDE_THE_FOUNTAIN
	await wait_frames(8)
	assert_gt(player.global_position.y, -0.3, "standing on the pavement, not in the basin")


# -- anything can be set down -------------------------------------------------


func test_every_carryable_can_be_set_down_and_picked_up_again() -> void:
	var street := _street()
	var player: CharacterBody3D = await _stand(street, NOWHERE)
	for item: String in ITEMS:
		assert_true(player.carry(item), "took the %s" % item)
		await wait_frames(4)
		assert_eq(
			_button(street).current_verb(),
			"verb.put_down",
			"with a %s in hand and nothing near, the button sets it down" % item
		)
		_button(street).pressed.emit()
		await wait_frames(4)
		assert_false(player.is_carrying(), "the %s left the hand" % item)
		assert_eq(_button(street).current_verb(), "verb.pick_up", "and lies there to be picked up")
		_button(street).pressed.emit()
		await wait_frames(4)
		assert_true(player.is_carrying(item), "the %s is back in hand" % item)
		player.put_down()
		await wait_frames(2)


func test_a_hold_is_still_the_call_with_a_full_hand() -> void:
	var street := _street()
	var player: CharacterBody3D = await _stand(street, NOWHERE)
	player.carry("feather")
	await wait_frames(4)
	assert_eq(_button(street).current_verb(), "verb.put_down")
	var before: int = GameState.hum_count
	_button(street).hold_for(_button(street).HUM_HOLD + 0.1)
	await wait_frames(2)
	assert_gt(GameState.hum_count, before, "holding the button still hums")


func test_the_dawn_choice_is_offered_with_something_else_in_hand() -> void:
	var street := _street()
	GameState.set_flag("on_the_tower")
	var top: Node3D = street.get_node("%TowerTop")
	var player: CharacterBody3D = street.get_node("%Player")
	player.carry("feather")
	player.global_position = top.global_position + Vector3(0.0, 0.3, 0.0)
	await wait_frames(8)
	assert_eq(
		_button(street).current_verb(), "verb.look", "a feather does not cost the player the dawn"
	)


# -- the block has edges ------------------------------------------------------


func test_the_street_is_walled_so_nothing_falls_out_of_the_world() -> void:
	# The ground stops at x 65, z 45 and there is nothing under it; a walk
	# north past the flats, or four seconds of car, used to fall for ever.
	var street := _street()
	var bounds: Node3D = street.get_node("Ground/Bounds")
	assert_eq(bounds.get_child_count(), 4, "one wall on each side")
	var player: CharacterBody3D = street.get_node("%Player")
	player.global_position = Vector3(0.0, 0.3, -42.0)
	await wait_frames(4)
	for _i in 90:
		player.set_move_input(Vector2(0.0, -1.0), 1.0)
		await wait_frames(1)
	assert_lt(player.global_position.z, -41.0, "it walked north")
	assert_gt(player.global_position.z, -47.0, "and the edge stopped it")
	assert_gt(player.global_position.y, -2.0, "still on the ground, not falling")


func test_the_pause_menu_can_leave_the_journey() -> void:
	var street := _street()
	watch_signals(street)
	street.pause()
	street._pause_menu.get_node("%QuitButton").pressed.emit()
	assert_false(street.is_paused(), "the world is let go first")
	assert_signal_emitted(street, "quit_requested", "and Main is told to show the title")
