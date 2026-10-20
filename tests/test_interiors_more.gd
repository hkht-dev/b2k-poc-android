## Tests the two more interiors: Dhanpal's office and Nanda's flat (GDD §5
## "four enterable interiors"), their street doors, the looks inside (GDD §7
## "Micro-interactions": a one-line thought each) and the missing string
## (GDD §7 "Mediate", step 3).
extends GutTest

## tools/check_data.py MAX_WORDS. GDD §8 kept a line under twenty words;
## the owner lifted it to thirty-four after the expansion, because the
## shorthand had stopped making sense (docs/DECISIONS.md "Conversations").
const LINE_WORD_CAP := 35

const STREET := preload("res://scenes/street/Street.tscn")
const OFFICE := preload("res://scenes/places/Office.tscn")
const NANDA := preload("res://scenes/places/NandaFlat.tscn")
const SCRATCH := "user://test_interiors_more_journey.json"
## The player's capsule radius (Player.tscn): a body at a point overlaps a
## reach box this much further out than the point itself.
const BODY_RADIUS := 0.34
## Street door node -> [place id, spawn id, which way the player faces on
## coming out], as the generators wrote them.
const DOORS := {
	"OfficeDoor/Door": ["office", "office_door", Vector3(0, 0, -1)],
	"NandaDoor/Door": ["nanda_flat", "nanda_door", Vector3(0, 0, 1)],
}

var _real_path := ""


func before_each() -> void:
	_real_path = GameState.save_path
	GameState.save_path = SCRATCH
	GameState.set_autosave(false)
	GameState.wipe()


func after_each() -> void:
	if Content.dialogue.is_running():
		Content.dialogue.dismiss()
	get_tree().paused = false
	GameState.wipe()
	GameState.save_path = _real_path
	GameState.set_autosave(true)


func _place(scene: PackedScene) -> Node3D:
	var place: Node3D = add_child_autofree(scene.instantiate())
	place.get_node("%TouchControls").apply_scheme("touch")
	return place


func _button(place: Node3D) -> Button:
	return place.get_node("%TouchControls").contextual_button()


## Stands the player at a point and gives physics time to notice the overlap.
func _stand_at(place: Node3D, point: Vector3) -> void:
	place.get_node("%Player").global_position = point
	await wait_frames(8)


func _spawn_named(place: Node3D, spawn_id: String) -> SpawnPoint:
	for node: Node in place.find_children("*", "Marker3D", true, false):
		if node is SpawnPoint and node.spawn_id == spawn_id:
			return node
	return null


func _facing(node: Node3D) -> Vector3:
	return -node.global_transform.basis.z


func _rooms() -> Array:
	return [[OFFICE, "office", "office_door"], [NANDA, "nanda_flat", "nanda_door"]]


func test_each_street_door_offers_go_in_and_leads_to_its_place() -> void:
	for door_path: String in DOORS:
		var place_id: String = DOORS[door_path][0]
		var spawn_id: String = DOORS[door_path][1]
		var street := _place(STREET)
		var door: Door = street.get_node(door_path)
		assert_eq(door.use_area().verb_id, "verb.enter", "%s offers Go in" % door_path)
		assert_eq(Strings.t(door.use_area().verb_id), "Go in")
		assert_true(door.use_area().is_available(), "with nothing required first")
		assert_eq(door.place_id, place_id)
		assert_eq(door.spawn_id, spawn_id)
		assert_true(Places.has(place_id), "'%s' is in data/places.json" % place_id)
		assert_true(ResourceLoader.exists(Places.scene_of(place_id)), "and its scene exists")
		watch_signals(street)
		door.use_area().use(street.get_node("%Player"))
		assert_eq(GameState.place, place_id, "the journey is on its way to %s" % place_id)
		assert_eq(GameState.spawn, spawn_id)
		await wait_seconds(street.DOOR_FADE_SECONDS + 0.3)
		assert_signal_emitted_with_parameters(street, "place_requested", [place_id, spawn_id])
		street.queue_free()
		await wait_frames(1)


func test_the_street_spawns_the_player_outside_each_door_within_its_reach() -> void:
	var street := _place(STREET)
	for door_path: String in DOORS:
		var spawn_id: String = DOORS[door_path][1]
		var facing: Vector3 = DOORS[door_path][2]
		var door: Door = street.get_node(door_path)
		var point := _spawn_named(street, spawn_id)
		assert_not_null(point, "the street has a spawn point '%s'" % spawn_id)
		if point == null:
			continue
		var offset := point.global_position - door.global_position
		assert_lt(absf(offset.x), door.reach.x * 0.5, "%s: beside the door" % spawn_id)
		assert_lt(
			absf(offset.z), door.reach.z * 0.5 + BODY_RADIUS, "%s: within its reach" % spawn_id
		)
		assert_almost_eq(
			_facing(point).dot(facing), 1.0, 0.01, "%s faces away from the door" % spawn_id
		)


