## Tests rooftop running (GDD §3a "Hold to sprint; time jumps at ledges and
## cables", §16a): the stair leads up, a run off a roof vaults the gap to the
## next, a walk off it does not, a fall ends on the pavement with nothing
## lost, and the route's end sets `reached_rooftop` once.
##
## The street's own physics process is switched off in these tests so the
## stick can be driven straight into the player; everything else in the
## scene (physics, the rooftops, the reach point) runs as in play.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const PLAYER := preload("res://scenes/player/Player.tscn")
const REACH := preload("res://scripts/quest/reach_point.gd")
const SCRATCH := "user://test_rooftops_journey.json"
## The cap slab's top on Flat9 and Flat10 (tools/street_parts/rooftops.py).
const ROOF_Y := 7.4
const FLAT9_CLEAR := Vector3(1.0, 7.5, 32.0)

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
	# The place feeds the stick every physics frame; these tests hold it.
	street.set_physics_process(false)
	return street


func _player(street: Node3D) -> CharacterBody3D:
	return street.get_node("%Player")


## Waits, a frame at a time, until [param done] says so or [param frames]
## have passed. Returns whether it was done in time.
func _until(done: Callable, frames: int) -> bool:
	for _i in frames:
		if done.call():
			return true
		await wait_frames(1)
	return done.call()


func test_the_route_is_in_the_street() -> void:
	var street := _street()
	for part: String in ["Stair", "StairLanding", "CableA", "PolePlatform", "CableB", "Awning"]:
		assert_not_null(street.get_node_or_null("Rooftops/" + part), "the route has a %s" % part)
	assert_true(street.get_node("Rooftops/CableA").is_in_group("cable"), "cables are cables")
	var reach: Area3D = street.get_node("Rooftops/RooftopReach")
	assert_eq(reach.flag_set, "reached_rooftop", "the end's flag is data on the node")
	assert_eq(
		street.get_node("Rooftops/StairsSign").text,
		Strings.t("sign.stairs"),
		"the start is signed from the string table"
	)


func test_the_stair_leads_up() -> void:
	var street := _street()
	var player := _player(street)
	player.global_position = Vector3(-4.75, 0.25, 23.9)
	await wait_frames(2)
	player.set_move_input(Vector2(0.0, 1.0))
	var arrived := await _until(func() -> bool: return player.global_position.y > 6.0, 420)
	player.set_move_input(Vector2.ZERO)
	assert_true(arrived, "walking south up the stair carries the player above 6 m")
	assert_gt(player.global_position.y, 6.0)
	assert_lt(absf(player.global_position.x + 4.75), 1.0, "and keeps them on the stair")


func test_running_off_the_first_roof_vaults_onto_the_second() -> void:
	var street := _street()
	var player := _player(street)
	watch_signals(player)
	player.global_position = FLAT9_CLEAR
	await wait_frames(2)
	player.set_move_input(Vector2(1.0, 0.0))
	var landed := await _until(
		func() -> bool: return player.global_position.x > 10.5 and not player.is_vaulting(), 300
	)
	player.set_move_input(Vector2.ZERO)
	assert_true(landed, "the run carried the player east onto Flat10")
	assert_signal_emitted(player, "vault_started")
	assert_signal_emitted(player, "vault_finished")
	assert_gt(player.global_position.y, 6.0, "still a roof's height up")
	assert_gt(player.global_position.x, 10.0, "and past the gap")
	assert_signal_not_emitted(player, "stumbled")


func test_walking_off_the_roof_does_not_vault() -> void:
	var street := _street()
	var player := _player(street)
	watch_signals(player)
	player.global_position = Vector3(6.3, 7.5, 32.0)
	await wait_frames(2)
	player.set_move_input(Vector2(0.5, 0.0))
	var dropped := await _until(func() -> bool: return player.global_position.y < 1.0, 360)
	player.set_move_input(Vector2.ZERO)
	assert_true(dropped, "a walk off the edge drops the player")
	assert_signal_not_emitted(player, "vault_started")
	assert_false(player.is_running(), "it was a walk")


func test_falling_to_the_pavement_loses_nothing() -> void:
	var street := _street()
	var player := _player(street)
	watch_signals(player)
	GameState.set_flag("looked_dry_fountain")
	GameState.add_journey_line("journey.glimpse.traffic_light")
	GameState.play_seconds = 42.0
	var before := GameState.to_dict()
	player.global_position = Vector3(2.0, 7.5, 28.5)
	await wait_frames(2)
	player.set_move_input(Vector2(0.0, -0.5))
	var down := await _until(
		func() -> bool: return player.global_position.y < 0.5 and player.is_on_floor(), 360
	)
	player.set_move_input(Vector2.ZERO)
	assert_true(down, "the fall ends on the pavement")
	assert_signal_emitted(player, "stumbled", "a fall from a storey is a stumble")
	assert_true(player.is_stumbling(), "which holds the stick for a moment")
	await wait_seconds(player.STUMBLE_SECONDS + 0.2)
	assert_false(player.is_stumbling(), "and no longer")
	assert_almost_eq(player.global_position.y, 0.0, 0.25, "standing at street level")
	assert_true(player.is_on_floor())
	assert_eq(GameState.to_dict(), before, "nothing in the journey changed")
	assert_true(GameState.has_flag("looked_dry_fountain"))
	assert_false(player.is_vaulting())
	assert_false(player.is_climbing())


func test_the_cable_carries_a_run_to_the_pole_and_the_end_sets_the_flag() -> void:
	var street := _street()
	var player := _player(street)
	var reach: Area3D = street.get_node("Rooftops/RooftopReach")
	watch_signals(reach)
	var step: Node3D = street.get_node("Rooftops/CableStep")
	player.global_position = step.global_position + Vector3(0.0, 0.3, 0.0)
	await wait_frames(2)
	var platform: Node3D = street.get_node("Rooftops/PolePlatform")
	var to_pole := platform.global_position - player.global_position
	player.set_move_input(Vector2(to_pole.x, to_pole.z).normalized())
	var on_cable := await _until(func() -> bool: return player.is_on_cable(), 120)
	assert_true(on_cable, "the step leads onto the cable")
	var reached := await _until(func() -> bool: return GameState.has_flag("reached_rooftop"), 480)
	player.set_move_input(Vector2.ZERO)
	assert_true(reached, "balancing down the cable reaches the pole")
	assert_signal_emitted(reach, "reached")
	assert_gt(player.global_position.y, 5.5, "the player is up on the pole")


func test_the_reach_point_sets_its_flag_once() -> void:
	var point: Area3D = add_child_autofree(REACH.new())
	point.flag_set = "reached_rooftop"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	shape.shape = box
	point.add_child(shape)
	point.global_position = Vector3(100.0, 1.0, 100.0)
	watch_signals(point)
	var player: CharacterBody3D = add_child_autofree(PLAYER.instantiate())
	player.global_position = Vector3(100.0, 0.2, 100.0)
	await wait_frames(4)
	assert_true(GameState.has_flag("reached_rooftop"), "standing in it sets the flag")
	assert_signal_emit_count(point, "reached", 1)
	player.global_position = Vector3(120.0, 0.2, 100.0)
	await wait_frames(4)
	player.global_position = Vector3(100.0, 0.2, 100.0)
	await wait_frames(4)
	assert_signal_emit_count(point, "reached", 1, "coming back fires nothing")
	assert_true(GameState.has_flag("reached_rooftop"))
