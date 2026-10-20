## Tests trying clothes on in the showroom (owner request 2026-10-20): the
## stand's verb, the wardrobe's buttons from data/outfits.json, the live
## repaint of the player's body, and the outfit riding in the journey file.
extends GutTest

const SHOWROOM := preload("res://scenes/places/Showroom.tscn")
const STREET := preload("res://scenes/street/Street.tscn")
const STAND := preload("res://scenes/quest/TryOnStand.tscn")
const WARDROBE := preload("res://scenes/ui/WardrobeScreen.tscn")
const PLAYER := preload("res://scenes/player/Player.tscn")
const GAME_STATE := preload("res://scripts/core/game_state.gd")
const SCRATCH := "user://test_wardrobe_journey.json"
## Where the fitting dais stands in the showroom (tools/gen_interiors.py).
const DAIS := Vector3(4.3, 0.25, 3.2)
const SKATER := "skater_female_a"
const COAT := "survivor_male_b"

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


func _showroom() -> Node3D:
	var room: Node3D = add_child_autofree(SHOWROOM.instantiate())
	room.get_node("%TouchControls").apply_scheme("touch")
	return room


func _on_dais(room: Node3D) -> void:
	room.get_node("%Player").global_position = DAIS
	await wait_frames(8)


## The texture actually painted on the body, not just the rig's export.
func _painted(rig: CharacterRig) -> Texture2D:
	var mesh_instance: MeshInstance3D = rig._meshes(rig.get_node("Body"))[0]
	var material := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	return material.albedo_texture if material != null else null


# -- the data -----------------------------------------------------------------


func test_the_outfit_data_lists_every_kenney_skin_with_a_name_and_a_file() -> void:
	var ids := Outfits.ids()
	assert_eq(ids.size(), 7, "the seven skins of tools/scenegen.py SKIN_PATH")
	assert_true(ids.has(Outfits.default_id()), "the default is one of them")
	var skins := {}
	for outfit_id in ids:
		var name_id := Outfits.name_id_of(outfit_id)
		assert_true(Strings.has_id(name_id), "%s has a name in the string table" % outfit_id)
		assert_false(Strings.t(name_id).is_empty())
		var path := Outfits.skin_path_of(outfit_id)
		assert_true(path.begins_with("res://assets/thirdparty/kenney/"), "a CC0 skin")
		assert_true(ResourceLoader.exists(path), "%s's skin exists" % outfit_id)
		assert_not_null(Outfits.skin_of(outfit_id))
		skins[path] = true
	assert_eq(skins.size(), ids.size(), "no two outfits share a skin")
	assert_null(Outfits.skin_of(""), "no outfit named: the scene's skin")
	assert_null(Outfits.skin_of("no_such_outfit"))
	assert_false(Outfits.has("no_such_outfit"))


func test_the_default_outfit_is_the_skin_the_player_scene_wears() -> void:
	var player: CharacterBody3D = add_child_autofree(PLAYER.instantiate())
	await wait_frames(1)
	var rig: CharacterRig = player.get_node("%Mesh")
	assert_eq(rig.skin.resource_path, Outfits.skin_path_of(Outfits.default_id()))
	assert_eq(GameState.outfit, "", "a fresh journey names no outfit")


# -- the stand ----------------------------------------------------------------


func test_the_stand_offers_try_on() -> void:
	var stand: Node3D = add_child_autofree(STAND.instantiate())
	assert_eq(stand.use_area().verb_id, "verb.try_on")
	assert_true(stand.use_area().is_available())
	assert_eq(Strings.t("verb.try_on"), "Try on")
	assert_false(stand.is_open())


func test_standing_on_the_showroom_dais_offers_try_on() -> void:
	var room := _showroom()
	assert_not_null(room.get_node_or_null("%TryOnStand"), "the generator placed the stand")
	assert_not_null(room.get_node_or_null("Fittings/Dais"), "on a round plinth")
	var button: Button = room.get_node("%TouchControls").contextual_button()
	await wait_frames(4)
	assert_ne(button.current_verb(), "verb.try_on", "not from the door")
	await _on_dais(room)
	assert_eq(button.current_verb(), "verb.try_on")