func test_each_room_spawns_the_player_at_its_spawn_and_the_door_back_leads_to_the_street() -> void:
	for entry: Array in _rooms():
		var scene: PackedScene = entry[0]
		var place_id: String = entry[1]
		var spawn_id: String = entry[2]
		GameState.set_place(place_id, spawn_id)
		var place := _place(scene)
		assert_eq(place.place_id, place_id)
		var player: CharacterBody3D = place.get_node("%Player")
		var point := _spawn_named(place, spawn_id)
		assert_not_null(point, "%s has a spawn point '%s'" % [place_id, spawn_id])
		if point == null:
			continue
		assert_lt(
			player.global_position.distance_to(point.global_position),
			0.05,
			"%s: the player arrives on the spawn point" % place_id
		)
		assert_almost_eq(_facing(player).dot(Vector3(0, 0, 1)), 1.0, 0.01, "facing into the room")
		await wait_frames(8)
		var door: Door = place.get_node("Room/DoorOut")
		assert_eq(door.place_id, "street", "the door back leads to the street")
		assert_eq(door.spawn_id, spawn_id, "with the same spawn id as the door outside")
		assert_eq(door.use_area().verb_id, "verb.leave")
		assert_eq(_button(place).current_verb(), "verb.leave", "%s: Go out at the spawn" % place_id)
		watch_signals(place)
		_button(place).pressed.emit()
		assert_eq(GameState.place, "street")
		assert_eq(GameState.spawn, spawn_id)
		await wait_seconds(place.DOOR_FADE_SECONDS + 0.3)
		assert_signal_emitted_with_parameters(place, "place_requested", ["street", spawn_id])
		place.queue_free()
		await wait_frames(1)


func test_looking_at_the_office_lock_says_a_thought_and_sets_its_flag() -> void:
	var office := _place(OFFICE)
	var lock: Node3D = office.get_node("Fittings/LockLook")
	await _stand_at(office, lock.global_position + Vector3(0, 0.05, 0))
	assert_eq(_button(office).current_verb(), "verb.look")
	assert_false(GameState.has_flag("noticed_office_lock"))
	_button(office).pressed.emit()
	assert_eq(Content.dialogue.current_line_id(), "office_lock_look")
	assert_true(GameState.has_flag("noticed_office_lock"), "the line's own sets")
	var line := Content.dialogue.get_line("office_lock_look")
	assert_eq(line["speaker"], "thought")
	assert_true(line["cards"].is_empty(), "a thought offers no cards")
	Content.dialogue.dismiss()


func test_each_photograph_of_the_tower_has_a_thought_of_its_own() -> void:
	var office := _place(OFFICE)
	var seen := {}
	for i in 3:
		var photo: Node3D = office.get_node("Fittings/PhotoLook%d" % i)
		var line_id: String = photo.line_id
		assert_true(Content.dialogue.has_line(line_id), "'%s' is a dialogue line" % line_id)
		var line := Content.dialogue.get_line(line_id)
		assert_eq(line["speaker"], "thought")
		assert_true(line["cards"].is_empty())
		assert_lt(Strings.t(line["text_id"]).split(" ").size(), LINE_WORD_CAP, "inside the cap")
		assert_false(seen.has(line_id), "each photograph its own thought")
		seen[line_id] = true
	var middle: Node3D = office.get_node("Fittings/PhotoLook1")
	await _stand_at(office, middle.global_position + Vector3(0, 0.05, 0))
	assert_eq(_button(office).current_verb(), "verb.look")
	_button(office).pressed.emit()
	assert_eq(Content.dialogue.current_line_id(), middle.line_id)
	Content.dialogue.dismiss()


func test_looking_at_the_brothers_photograph_sets_its_flag() -> void:
	var flat := _place(NANDA)
	var photo: Node3D = flat.get_node("Fittings/PhotoLook")
	await _stand_at(flat, photo.global_position + Vector3(0, 0.05, 0))
	assert_eq(_button(flat).current_verb(), "verb.look")
	assert_false(GameState.has_flag("saw_brothers_photo"))
	_button(flat).pressed.emit()
	assert_eq(Content.dialogue.current_line_id(), "nanda_photo_look")
	assert_true(GameState.has_flag("saw_brothers_photo"))
	Content.dialogue.dismiss()


func test_picking_up_the_string_sets_the_flag_and_the_player_carries_it() -> void:
	var flat := _place(NANDA)
	var player: CharacterBody3D = flat.get_node("%Player")
	assert_true(player.carryables.has("string"), "Player.tscn knows the string")
	var pickup: Node3D = flat.get_node("%StringPickup")
	assert_true(pickup.visible, "the string lies on the shelf")
	var shelf_front := Vector3(pickup.global_position.x, 0.05, pickup.global_position.z - 0.7)
	await _stand_at(flat, shelf_front)
	assert_eq(_button(flat).current_verb(), "verb.pick_up")
	assert_false(GameState.has_flag("has_sarang_string"))
	_button(flat).pressed.emit()
	assert_true(GameState.has_flag("has_sarang_string"))
	assert_true(player.is_carrying("string"))
	assert_eq(player.carried_item(), "string")
	assert_false(pickup.visible, "the string left the shelf")
	assert_true(GameState.has_event("sarang_string_picked_up"))
	await wait_frames(2)
	assert_eq(
		_button(flat).current_verb(),
		"verb.put_down",
		"nothing more to pick up there, and the string can be set down again"
	)


func test_a_loaded_journey_does_not_lay_the_string_down_again() -> void:
	GameState.fire_event("sarang_string_picked_up")
	var flat := _place(NANDA)
	assert_false(flat.get_node("%StringPickup").visible)


func test_a_door_ends_the_line_on_the_cards() -> void:
	var street := _place(STREET)
	assert_true(Content.dialogue.start("fountain_look"))
	assert_true(Content.dialogue.is_running())
	street._on_door_used("store", "store_door")
	assert_false(
		Content.dialogue.is_running(),
		"the conversation does not follow the player through the door"
	)
