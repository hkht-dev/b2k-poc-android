## The Street's forbidden colours (CLAUDE.md, GDD §10 Hollow Vale row):
## peacock blue and magenta, nowhere in the Street but the Glimpse's backlight
## and the feather it leaves. Walks every material, light, sign and the fog
## of scenes/street/Street.tscn as the Grove's test walks the Grove.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_street_colours_journey.json"
## The one exception (CLAUDE.md "The slice"): a node under a Glimpse, or a
## feather, may carry the peacock blue.
const EXCEPTIONS := ["Glimpse", "Feather"]
## The two bands as test_world_assets.gd draws them on the HSV wheel: peacock
## blue from 0.50 to 0.63, magenta from 0.78 to 0.93. The nature kit's bush
## (hue 0.48, aquamarine) sits just outside; docs/DECISIONS.md notes it.
const PEACOCK_BLUE := Vector2(0.5, 0.63)
const MAGENTA := Vector2(0.78, 0.93)
const SATURATION_FLOOR := 0.3

var _real_path := ""


func before_each() -> void:
	_real_path = GameState.save_path
	GameState.save_path = SCRATCH
	GameState.set_autosave(false)
	GameState.wipe()


func after_each() -> void:
	GameState.wipe()
	GameState.save_path = _real_path
	GameState.set_autosave(true)


func _is_forbidden(c: Color) -> bool:
	if c.v < 0.2 or c.s < SATURATION_FLOOR:
		return false
	var blue := c.h >= PEACOCK_BLUE.x and c.h <= PEACOCK_BLUE.y
	var magenta := c.h >= MAGENTA.x and c.h <= MAGENTA.y
	return blue or magenta


func _excepted(node: Node, root: Node) -> bool:
	var path := str(root.get_path_to(node))
	for word: String in EXCEPTIONS:
		if path.contains(word):
			return true
	return false


func _materials_of(geometry: GeometryInstance3D) -> Array[Material]:
	var out: Array[Material] = []
	if geometry.material_override != null:
		out.append(geometry.material_override)
	var mesh: Mesh = null
	var mesh_instance := geometry as MeshInstance3D
	var multi := geometry as MultiMeshInstance3D
	if mesh_instance != null:
		mesh = mesh_instance.mesh
	elif multi != null and multi.multimesh != null:
		mesh = multi.multimesh.mesh
	if mesh == null:
		return out
	for surface: int in mesh.get_surface_count():
		var material: Material = null
		if mesh_instance != null:
			material = mesh_instance.get_surface_override_material(surface)
		if material == null:
			material = mesh.surface_get_material(surface)
		if material != null:
			out.append(material)
	return out


func test_no_colour_on_the_street_is_peacock_blue_or_magenta() -> void:
	assert_true(_is_forbidden(Color(0.05, 0.42, 0.55)), "the feather's peacock blue would fail")
	assert_true(_is_forbidden(Color(0.85, 0.1, 0.8)), "magenta would fail")
	assert_false(_is_forbidden(Color(0.86, 0.6, 0.2)), "ochre is the Street's own")
	var street: Node3D = add_child_autofree(STREET.instantiate())
	await wait_frames(2)
	var checked := 0
	for node: Node in street.find_children("*", "GeometryInstance3D", true, false):
		if _excepted(node, street):
			continue
		var geometry := node as GeometryInstance3D
		for material: Material in _materials_of(geometry):
			var standard := material as StandardMaterial3D
			if standard == null:
				continue
			checked += 1
			assert_false(
				_is_forbidden(standard.albedo_color),
				"%s wears a forbidden colour %s" % [street.get_path_to(node), standard.albedo_color]
			)
		var label := node as Label3D
		if label != null:
			checked += 1
			assert_false(
				_is_forbidden(label.modulate), "%s is written in a forbidden colour" % node.name
			)
	for node: Node in street.find_children("*", "Light3D", true, false):
		if _excepted(node, street):
			continue
		var light := node as Light3D
		checked += 1
		assert_false(
			_is_forbidden(light.light_color),
			"%s shines a forbidden colour" % street.get_path_to(node)
		)
	var environment: Environment = street.get_node("Environment").environment
	assert_false(_is_forbidden(environment.fog_light_color), "the fog")
	assert_false(_is_forbidden(environment.ambient_light_color), "the ambient")
	assert_gt(checked, 100, "the walk saw the street")