# -- the screen ---------------------------------------------------------------


func test_the_screen_lists_every_outfit_from_the_data_by_name_and_nothing_else() -> void:
	var screen: Control = add_child_autofree(WARDROBE.instantiate())
	await wait_frames(1)
	var buttons: Array[Button] = screen.outfit_buttons()
	assert_eq(buttons.size(), Outfits.ids().size(), "one button per outfit")
	assert_eq(screen.outfit_ids(), Outfits.ids(), "in the data's order")
	for outfit_id in Outfits.ids():
		var button: Button = screen.button_for(outfit_id)
		assert_not_null(button, "a button for %s" % outfit_id)
		assert_eq(button.text, Strings.t(Outfits.name_id_of(outfit_id)))
		assert_gte(button.custom_minimum_size.y, 96.0, "a thumb-sized button")
		assert_eq(button.tooltip_text, button.text, "its label is readable")
		# No price, no badge, no owned state: a button is its name and nothing else.
		assert_null(button.icon)
		assert_eq(button.get_child_count(), 0)
		assert_false(button.disabled)
	assert_eq(screen.get_node("%Title").text, "Try on")
	assert_eq(screen.get_node("%DoneButton").text, "Done")


func test_focus_starts_on_the_worn_outfit_and_the_arrows_step_along_the_row() -> void:
	GameState.outfit = SKATER
	var screen: Control = add_child_autofree(WARDROBE.instantiate())
	await wait_frames(1)
	var index := Outfits.ids().find(SKATER)
	assert_true(screen.button_for(SKATER).has_focus(), "focus sits on what is worn")
	assert_eq(screen.current_index(), index)
	screen.get_node("%NextButton").pressed.emit()
	assert_true(screen.outfit_buttons()[index + 1].has_focus(), "Next steps right")
	screen.get_node("%PrevButton").pressed.emit()
	screen.get_node("%PrevButton").pressed.emit()
	assert_true(screen.outfit_buttons()[index - 1].has_focus(), "Prev steps left")
	for i in 20:
		screen.get_node("%PrevButton").pressed.emit()
	assert_true(screen.outfit_buttons()[0].has_focus(), "the row has ends")
	for i in 20:
		screen.get_node("%NextButton").pressed.emit()
	assert_true(screen.outfit_buttons()[Outfits.ids().size() - 1].has_focus())


func test_with_no_outfit_named_focus_starts_on_the_default() -> void:
	var screen: Control = add_child_autofree(WARDROBE.instantiate())
	await wait_frames(1)
	assert_true(screen.button_for(Outfits.default_id()).has_focus())


func test_done_and_cancel_close_the_screen() -> void:
	var screen: Control = add_child_autofree(WARDROBE.instantiate())
	watch_signals(screen)
	await wait_frames(1)
	screen.get_node("%DoneButton").pressed.emit()
	assert_signal_emit_count(screen, "closed", 1)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	screen._unhandled_input(cancel)
	assert_signal_emit_count(screen, "closed", 2, "a gamepad's B or Esc closes it too")


# -- trying on ----------------------------------------------------------------


func test_try_on_opens_the_wardrobe_holds_the_body_and_turns_the_camera() -> void:
	var room := _showroom()
	await _on_dais(room)
	var player: CharacterBody3D = room.get_node("%Player")
	var stand: Node3D = room.get_node("%TryOnStand")
	watch_signals(stand)
	room.get_node("%TouchControls").contextual_button().pressed.emit()
	await wait_frames(2)
	assert_true(stand.is_open(), "Try on opened the wardrobe")
	assert_signal_emitted(stand, "opened")
	assert_true(player.is_held_still(), "the body stays on the dais")
	assert_true(room.get_node("%CameraRig").is_drifting(), "the camera comes round to the front")
	assert_false(stand.use_area().is_available(), "no second Try on while it is open")
	assert_ne(
		room.get_node("%TouchControls").contextual_button().current_verb(),
		"verb.try_on",
		"the verb is withdrawn"
	)
	var screen: Control = stand.screen()
	assert_not_null(screen)
	assert_true(screen.is_inside_tree(), "the panel is on screen over the view")
	assert_eq(screen.outfit_buttons().size(), Outfits.ids().size())
	screen.get_node("%DoneButton").pressed.emit()
	await wait_frames(2)
	assert_false(stand.is_open())
	assert_signal_emitted(stand, "closed")
	assert_false(player.is_held_still(), "Done lets the body move again")
	assert_true(stand.use_area().is_available(), "and offers Try on again")


