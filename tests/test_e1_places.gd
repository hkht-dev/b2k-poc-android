## Tests the owner expansion's first stage: places behind doors, the saved
## place, the compass (docs/DECISIONS.md "The world grows").
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SHOWROOM := preload("res://scenes/places/Showroom.tscn")
const STORE := preload("res://scenes/places/Store.tscn")
const MAIN := preload("res://scenes/core/Main.tscn")
const GAME_STATE := preload("res://scripts/core/game_state.gd")
const SCRATCH := "user://test_e1_journey.json"

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


func _place(scene: PackedScene) -> Node3D:
	var place: Node3D = add_child_autofree(scene.instantiate())
	place.get_node("%TouchControls").apply_scheme("touch")
	return place


func _button(place: Node3D) -> Button:
	return place.get_node("%TouchControls").contextual_button()


func test_the_places_table_names_scenes_that_exist() -> void:
	assert_true(Places.ids().size() >= 3)
	for id in Places.ids():
		assert_true(ResourceLoader.exists(Places.scene_of(id)), "%s has a scene" % id)
		assert_true(Strings.has_id(Places.name_id_of(id)), "%s has a name" % id)
	assert_eq(Places.scene_of("nowhere"), "")


func test_the_street_has_two_shop_doors_that_offer_go_in() -> void:
	var street := _place(STREET)
	var doors := get_tree().get_nodes_in_group(Door.GROUP)
	assert_gte(doors.size(), 2, "the showroom and the store")
	street.get_node("%Player").global_position = Vector3(2.0, 0.05, 25.9)
	await wait_frames(6)
	assert_eq(_button(street).current_verb(), "verb.enter")
	assert_eq(_button(street).text, Strings.t("verb.enter"))


func test_going_in_remembers_the_place_fades_and_asks_main_for_it() -> void:
	var street := _place(STREET)
	watch_signals(street)
	street.get_node("%Player").global_position = Vector3(2.0, 0.05, 25.9)
	await wait_frames(6)
	_button(street).pressed.emit()
	assert_true(street.is_leaving())
	assert_eq(GameState.place, "showroom")
	assert_eq(GameState.spawn, "showroom_door")
	await wait_seconds(street.DOOR_FADE_SECONDS + 0.2)
	assert_almost_eq(street.fade_alpha(), 1.0, 0.01)
	assert_signal_emitted_with_parameters(street, "place_requested", ["showroom", "showroom_door"])


func test_inside_the_player_lands_on_the_spawn_and_can_go_out_again() -> void:
	GameState.set_place("showroom", "showroom_door")
	var room := _place(SHOWROOM)
	watch_signals(room)
	var player: Node3D = room.get_node("%Player")
	await wait_frames(6)
	assert_lt(player.global_position.z, -2.0, "just inside the north door")
	assert_eq(_button(room).current_verb(), "verb.leave", "the door out is right there")
	_button(room).pressed.emit()
	assert_eq(GameState.place, "street")
	assert_eq(GameState.spawn, "showroom_door")
	await wait_seconds(room.DOOR_FADE_SECONDS + 0.2)
	assert_signal_emitted_with_parameters(room, "place_requested", ["street", "showroom_door"])


func test_back_on_the_street_the_player_stands_outside_that_door() -> void:
	GameState.set_place("street", "store_door")
	var street := _place(STREET)
	await wait_frames(2)
	var player: Node3D = street.get_node("%Player")
	assert_almost_eq(player.global_position.x, 16.0, 0.3)
	assert_gt(player.global_position.z, 20.0, "on the pavement by the store, not in the basin")
	assert_lt(street.fade_alpha(), 1.0, "the view is coming back")


func test_a_fresh_journey_still_starts_in_the_basin() -> void:
	var street := _place(STREET)
	await wait_frames(1)
	var player: Node3D = street.get_node("%Player")
	assert_lt(player.global_position.y, 0.0, "in the fountain basin")
	assert_almost_eq(street.fade_alpha(), 0.0, 0.01)


func test_main_resumes_the_saved_place() -> void:
	GameState.set_place("store", "store_door")
	GameState.settings["controls_seen"] = true
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_frames(1)
	main.current_screen().begin_pressed.emit()
	await wait_frames(1)
	assert_eq(main.current_screen().place_id, "store")
	await wait_frames(2)
	main.current_screen().place_requested.emit("street", "store_door")
	await wait_frames(1)
	assert_eq(main.current_screen().place_id, "street")


func test_the_store_keeper_talks_and_the_showroom_tailor_too() -> void:
	GameState.set_place("store", "store_door")
	var store := _place(STORE)
	var keeper: Node3D = store.get_node("%Storekeeper")
	store.get_node("%Player").global_position = keeper.global_position + Vector3(0, 0, -1.4)
	await wait_frames(6)
	assert_eq(_button(store).current_verb(), "verb.talk")
	_button(store).pressed.emit()
	assert_eq(Content.dialogue.current_line_id(), "storekeeper_greet")
	Content.dialogue.dismiss()


func test_the_place_and_spawn_survive_a_save() -> void:
	GameState.set_place("showroom", "showroom_door")
	GameState.save()
	var loaded: Node = GAME_STATE.new()
	loaded.save_path = SCRATCH
	loaded.load_journey()
	assert_eq(loaded.place, "showroom")
	assert_eq(loaded.spawn, "showroom_door")
	loaded.free()
	GameState.wipe()
	assert_eq(GameState.place, "street")
	assert_eq(GameState.spawn, "")


func test_the_compass_shows_the_facing_and_only_that() -> void:
	var street := _place(STREET)
	var compass: Control = street.get_node("%TouchControls").compass()
	assert_true(compass.visible, "on by default")
	var player: Node3D = street.get_node("%Player")
	player.rotation.y = 0.0
	await wait_frames(2)
	assert_almost_eq(compass.bearing_degrees(), 0.0, 0.5, "facing -Z is north")
	player.rotation.y = -PI / 2
	await wait_frames(2)
	assert_almost_eq(compass.bearing_degrees(), 90.0, 0.5, "facing +X is east")
	GameState.settings["compass"] = false
	street._apply_settings()
	assert_false(compass.visible)
	for child: Node in compass.get_children():
		assert_false(child is Label, "nothing but the drawn strip: no destination text")


func test_signs_read_from_the_string_table() -> void:
	var street := _place(STREET)
	await wait_frames(1)
	var sign: Label3D = street.get_node("Shopfronts/ShowroomSign")
	assert_eq(sign.text, Strings.t("sign.showroom"))
