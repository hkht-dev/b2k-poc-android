## Tests the traveler's movement rules.
##
## GDD §6 "Movement and camera": auto-run after 0.5 s of full tilt, a
## context-sensitive climb, and no jump. The timings are design decisions, so
## they are asserted rather than left to feel.
extends GutTest

const PLAYER := preload("res://scenes/player/Player.tscn")
const STEP := 0.1


func _spawn() -> CharacterBody3D:
	var player: CharacterBody3D = add_child_autofree(PLAYER.instantiate())
	return player


## Drives the controller directly instead of awaiting 30 physics frames, so
## the timing assertions stay exact and the suite stays fast.
func _step(player: CharacterBody3D, seconds: float) -> void:
	var steps := int(round(seconds / STEP))
	for _i in steps:
		player._physics_process(STEP)


func test_walks_before_the_auto_run_delay() -> void:
	var player := _spawn()
	player.set_move_input(Vector2(0.0, -1.0))
	_step(player, player.AUTO_RUN_DELAY - 0.15)
	assert_false(player.is_running(), "still walking before 0.5 s of full tilt")


func test_runs_after_the_auto_run_delay() -> void:
	var player := _spawn()
	player.set_move_input(Vector2(0.0, -1.0))
	_step(player, player.AUTO_RUN_DELAY + 0.15)
	assert_true(player.is_running(), "running after 0.5 s of full tilt")


func test_a_half_tilt_never_becomes_a_run() -> void:
	var player := _spawn()
	player.set_move_input(Vector2(0.0, -0.5))
	_step(player, 3.0)
	assert_false(player.is_running(), "a gentle push walks, however long it is held")


func test_releasing_the_stick_resets_the_run_timer() -> void:
	var player := _spawn()
	player.set_move_input(Vector2(0.0, -1.0))
	_step(player, 0.4)
	player.set_move_input(Vector2.ZERO)
	_step(player, 0.2)
	player.set_move_input(Vector2(0.0, -1.0))
	_step(player, 0.3)
	assert_false(player.is_running(), "the timer starts again after the stick is let go")


func test_input_longer_than_one_is_clamped() -> void:
	var player := _spawn()
	player.set_move_input(Vector2(12.0, -9.0))
	_step(player, 0.1)
	assert_almost_eq(
		Vector2(player.velocity.x, player.velocity.z).length(),
		Vector2(player.velocity.x, player.velocity.z).length(),
		0.001
	)
	assert_lt(
		Vector2(player.velocity.x, player.velocity.z).length(),
		player.RUN_SPEED + 0.001,
		"an over-long input vector cannot outrun the run speed"
	)


func test_climb_lands_on_the_exit_and_reports_both_ends() -> void:
	var player := _spawn()
	player.global_position = Vector3(0.0, -1.0, 0.0)
	watch_signals(player)
	var exit := Vector3(0.0, 0.05, -6.6)

	assert_true(player.begin_climb(exit), "the climb starts")
	assert_signal_emitted(player, "climb_started")
	assert_true(player.is_climbing(), "and it is in progress")

	# Step only until the climb ends: once it does, ordinary gravity takes over
	# and this bare player has no floor under it to land on.
	var guard := 0
	while player.is_climbing() and guard < 100:
		player._physics_process(STEP)
		guard += 1
	assert_lt(guard, 100, "the climb ended rather than running forever")
	assert_false(player.is_climbing(), "the climb ends on its own")
	assert_signal_emitted(player, "climb_finished")
	assert_almost_eq(player.global_position.y, exit.y, 0.01, "it lands at street level")
	assert_almost_eq(player.global_position.z, exit.z, 0.01, "and clears the wall")


func test_a_second_climb_cannot_interrupt_one_in_progress() -> void:
	var player := _spawn()
	assert_true(player.begin_climb(Vector3(0.0, 0.0, -6.0)))
	assert_false(
		player.begin_climb(Vector3(20.0, 0.0, 0.0)), "overlapping ledges cannot stack climbs"
	)


func test_the_climb_lifts_before_it_travels() -> void:
	var player := _spawn()
	player.global_position = Vector3(0.0, -1.0, 0.0)
	player.begin_climb(Vector3(0.0, 0.05, -6.6))
	_step(player, player.CLIMB_DURATION * 0.4)
	var risen: float = player.global_position.y - (-1.0)
	var travelled: float = absf(player.global_position.z)
	assert_gt(risen, 0.4, "it is already rising early in the climb")
	assert_lt(travelled, 3.3, "before most of the forward travel happens")
