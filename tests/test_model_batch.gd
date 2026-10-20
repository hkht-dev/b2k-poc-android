## Tests scripts/street/model_batch.gd: one imported model, many placements,
## one MultiMesh per surface. The street's lamps, trees, cars and litter are
## CC0 models (docs/RIGHTS_REGISTER.md) drawn this way to stay inside the
## draw-call budget of docs/BRIEF_AMENDMENT_1.md §C.
extends GutTest

const LAMP := preload("res://assets/thirdparty/polyhaven/models/street_lamp_01/street_lamp_01.glb")
const CAR := preload("res://assets/thirdparty/quaternius/realistic-car-pack/NormalCar1.glb")
const BUSH := preload("res://assets/thirdparty/kenney/nature-kit/plant_bushLarge.glb")
const STREET := preload("res://scenes/street/Street.tscn")


func _batch(scene: PackedScene, placements: Array[Transform3D]) -> ModelBatch:
	var batch := ModelBatch.new()
	batch.scene = scene
	var floats := PackedFloat32Array()
	for t: Transform3D in placements:
		for row: int in 3:
			floats.append(t.basis.x[row])
			floats.append(t.basis.y[row])
			floats.append(t.basis.z[row])
			floats.append(t.origin[row])
	batch.transforms = floats
	add_child_autofree(batch)
	return batch


func _mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		found.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		found.append_array(_mesh_instances(child))
	return found


func test_transforms_round_trip_through_the_buffer_layout() -> void:
	var placed := Transform3D(
		Basis.from_euler(Vector3(0.0, 1.2, 0.0)).scaled(Vector3(2, 2, 2)), Vector3(3, 0.16, -7)
	)
	var batch := _batch(LAMP, [Transform3D.IDENTITY, placed])
	var decoded := batch.instance_transforms()
	assert_eq(decoded.size(), 2)
	assert_true(
		decoded[1].is_equal_approx(placed), "the 12-float row layout decodes to the placement"
	)
	assert_eq(batch.instance_count(), 2)


func test_one_multimesh_per_mesh_in_the_model_however_many_copies() -> void:
	var placements: Array[Transform3D] = []
	for i: int in 20:
		placements.append(Transform3D(Basis.IDENTITY, Vector3(i * 3.0, 0.0, 0.0)))
	var batch := _batch(CAR, placements)
	var prototype: Node = CAR.instantiate()
	var meshes := _mesh_instances(prototype).size()
	prototype.free()
	assert_gt(meshes, 0, "the car has meshes")
	assert_eq(batch.get_child_count(), meshes, "twenty cars cost as many draw calls as one")
	for child: Node in batch.get_children():
		assert_true(child is MultiMeshInstance3D)
		assert_eq((child as MultiMeshInstance3D).multimesh.instance_count, 20)


func test_a_mesh_offset_inside_the_model_is_read_before_the_scene_is_in_the_tree() -> void:
	# Kenney's bush mesh sits under a parent node with its own offset; the
	# batch composes that offset with each placement rather than dropping it.
	# (The headless renderer does not store MultiMesh transforms, so the maths
	# is checked here and the composition is placement * local.)
	var prototype: Node = BUSH.instantiate()
	var found_offset := false
	for mesh_instance: MeshInstance3D in _mesh_instances(prototype):
		var local := ModelBatch.local_transform_within(mesh_instance, prototype)
		if not local.origin.is_zero_approx():
			found_offset = true
	prototype.free()
	assert_true(found_offset, "the bush mesh sits off the model's origin")


func test_a_nested_offset_composes_parent_then_child() -> void:
	var root := Node3D.new()
	var middle := Node3D.new()
	middle.position = Vector3(1, 0, 0)
	var leaf := MeshInstance3D.new()
	leaf.position = Vector3(0, 2, 0)
	root.add_child(middle)
	middle.add_child(leaf)
	assert_true(
		ModelBatch.local_transform_within(leaf, root).origin.is_equal_approx(Vector3(1, 2, 0))
	)
	root.free()


func test_an_empty_batch_is_harmless() -> void:
	var batch := ModelBatch.new()
	add_child_autofree(batch)
	assert_eq(batch.get_child_count(), 0)
	assert_eq(batch.instance_count(), 0)


func test_the_street_draws_its_lamps_trees_and_cars_as_batches() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var lamps: ModelBatch = street.get_node("Lamps/LampPosts")
	assert_gt(lamps.instance_count(), 10, "a block of lamp posts")
	assert_not_null(street.get_node_or_null("Dressing/Trees_tree_3"))
	assert_not_null(street.get_node_or_null("Dressing/ParkedCar0"))
	assert_not_null(
		street.get_node_or_null("Ambience/Vehicle0/Model"), "moving cars are the model too"
	)
	assert_not_null(street.get_node_or_null("Fountain/Lip"), "the fountain has a lip")
