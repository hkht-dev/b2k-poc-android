## A plain top-down map of the block with the player's position and facing.
##
## Owner request after the P2 playtest ("a map to know where I am"). The GDD
## (§6 "What is deliberately absent") rules out a map *with markers*; this one
## has none — no quest, no objective, no Tulu — and is off by default, toggled
## from the pause menu. docs/DECISIONS.md records the trade.
##
## Built at runtime from the street's own geometry, so it is never out of date.
extends Control

const SETTING := "minimap"
const SIZE_PX := 300.0
## Metres of street per pixel.
const SCALE := 0.42
const PAPER := Color(0.957, 0.925, 0.847, 0.82)
const INK := Color(0.42, 0.31, 0.208, 0.9)
const ROAD := Color(0.45, 0.43, 0.4, 0.9)
const BLOCK := Color(0.62, 0.52, 0.34, 0.85)
const WATER := Color(0.7, 0.66, 0.58, 0.9)
const PLAYER := Color(0.2, 0.16, 0.1, 1.0)

var _street: Node3D = null
var _player: Node3D = null
var _rects: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	visible = enabled()


func _process(_delta: float) -> void:
	queue_redraw()


func bind(street: Node3D, player: Node3D) -> void:
	_street = street
	_player = player
	_collect()


static func enabled() -> bool:
	return GameState.settings.get(SETTING, false) == true


static func set_enabled(on: bool) -> void:
	GameState.settings[SETTING] = on
	GameState.save()


func refresh_visibility() -> void:
	visible = enabled()


## The footprints collected from the street, for anything else that draws
## the block (the Path card, GDD §16a).
func footprints() -> Array[Dictionary]:
	return _rects


## Footprints of the named groups, as world-space XZ rectangles.
func _collect() -> void:
	_rects.clear()
	if _street == null:
		return
	for entry: Array in [
		["Ground", ROAD, "Road"],
		["Fountain", WATER, "Wall"],
		["Shop", BLOCK, ""],
		["ChaiStall", BLOCK, "Body"],
		["Tower", BLOCK, "Block"],
		["Flats", BLOCK, "Flat"],
		["BusStop", INK, "Shelter"],
	]:
		var group: Node3D = _street.get_node_or_null(entry[0])
		if group == null:
			continue
		for child: Node in group.get_children():
			if not entry[2].is_empty() and not child.name.begins_with(entry[2]):
				continue
			if child.name.ends_with("Parapet") or child.name.contains("Kerb"):
				continue
			var mesh := _mesh_of(child)
			if mesh == null:
				continue
			var aabb: AABB = mesh.global_transform * mesh.get_aabb()
			_rects.append(
				{
					"rect": Rect2(aabb.position.x, aabb.position.z, aabb.size.x, aabb.size.z),
					"color": entry[1]
				}
			)


func _mesh_of(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
	return null


func _to_map(world_xz: Vector2) -> Vector2:
	var centre := Vector2.ZERO
	if _player != null:
		centre = Vector2(_player.global_position.x, _player.global_position.z)
	return Vector2(SIZE_PX * 0.5, SIZE_PX * 0.5) + (world_xz - centre) / SCALE


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX)), PAPER)
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX)), INK, false, 2.0)
	for entry in _rects:
		var r: Rect2 = entry["rect"]
		var a := _to_map(r.position)
		var b := _to_map(r.end)
		var rect := Rect2(a, b - a).abs().intersection(
			Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX))
		)
		if rect.size.x > 0.5 and rect.size.y > 0.5:
			draw_rect(rect, entry["color"])
	if _player == null:
		return
	var centre := Vector2(SIZE_PX * 0.5, SIZE_PX * 0.5)
	var facing := Vector2(-sin(_player.rotation.y), -cos(_player.rotation.y))
	draw_circle(centre, 6.0, PLAYER)
	draw_line(centre, centre + facing * 16.0, PLAYER, 3.0)
