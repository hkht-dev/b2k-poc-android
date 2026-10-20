## Tests the four Glimpse points beyond the traffic light (GDD §6
## "Glimpses"): none shows at the start; each shows when its own condition
## holds and never before; approaching ends it, leaves its feather or jasmine
## where the data says, sets its seen flag and records exactly its line; a
## condition with `and not` reads as written; nobody but Tulu, at the traffic
## light, reacts.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_glimpses_journey.json"

## Point node -> the flag that shows it, its seen flag, its line, what it leaves.
const POINTS := {
	"GlimpseTower": ["heard_tulu", "glimpsed_tower", "journey.glimpse.tower", "feather"],
	"GlimpseStairwell":
	["rukma_heard", "glimpsed_stairwell", "journey.glimpse.stairwell", "jasmine"],
	"GlimpseGarden": ["garden_open", "glimpsed_garden", "journey.glimpse.garden", "jasmine"],
	"GlimpseChaiStall":
	["saw_shrine", "glimpsed_chai_stall", "journey.glimpse.chai_stall", "feather"],
}
const LINES := {
	"journey.glimpse.tower": "You thought you saw someone on the tower.",
	"journey.glimpse.stairwell": "You thought you saw someone in the stairwell doorway.",
	"journey.glimpse.garden": "You thought you saw someone at the far end of the garden.",
	"journey.glimpse.chai_stall": "You thought you saw someone on the chai stall's roof.",
}

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


func _point(street: Node3D, point: String) -> Node3D:
	return street.get_node("%" + point)


func _stand_at(street: Node3D, spot: Vector3) -> void:
	var player: CharacterBody3D = street.get_node("%Player")
	player.global_position = spot + Vector3(0.3, 0.2, 0.3)


func test_none_of_the_four_shows_at_the_start_or_on_an_unrelated_flag() -> void:
	var street := _street()
	await wait_frames(60)
	GameState.set_flag("took_dry_fountain")
	GameState.set_flag("gave_dry_fountain")
	await wait_frames(3)
	for point: String in POINTS:
		var glimpse := _point(street, point)
		assert_false(glimpse.is_active(), "%s waits for its own condition" % point)
		assert_false(glimpse.pickup().visible, "%s has left nothing" % point)


func test_each_shows_when_its_condition_holds_and_not_before() -> void:
	var street := _street()
	await wait_frames(2)
	var shown: Array[String] = []
	for point: String in POINTS:
		var glimpse := _point(street, point)
		assert_false(glimpse.is_active(), "%s is not there yet" % point)
		watch_signals(glimpse)
		GameState.set_flag(POINTS[point][0])
		await wait_frames(3)
		shown.append(point)
		assert_true(glimpse.is_active(), "%s shows on %s" % [point, POINTS[point][0]])
		assert_signal_emitted(glimpse, "appeared")
		assert_true(glimpse.get_node("%Figure").visible, "the silhouette is there")
		assert_true(glimpse.get_node("%RimLight").visible, "lit by the one warm light")
		for other: String in POINTS:
			if other not in shown:
				assert_false(_point(street, other).is_active(), "%s is not" % other)


func test_approaching_ends_it_and_leaves_its_pickup_its_flag_and_exactly_its_line() -> void:
	var street := _street()
	await wait_frames(2)
	for point: String in POINTS:
		var glimpse := _point(street, point)
		GameState.set_flag(POINTS[point][0])
		await wait_frames(3)
		assert_true(glimpse.is_active())
		var pickup: Node3D = glimpse.pickup()
		assert_false(pickup.visible, "nothing lies there while He is there")
		_stand_at(street, pickup.global_position)
		await wait_frames(4)
		assert_false(glimpse.is_active(), "%s ends on approach" % point)
		assert_true(pickup.visible, "%s leaves its %s" % [point, POINTS[point][3]])
		assert_eq(pickup.item, POINTS[point][3], "the right thing")
		assert_true(GameState.has_flag(POINTS[point][1]), "recorded as a flag, once")
		assert_eq(GameState.journey_lines.count(POINTS[point][2]), 1, "exactly its line")
		assert_eq(Strings.t(POINTS[point][2]), LINES[POINTS[point][2]], "the line of GDD §6")
	assert_eq(GameState.journey_lines.size(), POINTS.size(), "one line each, nothing else")
	await wait_seconds(0.7)
	for point: String in POINTS:
		assert_false(_point(street, point).get_node("%Figure").visible, "faded away")


func test_what_it_leaves_lies_where_the_data_says() -> void:
	var street := _street()
	await wait_frames(2)
	var tower := _point(street, "GlimpseTower")
	var foot: Vector3 = tower.pickup().global_position
	assert_almost_eq(foot, Vector3(-31.0, 0.0, -17.4), Vector3.ONE * 0.01, "at the tower's foot")
	assert_lt(foot.y, tower.global_position.y - 20.0, "far below the beam")
	var garden := _point(street, "GlimpseGarden")
	assert_almost_eq(
		garden.pickup().global_position, garden.global_position, Vector3.ONE * 0.01, "on the spot"
	)
	var chai := _point(street, "GlimpseChaiStall")
	assert_almost_eq(
		chai.pickup().global_position, Vector3(13.6, 0.0, -6.0), Vector3.ONE * 0.01, "by the hatch"
	)


