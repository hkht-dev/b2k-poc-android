## Tests P5, the Glimpse (CLAUDE_CODE_BRIEF.md §4.5, GDD §6): triggered once
## by the flag, never by a timer or the other path; ends when approached;
## leaves the one peacock feather; one exact line in *Your journey*.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const PAUSE := preload("res://scenes/ui/PauseMenu.tscn")
const SCRATCH := "user://test_p5_journey.json"

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


func _street() -> Node3D:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	return street


func _glimpse(street: Node3D) -> Node3D:
	return street.get_node("%Glimpse")


func test_nothing_happens_on_a_timer_or_on_the_took_path() -> void:
	var street := _street()
	var glimpse := _glimpse(street)
	await wait_frames(90)
	assert_false(glimpse.is_active(), "time alone never triggers it")
	GameState.set_flag("took_dry_fountain")
	await wait_frames(3)
	assert_false(glimpse.is_active(), "the took path never triggers it")
	assert_false(glimpse.get_node("%FeatherPickup").visible, "no feather")


func test_the_first_gave_flag_shows_the_silhouette_with_its_rim_light() -> void:
	var street := _street()
	var glimpse := _glimpse(street)
	watch_signals(glimpse)
	GameState.set_flag("gave_dry_fountain")
	await wait_frames(3)
	assert_true(glimpse.is_active())
	assert_signal_emitted(glimpse, "appeared")
	assert_true(glimpse.get_node("%Figure").visible, "the silhouette is on the beam")
	assert_true(glimpse.get_node("%RimLight").visible, "lit by the one warm rim light")
	var tulu: Node3D = street.get_node("%Tulu")
	assert_true(tulu.is_looking_up(), "Tulu looks up")
	for i: int in 5:
		var ped: Node3D = street.get_node("Ambience/Pedestrian%d" % i)
		assert_false(ped.has_method("look_up_at"), "pedestrians do not react")


func test_approaching_ends_it_and_leaves_the_feather_and_the_line() -> void:
	var street := _street()
	var glimpse := _glimpse(street)
	GameState.set_flag("gave_dry_fountain")
	await wait_frames(3)
	assert_true(glimpse.is_active())
	var player: CharacterBody3D = street.get_node("%Player")
	player.global_position = glimpse.global_position + Vector3(2.0, -5.5, 0.0)
	await wait_frames(4)
	assert_false(glimpse.is_active(), "within 6 m it ends")
	assert_true(glimpse.get_node("%FeatherPickup").visible, "a feather lies beneath")
	assert_true(GameState.has_flag("glimpsed_traffic_light"), "recorded as a flag, once")
	assert_true(GameState.journey_lines.has("journey.glimpse.traffic_light"))
	assert_eq(
		Strings.t("journey.glimpse.traffic_light"),
		"You thought you saw someone on the traffic light.",
		"the exact line of §4.5"
	)
	await wait_seconds(0.7)
	assert_false(glimpse.get_node("%Figure").visible, "faded away")


func test_it_never_happens_twice() -> void:
	var street := _street()
	var glimpse := _glimpse(street)
	GameState.set_flag("glimpsed_traffic_light")
	GameState.set_flag("gave_dry_fountain")
	await wait_frames(3)
	assert_false(glimpse.is_active())
	assert_true(glimpse.get_node("%FeatherPickup").visible, "but the feather it left is there")


func test_the_feather_can_be_picked_up_and_carried_and_nothing_happens() -> void:
	var street := _street()
	var glimpse := _glimpse(street)
	GameState.set_flag("glimpsed_traffic_light")
	await wait_frames(2)
	var feather: Node3D = glimpse.get_node("%FeatherPickup")
	var player: CharacterBody3D = street.get_node("%Player")
	player.global_position = feather.global_position + Vector3(0.3, 0.2, 0.3)
	await wait_frames(8)
	var button: Button = street.get_node("%TouchControls").contextual_button()
	assert_eq(button.current_verb(), "verb.pick_up")
	var flags_before: int = GameState.flags.size()
	button.pressed.emit()
	await wait_frames(2)
	assert_true(player.is_carrying("feather"))
	assert_false(feather.visible)
	assert_true(GameState.has_event("feather_picked_up"))
	assert_eq(
		GameState.flags.size(), flags_before + 1, "only the carrying flag changed: nothing happens"
	)
	var rig: CharacterRig = street.get_node("%Player/Mesh")
	assert_true(rig.is_carrying(), "it shows in the hand")


func test_your_journey_lists_the_line_in_the_pause_menu() -> void:
	GameState.add_journey_line("journey.glimpse.traffic_light")
	var menu: Control = add_child_autofree(PAUSE.instantiate())
	await wait_frames(1)
	assert_eq(
		menu.journey_texts(),
		PackedStringArray(["You thought you saw someone on the traffic light."])
	)


func test_the_feather_is_the_only_peacock_blue_and_the_can_and_feather_cannot_both_be_held(
) -> void:
	var street := _street()
	var player: CharacterBody3D = street.get_node("%Player")
	await wait_frames(2)
	assert_true(player.carry("can"))
	assert_false(player.carry("feather"), "one thing at a time")
	assert_eq(player.carried_item(), "can")
	player.put_down()
	assert_false(player.is_carrying())
