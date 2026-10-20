## Tests the lamps (GDD §16a "Social: lamps", the player's own half): twelve
## preset lines as data, set from the pause menu where the player stands, sat
## by for the line, kept in the journey, eight to a place, fading after thirty
## play-days, and no network anywhere in the files that build them.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const STORE := preload("res://scenes/places/Store.tscn")
const SCRATCH := "user://test_lamps_journey.json"
## Everything the feature added or touched, read back for the network check.
const LAMP_FILES := [
	"res://data/lamp_lines.json",
	"res://scripts/core/lamp_lines.gd",
	"res://scripts/quest/lamp.gd",
	"res://scenes/quest/Lamp.tscn",
	"res://scripts/ui/lamp_lines_screen.gd",
	"res://scenes/ui/LampLinesScreen.tscn",
	"res://scripts/ui/pause_menu.gd",
	"res://scenes/ui/PauseMenu.tscn",
	"res://scripts/places/place.gd",
	"res://scripts/core/game_state.gd",
	"res://tests/test_lamps.gd",
]
## Where the street puts the player at a fresh start (scenes/street/Street.tscn).
const SPAWN := Vector3(2.4, -0.4, 2.0)

var _real_path := ""


func before_each() -> void:
	_real_path = GameState.save_path
	GameState.save_path = SCRATCH
	GameState.set_autosave(false)
	GameState.wipe()


func after_each() -> void:
	get_tree().paused = false
	get_tree().root.content_scale_factor = 1.0
	GameState.wipe()
	GameState.save_path = _real_path
	GameState.set_autosave(true)


func _street() -> Node3D:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	return street


func _record(place: String, line_id: String, x := 0.0, z := 0.0, lit_day := 0) -> Dictionary:
	return {"place": place, "x": x, "z": z, "line_id": line_id, "lit_day": lit_day}


func test_the_data_has_twelve_lines_each_in_the_string_table() -> void:
	var ids := LampLines.line_ids()
	assert_eq(ids.size(), 12, "twelve preset lines (GDD §16a)")
	for id in ids:
		assert_true(id.begins_with("lamp.line."), id)
		assert_true(Strings.has_id(id), "%s is in the string table" % id)
	assert_eq(Strings.t(ids[0]), "Someone was kind here")
	assert_true(ids.has("lamp.line.look_up"))
	assert_true(ids.has("lamp.line.kept_sorry"))
	assert_true(ids.has("lamp.line.sit_a_while"))
	assert_eq(LampLines.fade_days(), 30, "data: thirty play-days")
	assert_eq(LampLines.max_per_place(), 8)
	assert_true(Strings.has_id("pause.set_lamp"))
	assert_true(Strings.has_id("lamp.title"))
	assert_true(Strings.has_id("lamp.cancel"))


func test_the_pause_menu_opens_the_lines_screen_and_cancel_keeps_the_pause() -> void:
	var street := _street()
	await wait_frames(2)
	# No awaits while paused: the tree is paused and GUT's frame waiter with it.
	street.pause()
	var button: Button = street._pause_menu.get_node("%LampButton")
	assert_eq(button.text, "Set a lamp here")
	button.pressed.emit()
	var screen: Control = street.lamp_lines_overlay()
	assert_not_null(screen, "the lines screen opened from the pause menu")
	var buttons: Array = screen.line_buttons()
	assert_eq(buttons.size(), 12, "twelve big buttons")
	var ids := LampLines.line_ids()
	for i in buttons.size():
		var line_button := buttons[i] as Button
		assert_eq(line_button.text, Strings.t(ids[i]), "in the data's order")
		assert_false(line_button.tooltip_text.is_empty(), "every button carries its label")
		assert_gte(line_button.custom_minimum_size.y, 72.0, "big enough for a thumb")
	assert_true((buttons[0] as Button).has_focus(), "keyboard and gamepad start on the first")
	screen.get_node("%CancelButton").pressed.emit()
	assert_null(street.lamp_lines_overlay(), "Cancel closed it")
	assert_true(street.is_paused(), "and the pause menu is still there")
	assert_true(GameState.lamps.is_empty(), "no lamp was set")
	street.resume()
	await wait_frames(1)


