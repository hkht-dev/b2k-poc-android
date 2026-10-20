## Tests the growing world's placeholder textures, materials and sounds
## (tools/texture_parts/world.py, tools/audio_parts/world.py; GDD §5, §10),
## the player's footsteps and the door's sound.
extends GutTest

const PLAYER := preload("res://scenes/player/Player.tscn")
const DOOR := preload("res://scenes/places/Door.tscn")
const TEXTURES: Array[String] = [
	"grass",
	"river_bed",
	"tile_floor",
	"parquet",
	"fabric_print",
	"chalkboard",
	"paper",
	"stone_old",
	"bark_kadamba",
	"sari_red",
]
const LOOPS: Array[String] = [
	"footsteps_pavement", "footsteps_wood", "room_tone", "bird_calls", "river_loop", "swing_creak"
]
const ONE_SHOTS: Array[String] = ["door_open", "door_close", "shop_bell", "calf_moo"]
## docs/BRIEF_AMENDMENT_1.md §B1: 1024 or 2048; the generator uses 1024.
const MAX_TEXTURE_SIZE := 1024
const STEP := 0.1
## GDD §10, Hollow Vale row: the two forbidden hues, as ranges on the HSV
## wheel (0..1), and how saturated a colour must be to count as either.
const PEACOCK_BLUE := Vector2(0.5, 0.63)
const MAGENTA := Vector2(0.78, 0.93)
const SATURATION_FLOOR := 0.3
const SAMPLE_STRIDE := 16


func _step(player: CharacterBody3D, seconds: float) -> void:
	for _i in int(round(seconds / STEP)):
		player._physics_process(STEP)


func test_every_texture_exists_loads_and_is_within_1024() -> void:
	for name in TEXTURES:
		var path := "res://assets/textures/%s.png" % name
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		var texture := load(path) as Texture2D
		assert_not_null(texture, "%s loads as a texture" % name)
		if texture == null:
			continue
		assert_lte(texture.get_width(), MAX_TEXTURE_SIZE, "%s is at most 1024 px wide" % name)
		assert_lte(texture.get_height(), MAX_TEXTURE_SIZE, "%s is at most 1024 px high" % name)


func test_every_material_is_a_standard_material_with_its_texture() -> void:
	for name in TEXTURES:
		var path := "res://assets/materials/%s.tres" % name
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		var material := load(path) as StandardMaterial3D
		assert_not_null(material, "%s loads as a StandardMaterial3D" % name)
		if material == null:
			continue
		assert_not_null(material.albedo_texture, "%s carries its texture" % name)
		assert_true(material.uv1_triplanar, "%s tiles over scaled primitives" % name)


func test_every_sound_exists_and_loads() -> void:
	for name in LOOPS + ONE_SHOTS:
		var path := "res://assets/audio/%s.ogg" % name
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		var stream := load(path) as AudioStream
		assert_not_null(stream, "%s loads as a stream" % name)
		if stream != null:
			assert_gt(stream.get_length(), 0.3, "%s is not empty" % name)


func test_loops_loop_and_one_shots_do_not() -> void:
	for name in LOOPS:
		var stream := load("res://assets/audio/%s.ogg" % name) as AudioStreamOggVorbis
		assert_true(stream != null and stream.loop, "%s loops" % name)
	for name in ONE_SHOTS:
		var stream := load("res://assets/audio/%s.ogg" % name) as AudioStreamOggVorbis
		assert_true(stream != null and not stream.loop, "%s plays once" % name)


func test_no_texture_averages_peacock_blue_or_magenta() -> void:
	for name in TEXTURES:
		var image := Image.load_from_file(
			ProjectSettings.globalize_path("res://assets/textures/%s.png" % name)
		)
		assert_not_null(image, "%s can be read back" % name)
		if image == null:
			continue
		var sum := Color(0.0, 0.0, 0.0, 0.0)
		var count := 0
		for y in range(0, image.get_height(), SAMPLE_STRIDE):
			for x in range(0, image.get_width(), SAMPLE_STRIDE):
				sum += image.get_pixel(x, y)
				count += 1
		var average := sum / float(count)
		var blue := average.h >= PEACOCK_BLUE.x and average.h <= PEACOCK_BLUE.y
		var magenta := average.h >= MAGENTA.x and average.h <= MAGENTA.y
		assert_false(
			average.s >= SATURATION_FLOOR and (blue or magenta),
			(
				"%s averages hue %.2f, saturation %.2f: not peacock blue, not magenta"
				% [name, average.h, average.s]
			)
		)


func test_footsteps_play_while_moving_and_stop_when_still() -> void:
	var player: CharacterBody3D = add_child_autofree(PLAYER.instantiate())
	assert_false(player.is_footsteps_playing(), "quiet at rest")
	player.set_move_input(Vector2(0.0, -1.0))
	_step(player, 0.3)
	assert_true(player.is_footsteps_playing(), "the feet sound while walking")
	assert_almost_eq(
		player.footsteps_pitch(), player.FOOTSTEPS_WALK_PITCH, 0.001, "at walking pitch"
	)
	_step(player, player.AUTO_RUN_DELAY + 0.2)
	assert_true(player.is_running())
	assert_almost_eq(
		player.footsteps_pitch(),
		player.FOOTSTEPS_RUN_PITCH,
		0.001,
		"a run is the same loop, faster"
	)
	player.set_move_input(Vector2.ZERO)
	_step(player, 1.0)
	assert_false(player.is_footsteps_playing(), "and they stop when still")


func test_a_climb_silences_the_feet() -> void:
	var player: CharacterBody3D = add_child_autofree(PLAYER.instantiate())
	player.set_move_input(Vector2(0.0, -1.0))
	_step(player, 0.3)
	assert_true(player.is_footsteps_playing())
	player.begin_climb(player.global_position + Vector3(0.0, 1.0, -2.0))
	assert_false(player.is_footsteps_playing(), "no steps on a wall")


func test_holding_still_and_a_vault_silence_the_feet() -> void:
	var player: CharacterBody3D = add_child_autofree(PLAYER.instantiate())
	player.set_move_input(Vector2(0.0, -1.0))
	_step(player, 0.3)
	assert_true(player.is_footsteps_playing())
	player.hold_still(true)
	assert_false(player.is_footsteps_playing(), "no steps on the fitting dais")
	player.hold_still(false)
	_step(player, 0.3)
	assert_true(player.is_footsteps_playing(), "walking again")
	player._begin_vault(Vector3(0.0, 0.0, -1.0), player.global_position + Vector3(0.0, 0.5, -1.5))
	assert_false(player.is_footsteps_playing(), "no steps in the air")


func test_the_door_sounds_when_used() -> void:
	var door: Door = add_child_autofree(DOOR.instantiate())
	var player: Node3D = add_child_autofree(Node3D.new())
	watch_signals(door)
	assert_false(door.is_sound_playing(), "silent until used")
	door.use_area().use(player)
	assert_true(door.is_sound_playing(), "the door creaks open")
	assert_signal_emitted(door, "used_door")