func test_a_condition_with_and_not_reads_as_written() -> void:
	var street := _street()
	var stairwell := _point(street, "GlimpseStairwell")
	assert_eq(stairwell.condition(), "flag:rukma_heard and not flag:rukma_key_taken")
	GameState.set_flag("rukma_key_taken")
	GameState.set_flag("rukma_heard")
	await wait_frames(3)
	assert_false(stairwell.is_active(), "He does not come to one who took the key")
	assert_false(GameState.has_flag("glimpsed_stairwell"))
	GameState.clear_flag("rukma_key_taken")
	await wait_frames(3)
	assert_true(stairwell.is_active(), "the condition is read whole, on every change")


func test_the_old_trigger_flag_export_still_reads_as_a_condition() -> void:
	var street := _street()
	var light := _point(street, "Glimpse")
	assert_eq(light.trigger_condition, "", "the traffic light keeps the P5 export")
	assert_eq(light.condition(), "flag:gave_dry_fountain")
	assert_eq(light.leaves, "feather")
	assert_true(light.witnessed, "the one Tulu looks up at")


func test_a_condition_already_true_on_arrival_shows_it() -> void:
	# saw_shrine is set inside the shrine, a place of its own: the Street is
	# loaded afresh when the player comes out, and the roof is above the door.
	GameState.set_flag("saw_shrine")
	var street := _street()
	await wait_frames(2)
	assert_true(_point(street, "GlimpseChaiStall").is_active(), "He is on the roof as you come out")
	for point: String in POINTS:
		if point != "GlimpseChaiStall":
			assert_false(_point(street, point).is_active())


func test_it_never_happens_twice_but_what_it_left_is_there() -> void:
	GameState.set_flag("glimpsed_garden")
	GameState.set_flag("garden_open")
	var street := _street()
	await wait_frames(2)
	var garden := _point(street, "GlimpseGarden")
	assert_false(garden.is_active())
	assert_true(garden.pickup().visible, "the jasmine it left is there")
	GameState.fire_event("jasmine_picked_up_garden")
	var again := _street()
	await wait_frames(2)
	assert_false(_point(again, "GlimpseGarden").pickup().visible, "once picked up, gone")


func test_nobody_reacts_but_tulu_at_the_traffic_light() -> void:
	var street := _street()
	var tulu: Node3D = street.get_node("%Tulu")
	await wait_frames(2)
	for point: String in POINTS:
		GameState.set_flag(POINTS[point][0])
		await wait_frames(2)
		assert_true(_point(street, point).is_active())
		assert_false(tulu.is_looking_up(), "Tulu does not look at %s" % point)
	for i: int in 5:
		var ped: Node3D = street.get_node("Ambience/Pedestrian%d" % i)
		assert_false(ped.has_method("look_up_at"), "pedestrians do not react")
	GameState.set_flag("gave_dry_fountain")
	await wait_frames(2)
	assert_true(tulu.is_looking_up(), "only at the traffic light")


func test_the_jasmine_can_be_picked_up_and_carried_and_nothing_happens() -> void:
	var street := _street()
	GameState.set_flag("glimpsed_stairwell")
	await wait_frames(2)
	var jasmine: Node3D = _point(street, "GlimpseStairwell").pickup()
	assert_eq(jasmine.item, "jasmine")
	var player: CharacterBody3D = street.get_node("%Player")
	_stand_at(street, jasmine.global_position)
	await wait_frames(8)
	var button: Button = street.get_node("%TouchControls").contextual_button()
	assert_eq(button.current_verb(), "verb.pick_up")
	var flags_before: int = GameState.flags.size()
	button.pressed.emit()
	await wait_frames(2)
	assert_true(player.is_carrying("jasmine"))
	assert_false(jasmine.visible)
	assert_true(GameState.has_event("jasmine_picked_up_stairwell"), "this point's own event")
	assert_false(GameState.has_event("jasmine_picked_up_garden"), "not the garden's")
	assert_eq(GameState.flags.size(), flags_before + 1, "only the carrying flag: nothing happens")
	var rig: CharacterRig = street.get_node("%Player/Mesh")
	assert_true(rig.is_carrying(), "it shows in the hand")
	assert_false(player.carry("feather"), "one thing at a time")


func test_each_point_leaves_only_one_pickup_node() -> void:
	var street := _street()
	await wait_frames(2)
	for point: String in POINTS:
		var glimpse := _point(street, point)
		var pickups := 0
		for child: Node in glimpse.get_children():
			if child.has_method("_on_pick_up") and not child.is_queued_for_deletion():
				pickups += 1
		assert_eq(pickups, 1, "%s keeps the one it leaves" % point)