func test_choosing_a_line_sets_a_lamp_where_the_player_stands_and_resumes() -> void:
	var street := _street()
	await wait_frames(3)
	var player: CharacterBody3D = street.get_node("%Player")
	var at := player.global_position
	street.pause()
	street._pause_menu.get_node("%LampButton").pressed.emit()
	var ids := LampLines.line_ids()
	(street.lamp_lines_overlay().line_buttons()[2] as Button).pressed.emit()
	assert_null(street.lamp_lines_overlay(), "the screen closed")
	assert_false(street.is_paused(), "and play resumed")
	assert_eq(GameState.lamps.size(), 1, "one lamp in the journey")
	var lamp: Dictionary = GameState.lamps[0]
	assert_eq(lamp["place"], "street", "the Place's place_id")
	assert_eq(lamp["line_id"], ids[2], "the line that was chosen")
	assert_almost_eq(float(lamp["x"]), at.x, 0.01)
	assert_almost_eq(float(lamp["z"]), at.z, 0.01)
	assert_eq(int(lamp["lit_day"]), 0)
	var lamps: Array = street.lamps()
	assert_eq(lamps.size(), 1, "a Lamp node appeared")
	await wait_frames(3)
	var node: Node3D = lamps[0]
	assert_eq(node.line_id(), ids[2])
	assert_almost_eq(node.global_position.x, at.x, 0.01)
	assert_almost_eq(node.global_position.z, at.z, 0.01)
	assert_almost_eq(node.global_position.y, at.y, 0.5, "settled on the ground at the feet")
	var light: OmniLight3D = node.light()
	assert_almost_eq(light.omni_range, 3.0, 0.01, "a small light, 3 m")
	assert_false(light.shadow_enabled)
	assert_gt(light.light_color.r, light.light_color.b, "warm: never peacock blue")
	assert_gt(light.light_color.g, light.light_color.b, "never magenta")


func test_sitting_by_a_lamp_shows_its_line_and_the_player_sits_until_they_move() -> void:
	var line := LampLines.line_ids()[3]
	var lamp_at := SPAWN + Vector3(1.6, 0.0, 0.0)
	GameState.set_lamp(_record("street", line, lamp_at.x, lamp_at.z), 8)
	var street := _street()
	var player: CharacterBody3D = street.get_node("%Player")
	player.global_position = lamp_at + Vector3(0.3, 0.7, 0.3)
	await wait_frames(8)
	var lamps: Array = street.lamps()
	assert_eq(lamps.size(), 1, "the journey's lamp stands in the street")
	var button: Button = street.get_node("%TouchControls").contextual_button()
	assert_eq(button.current_verb(), "verb.sit")
	button.pressed.emit()
	await wait_frames(2)
	var controls: Control = street.get_node("%TouchControls")
	assert_eq(controls.subtitle_text(), Strings.t(line), "the lamp's line, as a subtitle")
	var rig: CharacterRig = street.get_node("%Player/Mesh")
	assert_eq(rig.state(), "pose", "the player sits")
	assert_true(lamps[0].is_sat())
	assert_ne(button.current_verb(), "verb.sit", "no Sit while sitting")
	player.walk_to(SPAWN)
	await wait_frames(12)
	assert_false(lamps[0].is_sat(), "moving stands the player up")
	assert_ne(rig.state(), "pose")


