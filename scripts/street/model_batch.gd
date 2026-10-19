## Draws one imported model many times for the price of one.
##
## The street's dressing — Kenney cars and trees, Poly Haven lamps, benches,
## hydrants and litter (docs/RIGHTS_REGISTER.md) — comes as .glb scenes. A
## scene instanced twenty times is twenty sets of draw calls; this node
## instantiates the scene once, lifts out its meshes, and draws each as a
## MultiMesh with the transforms given here: one draw call per surface
## however many lamps the pavement has (docs/BRIEF_AMENDMENT_1.md §B3, §C).
##
## Collision is not this node's business: tools/gen_street.py places plain
## StaticBody3D colliders next to it where a prop should stop the player.
class_name ModelBatch
extends Node3D

const FLOATS_PER_INSTANCE := 12

## The imported .glb (or any scene made of MeshInstance3D nodes).
@export var scene: PackedScene
## One 3x4 transform per instance, row by row, the layout MultiMesh uses:
## bx.x, by.x, bz.x, o.x, bx.y, by.y, bz.y, o.y, bx.z, by.z, bz.z, o.z.
@export var transforms: PackedFloat32Array = PackedFloat32Array()
@export var cast_shadow := true

var _instance_count := 0


func _ready() -> void:
	if scene == null:
		return
	var prototype: Node = scene.instantiate()
	var placements := instance_transforms()
	_instance_count = placements.size()
	for mesh_instance: MeshInstance3D in _mesh_instances(prototype, prototype):
		var local: Transform3D = local_transform_within(mesh_instance, prototype)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh_instance.mesh
		multimesh.instance_count = placements.size()
		for i: int in placements.size():
			multimesh.set_instance_transform(i, placements[i] * local)
		var node := MultiMeshInstance3D.new()
		node.name = mesh_instance.name
		node.multimesh = multimesh
		node.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if cast_shadow
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		for surface: int in mesh_instance.get_surface_override_material_count():
			var override := mesh_instance.get_surface_override_material(surface)
			if override != null:
				node.set_surface_override_material(surface, override)
		add_child(node)
	prototype.free()


## How many copies of the model this batch draws.
func instance_count() -> int:
	return _instance_count


## The placements decoded from `transforms`, in order.
func instance_transforms() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var count := transforms.size() / FLOATS_PER_INSTANCE
	for i: int in count:
		var f := i * FLOATS_PER_INSTANCE
		var basis := Basis(
			Vector3(transforms[f], transforms[f + 4], transforms[f + 8]),
			Vector3(transforms[f + 1], transforms[f + 5], transforms[f + 9]),
			Vector3(transforms[f + 2], transforms[f + 6], transforms[f + 10])
		)
		var origin := Vector3(transforms[f + 3], transforms[f + 7], transforms[f + 11])
		out.append(Transform3D(basis, origin))
	return out


func _mesh_instances(node: Node, root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		found.append(mesh_instance)
	for child: Node in node.get_children():
		found.append_array(_mesh_instances(child, root))
	return found


## A mesh's transform relative to the prototype's root, before the scene is
## in the tree (global_transform is not available yet). Each instance draws
## the mesh at placement * this.
static func local_transform_within(node: Node3D, root: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		var spatial := current as Node3D
		if spatial != null:
			result = spatial.transform * result
		current = current.get_parent()
	return result
