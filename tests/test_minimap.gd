## The plain map of the block (scripts/ui/minimap.gd) and the footprints it
## hands the Path card. The footprints come from the street's own geometry by
## group and name, so a change to how the generator writes the street can
## empty them silently; this test stands in their way.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_minimap_journey.json"
## The groups minimap.gd walks, and roughly how much of the block they cover.
const LEAST_FOOTPRINTS := 12
## The fountain is at the origin, the shop west of it, the flats north.
const FOUNTAIN := Vector2(0.0, 0.0)

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


func _street() -> Node3D:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	return street


func _minimap(street: Node3D) -> Control:
	return street.get_node("%TouchControls").minimap()


func _covers(rects: Array[Dictionary], point: Vector2) -> bool:
	for entry: Dictionary in rects:
		if (entry["rect"] as Rect2).has_point(point):
			return true
	return false


func test_the_map_is_off_until_it_is_asked_for() -> void:
	var street := _street()
	await wait_frames(2)
	assert_false(_minimap(street).visible, "the HUD is empty by default (GDD §6)")
	assert_false(_minimap(street).enabled())


func test_the_footprints_are_read_from_the_street_itself() -> void:
	var street := _street()
	await wait_frames(2)
	var rects: Array[Dictionary] = _minimap(street).footprints()
	assert_gte(rects.size(), LEAST_FOOTPRINTS, "the block's buildings, roads and fountain")
	assert_true(_covers(rects, FOUNTAIN), "the fountain is on the map")
	var wide := false
	for entry: Dictionary in rects:
		if (entry["rect"] as Rect2).size.x > 40.0:
			wide = true
	assert_true(wide, "a road runs across the block")


func test_turning_it_on_shows_it_and_it_draws_without_a_marker() -> void:
	var street := _street()
	await wait_frames(2)
	var map: Control = _minimap(street)
	map.set_enabled(true)
	map.refresh_visibility()
	assert_true(map.visible, "the pause menu's switch shows it")
	assert_eq(map.get_child_count(), 0, "drawn with _draw: no marker node, no icon (GDD §6)")
	map.set_enabled(false)
	map.refresh_visibility()
	assert_false(map.visible)
