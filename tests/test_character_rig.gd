## Tests scripts/characters/character_rig.gd: a CC0 body, a skin and clips
## assembled into one animated human (docs/BRIEF_AMENDMENT_1.md §B4), driven
## by its own motion like the procedural walk it replaced.
extends GutTest

const CHARACTER := preload("res://scenes/characters/Character.tscn")
const STREET := preload("res://scenes/street/Street.tscn")
const PLAYER := preload("res://scenes/player/Player.tscn")


func _rig() -> CharacterRig:
	var rig: CharacterRig = add_child_autofree(CHARACTER.instantiate())
	return rig


func test_the_rig_builds_a_body_and_an_animation_player_with_the_three_clips() -> void:
	var rig := _rig()
	assert_not_null(rig.get_node_or_null("Body"), "the body scene is instanced")
	var player := rig.animation_player()
	assert_not_null(player)
	for state: String in ["idle", "walk", "run"]:
		assert_true(player.has_animation("clips/%s" % state), "clip '%s' is in the library" % state)
	assert_eq(player.get_animation("clips/idle").loop_mode, Animation.LOOP_LINEAR, "clips loop")
	assert_eq(rig.state(), "idle", "a rig at rest idles")


func test_the_body_stands_at_the_asked_height_facing_forward() -> void:
	var rig := _rig()
	var body: Node3D = rig.get_node("Body")
	assert_almost_eq(body.scale.y, rig.height / rig.body_height, 0.001)
	assert_almost_eq(absf(body.rotation.y), PI, 0.001, "Kenney's body faces +Z; turned to -Z")


func test_the_skin_is_painted_onto_every_surface() -> void:
	var rig := _rig()
	var painted := 0
	for mesh_instance: MeshInstance3D in rig._meshes(rig.get_node("Body")):
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material := (
				mesh_instance.get_surface_override_material(surface) as StandardMaterial3D
			)
			assert_not_null(material, "an override material")
			if material != null:
				assert_eq(material.albedo_texture, rig.skin)
				painted += 1
	assert_gt(painted, 0, "the body has at least one painted surface")


func test_moving_walks_then_runs_then_idles_again() -> void:
	var rig := _rig()
	await wait_frames(2)
	for i: int in 12:
		rig.global_position += Vector3(0.0, 0.0, -1.5 / 60.0)  # 1.5 m/s
		await wait_frames(1)
	assert_eq(rig.state(), "walk", "a walking pace plays the walk")
	assert_true(rig.animation_player().speed_scale > 0.0)
	for i: int in 12:
		rig.global_position += Vector3(0.0, 0.0, -4.6 / 60.0)  # 4.6 m/s
		await wait_frames(1)
	assert_eq(rig.state(), "run", "a running pace plays the run")
	await wait_frames(30)
	assert_eq(rig.state(), "idle", "standing still returns to idle")


func test_clips_are_shared_between_rigs() -> void:
	var a := _rig()
	var b := _rig()
	assert_same(
		a.animation_player().get_animation("clips/idle"),
		b.animation_player().get_animation("clips/idle"),
		"one Animation resource serves every rig built from the same clip"
	)


func test_a_rig_without_a_body_is_harmless() -> void:
	var rig := CharacterRig.new()
	add_child_autofree(rig)
	await wait_frames(2)
	assert_null(rig.animation_player())
	assert_eq(rig.state(), "")


func test_the_player_tulu_and_pedestrians_are_rigs() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	assert_true(street.get_node("%Player/Mesh") is CharacterRig, "the player")
	assert_true(street.get_node("%Tulu/Figure") is CharacterRig, "Tulu")
	assert_true(street.get_node("Ambience/Pedestrian0/Figure") is CharacterRig, "a pedestrian")
	var a: CharacterRig = street.get_node("Ambience/Pedestrian0/Figure")
	var b: CharacterRig = street.get_node("Ambience/Pedestrian1/Figure")
	assert_ne(a.skin, b.skin, "neighbouring pedestrians wear different skins")


func test_the_player_scene_stands_alone() -> void:
	var player: CharacterBody3D = add_child_autofree(PLAYER.instantiate())
	await wait_frames(2)
	assert_true(player.get_node("Mesh") is CharacterRig)
	assert_not_null(player.get_node_or_null("Mesh/Body"))