func test_choosing_an_outfit_sets_the_journey_and_repaints_the_player_at_once() -> void:
	var room := _showroom()
	await _on_dais(room)
	var player: CharacterBody3D = room.get_node("%Player")
	var rig: CharacterRig = player.get_node("%Mesh")
	var before: Texture2D = rig.skin
	room.get_node("%TouchControls").contextual_button().pressed.emit()
	await wait_frames(2)
	var screen: Control = room.get_node("%TryOnStand").screen()
	watch_signals(screen)
	screen.button_for(SKATER).pressed.emit()
	assert_eq(GameState.outfit, SKATER, "the journey knows")
	assert_signal_emitted_with_parameters(screen, "outfit_chosen", [SKATER])
	assert_eq(rig.skin.resource_path, Outfits.skin_path_of(SKATER), "the rig's skin changed")
	assert_eq(_painted(rig), rig.skin, "and is painted on the body without waiting")
	assert_ne(rig.skin, before)
	screen.button_for(COAT).pressed.emit()
	assert_eq(GameState.outfit, COAT, "trying another one")
	assert_eq(_painted(rig).resource_path, Outfits.skin_path_of(COAT))
	screen.get_node("%DoneButton").pressed.emit()
	await wait_frames(2)
	assert_eq(GameState.outfit, COAT, "Done keeps what was chosen")
	assert_eq(_painted(rig).resource_path, Outfits.skin_path_of(COAT))


func test_the_outfit_is_saved_at_once_and_loads_into_a_fresh_game_state() -> void:
	GameState.set_autosave(true)
	GameState.set_outfit(SKATER)
	GameState.set_autosave(false)
	assert_true(FileAccess.file_exists(SCRATCH), "autosave wrote the journey on the choice")
	var loaded: Node = GAME_STATE.new()
	loaded.save_path = SCRATCH
	assert_true(loaded.load_journey())
	assert_eq(loaded.outfit, SKATER, "the outfit is in the journey file")
	loaded.free()
	GameState.wipe()
	assert_eq(GameState.outfit, "", "Play again undresses the journey")
	assert_false(GameState.to_dict().get("outfit", "x") is int)
	assert_eq(GameState.to_dict().get("outfit"), "")


func test_the_street_player_wears_the_saved_outfit_at_ready() -> void:
	GameState.set_outfit(COAT)
	var street: Node3D = add_child_autofree(STREET.instantiate())
	await wait_frames(1)
	var rig: CharacterRig = street.get_node("%Player/Mesh")
	assert_eq(rig.skin.resource_path, Outfits.skin_path_of(COAT), "dressed at ready")
	assert_eq(_painted(rig).resource_path, Outfits.skin_path_of(COAT))
	var tulu: CharacterRig = street.get_node("%Tulu/Figure")
	assert_ne(tulu.skin.resource_path, rig.skin.resource_path, "only the player changed")


func test_an_outfit_the_data_no_longer_knows_keeps_the_scene_skin() -> void:
	GameState.set_outfit("a_coat_from_a_later_build")
	var player: CharacterBody3D = add_child_autofree(PLAYER.instantiate())
	await wait_frames(1)
	var rig: CharacterRig = player.get_node("%Mesh")
	assert_eq(rig.skin.resource_path, Outfits.skin_path_of(Outfits.default_id()))
	GameState.set_outfit(SKATER)
	assert_eq(rig.skin.resource_path, Outfits.skin_path_of(SKATER), "a live change still lands")
	GameState.set_outfit("")
	assert_eq(
		rig.skin.resource_path,
		Outfits.skin_path_of(Outfits.default_id()),
		"and no outfit is the scene's skin again"
	)