func test_lamps_survive_save_and_load_and_reappear_in_their_own_place_only() -> void:
	var ids := LampLines.line_ids()
	GameState.set_lamp(_record("street", ids[0], 1.0, 2.0), 8)
	GameState.set_lamp(_record("store", ids[1], 0.5, -1.0), 8)
	GameState.save()
	GameState.lamps.clear()
	assert_true(GameState.load_journey(), "the slot was there")
	assert_eq(GameState.lamps.size(), 2, "both lamps came back")
	assert_eq(GameState.lamps[0]["place"], "street")
	assert_eq(GameState.lamps[1]["line_id"], ids[1])
	var street := _street()
	await wait_frames(2)
	var in_street: Array = street.lamps()
	assert_eq(in_street.size(), 1, "the street shows its own lamp only")
	assert_eq(in_street[0].line_id(), ids[0])
	street.free()
	var store: Node3D = add_child_autofree(STORE.instantiate())
	await wait_frames(2)
	var in_store: Array = store.lamps()
	assert_eq(in_store.size(), 1, "the store shows its own lamp only")
	assert_eq(in_store[0].line_id(), ids[1])


func test_the_ninth_lamp_in_a_place_replaces_the_oldest_there() -> void:
	var ids := LampLines.line_ids()
	var most := LampLines.max_per_place()
	GameState.set_lamp(_record("store", ids[11]), most)
	for i in 9:
		GameState.set_lamp(_record("street", ids[i], float(i), 0.0), most)
	var in_street := GameState.lamps_in("street")
	assert_eq(in_street.size(), 8, "eight to a place")
	assert_eq(in_street[0]["line_id"], ids[1], "the oldest went out")
	assert_eq(in_street[7]["line_id"], ids[8], "the newest stands")
	assert_eq(GameState.lamps_in("store").size(), 1, "another place's lamp is untouched")
	var street := _street()
	await wait_frames(2)
	assert_eq(street.lamps().size(), 8)


func test_a_lamp_fades_after_thirty_play_days() -> void:
	var ids := LampLines.line_ids()
	var old := _record("street", ids[0], 2.0, 2.0, 0)
	assert_true(LampLines.is_lit(old), "lit on the day it was set")
	GameState.play_seconds = 29.5 * LampLines.seconds_per_day()
	assert_true(LampLines.is_lit(old), "still burning on day 29")
	GameState.play_seconds = 30.0 * LampLines.seconds_per_day()
	assert_false(LampLines.is_lit(old), "gone on day 30")
	var fresh := _record("street", ids[1], -2.0, 2.0, LampLines.play_day())
	assert_true(LampLines.is_lit(fresh))
	GameState.set_lamp(old, 8)
	GameState.set_lamp(fresh, 8)
	var street := _street()
	await wait_frames(2)
	var lamps: Array = street.lamps()
	assert_eq(lamps.size(), 1, "only the lamp that still burns stands")
	assert_eq(lamps[0].line_id(), ids[1])


func test_no_network_code_in_the_lamp_files() -> void:
	# Spelt in two halves so this file passes its own check.
	var needles := ["ht" + "tp", "sock" + "et", "pack" + "et_peer", "t" + "ls"]
	for path: String in LAMP_FILES:
		assert_true(FileAccess.file_exists(path), path)
		var text := FileAccess.get_file_as_string(path).to_lower()
		for needle: String in needles:
			assert_false(text.contains(needle), "%s has no '%s'" % [path, needle])


func test_a_lamp_set_on_a_landing_keeps_its_height() -> void:
	var street := _street()
	await wait_frames(3)
	var player: CharacterBody3D = street.get_node("%Player")
	var landing: Node3D = street.get_node("Tower/Landing1")
	player.global_position = landing.global_position + Vector3(0.0, 0.3, 0.0)
	await wait_frames(4)
	var at := player.global_position
	assert_gt(at.y, 2.0, "standing on the landing")
	street.pause()
	street._pause_menu.get_node("%LampButton").pressed.emit()
	(street.lamp_lines_overlay().line_buttons()[0] as Button).pressed.emit()
	assert_almost_eq(float(GameState.lamps[0]["y"]), at.y, 0.01, "the record keeps the height")
	await wait_frames(3)
	var node: Node3D = street.lamps()[0]
	assert_almost_eq(
		node.global_position.y, at.y, 0.6, "the lamp is on the landing, not in the tower's foot"
	)
