## Tests the Pool of Worlds (GDD §3 Act 2 and Act 5, §3a Act 2, §5, §10 Pool
## row): both ways are places that load with an empty HUD; after `seconds`
## the journey moves on and Main is asked for the next place; the early end
## waits for its threshold and a touch held still; a drag tilts the view and
## nothing else does anything; the colours end where the GDD puts them.
extends GutTest

## tools/check_data.py MAX_WORDS. GDD §8 kept a line under twenty words;
## the owner lifted it to thirty-four after the expansion, because the
## shorthand had stopped making sense (docs/DECISIONS.md "Conversations").
const LINE_WORD_CAP := 35

const VEIL := preload("res://scenes/places/Veil.tscn")
const VEIL_DOWN := preload("res://scenes/places/VeilDown.tscn")
const VEIL_UP := preload("res://scenes/places/VeilUp.tscn")
const SCRATCH := "user://test_veil_journey.json"
## The brief's budget for the star field, both segments together.
const MAX_POINTS := 400
const NEXT_PLACE := "store"
const NEXT_SPAWN := "store_door"

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


## A Veil with its exports set before it enters the tree, as the two data
## scenes set them.
func _veil(direction: String, seconds: float, lines := PackedStringArray()) -> Node3D:
	var veil: Node3D = VEIL.instantiate()
	veil.direction = direction
	veil.seconds = seconds
	veil.next_place = NEXT_PLACE
	veil.next_spawn = NEXT_SPAWN
	veil.line_ids = lines
	add_child_autofree(veil)
	return veil


func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _drag(index: int, position: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))


# -- two places, one scene ----------------------------------------------------


func test_both_ways_are_places_that_load_with_an_empty_hud() -> void:
	for place_id: String in ["veil_down", "veil_up"]:
		assert_true(Places.has(place_id), "%s is in data/places.json" % place_id)
		assert_true(Strings.has_id(Places.name_id_of(place_id)), "%s has a name" % place_id)
		var packed := load(Places.scene_of(place_id)) as PackedScene
		assert_not_null(packed, "%s names a scene that loads" % place_id)
		var veil: Node3D = add_child_autofree(packed.instantiate())
		await wait_frames(2)
		assert_eq(veil.direction, place_id.trim_prefix("veil_"), "the direction is the scene's")
		assert_eq(veil.seconds, 90.0, "GDD §5: a 90-second sequence")
		var controls: Control = veil.controls()
		assert_false(controls.joystick().visible, "no joystick: nothing walks here")
		assert_false(controls.contextual_button().visible, "nothing to use")
		assert_false(controls.pause_button().visible, "no pause in the fall")
		assert_false(controls.minimap().visible)
		assert_false(controls.compass().visible)
		assert_gt(veil.star_count(), 0)
		assert_lte(veil.star_count(), MAX_POINTS, "cheap on a phone")
		assert_true(veil.get_node("%Song").playing, "the Song is playing")
		assert_false(veil.is_ending())


func test_the_lines_are_data_and_only_the_way_down_has_them() -> void:
	var down: Node3D = add_child_autofree(VEIL_DOWN.instantiate())
	var up: Node3D = add_child_autofree(VEIL_UP.instantiate())
	await wait_frames(1)
	assert_eq(down.line_ids.size(), 3, "§8 Scene B: three lines, one at a time")
	for id: String in down.line_ids:
		assert_true(Strings.has_id(id), "%s is in the string table" % id)
		assert_lt(Strings.t(id).split(" ").size(), LINE_WORD_CAP, "§8: inside the cap")
	assert_true(up.line_ids.is_empty(), "nothing is said on the way home")
	assert_eq(down.next_place, "street", "down lands in the Street")
	# GDD §3 Act 5 is "Rising" and then "Home": the rise ends on the riverbank
	# where the garland is offered, not back in the Grove meadow.
	assert_eq(up.next_place, "home", "up lands on the riverbank")
	assert_eq(up.next_spawn, "bank")
	assert_eq(down.line_text(), "", "nothing is shown at the start")


# -- the fall ends and the journey moves on -----------------------------------


func test_after_its_seconds_the_journey_moves_on_and_the_next_place_is_requested() -> void:
	var veil := _veil("down", 2.0)
	watch_signals(veil)
	await wait_seconds(1.0)
	assert_false(veil.is_ending(), "not yet")
	assert_eq(GameState.place, "street", "the journey has not moved")
	await wait_seconds(1.0 + veil.END_FADE_SECONDS + 0.4)
	assert_true(veil.is_ending())
	assert_almost_eq(veil.fade_alpha(), 1.0, 0.01, "black before the swap")
	assert_eq(GameState.place, NEXT_PLACE, "GameState.set_place came first")
	assert_eq(GameState.spawn, NEXT_SPAWN)
	assert_signal_emitted_with_parameters(veil, "ended", [false])
	assert_signal_emitted_with_parameters(veil, "place_requested", [NEXT_PLACE, NEXT_SPAWN])


func test_the_lines_appear_one_at_a_time_on_the_way_down() -> void:
	var lines := PackedStringArray(["veil.line.easy", "veil.line.harder"])
	var veil := _veil("down", 3.0, lines)
	assert_eq(veil.current_line_id(), "")
	await wait_seconds(3.0 * veil.LINES_FROM + 0.2)
	assert_eq(veil.current_line_id(), "veil.line.easy")
	assert_eq(veil.line_text(), Strings.t("veil.line.easy"), "from the string table")
	assert_gt(veil.get_node("%Line").modulate.a, 0.0, "fading in")
	await wait_seconds(3.0 * (veil.LINES_TO - veil.LINES_FROM) / 2.0)
	assert_eq(veil.current_line_id(), "veil.line.harder", "the next waits its turn")


# -- the early end ------------------------------------------------------------


func test_the_early_end_waits_for_the_threshold_and_a_touch_held_still() -> void:
	var veil := _veil("down", 30.0)
	veil.early_end_after = 1.0
	veil.hold_seconds = 0.3
	watch_signals(veil)
	# Before the threshold a held finger is nothing.
	veil._unhandled_input(_touch(0, Vector2(540, 960), true))
	await wait_seconds(0.5)
	assert_false(veil.is_holding(), "no early end before the threshold")
	assert_false(veil.is_ending())
	veil._unhandled_input(_touch(0, Vector2(540, 960), false))
	await wait_seconds(0.6)
	assert_true(veil.can_end_early(), "past the threshold")
	# A finger that wanders is a drag, not a hold.
	veil._unhandled_input(_touch(0, Vector2(540, 960), true))
	assert_true(veil.is_holding())
	veil._unhandled_input(_drag(0, Vector2(600, 960)))
	assert_false(veil.is_holding(), "moving cancels the hold")
	veil._unhandled_input(_touch(0, Vector2(600, 960), false))
	# Letting go cancels it too.
	veil._unhandled_input(_touch(0, Vector2(540, 960), true))
	veil._unhandled_input(_touch(0, Vector2(540, 960), false))
	assert_false(veil.is_holding())
	# Held still for hold_seconds: the view darkens, then it ends.
	veil._unhandled_input(_touch(0, Vector2(540, 960), true))
	await wait_seconds(0.15)
	assert_true(veil.is_holding())
	assert_gt(veil.fade_alpha(), 0.1, "the view darkens while the finger stays")
	assert_false(veil.is_ending())
	await wait_seconds(0.4)
	assert_true(veil.is_ending(), "ended by the hold")
	await wait_seconds(0.4)
	assert_signal_emitted_with_parameters(veil, "ended", [true])
	assert_signal_emitted_with_parameters(veil, "place_requested", [NEXT_PLACE, NEXT_SPAWN])
	assert_eq(GameState.place, NEXT_PLACE)


func test_the_held_key_or_button_ends_it_too() -> void:
	var veil := _veil("up", 30.0)
	veil.early_end_after = 0.0
	veil.hold_seconds = 0.2
	await wait_frames(2)
	var press := InputEventAction.new()
	press.action = "contextual"
	press.pressed = true
	veil._unhandled_input(press)
	assert_true(veil.is_holding(), "E or A on a gamepad stands in for a finger")
	await wait_seconds(0.35)
	assert_true(veil.is_ending())


# -- tilting the view ---------------------------------------------------------


func test_a_drag_tilts_the_view_and_a_tap_does_nothing() -> void:
	var veil := _veil("down", 30.0)
	await wait_frames(2)
	var controls: Control = veil.controls()
	var yaw_before: float = veil.camera_yaw()
	var pitch_before: float = veil.camera_pitch()
	controls._unhandled_input(_touch(0, Vector2(800, 900), true))
	controls._unhandled_input(_drag(0, Vector2(900, 960)))
	controls._unhandled_input(_drag(0, Vector2(1000, 1020)))
	controls._unhandled_input(_touch(0, Vector2(1000, 1020), false))
	assert_lt(veil.camera_yaw(), yaw_before, "dragging right turns the view, the rig's way round")
	assert_lt(veil.camera_pitch(), pitch_before, "dragging down tilts it down")
	assert_gte(veil.camera_pitch(), -veil.TILT_LIMIT, "within the tilt")
	assert_false(veil.is_holding(), "a drag is never a hold")
	var yaw: float = veil.camera_yaw()
	controls._unhandled_input(_touch(0, Vector2(300, 900), true))
	controls._unhandled_input(_touch(0, Vector2(300, 900), false))
	assert_eq(veil.camera_yaw(), yaw, "a tap has nothing to walk to")
	controls.camera_dragged.emit(Vector2(-500.0, 0.0))
	assert_gt(veil.camera_yaw(), yaw, "the right stick comes through the same seam")
	assert_false(veil.is_ending())


func test_the_stars_stream_up_on_the_way_down_and_down_on_the_way_up() -> void:
	var down := _veil("down", 30.0)
	var up := _veil("up", 30.0)
	await wait_frames(1)
	var down_before: PackedFloat32Array = down.segment_heights()
	var up_before: PackedFloat32Array = up.segment_heights()
	await wait_frames(10)
	assert_gt(down.segment_heights()[0], down_before[0], "falling: the field rises past the camera")
	assert_lt(up.segment_heights()[0], up_before[0], "rising: it sinks past")
	assert_eq(down.star_count(), up.star_count(), "one field, two directions")


# -- colour -------------------------------------------------------------------


func test_the_way_down_drains_the_colour_to_blue_black() -> void:
	var veil := _veil("down", 1.2)
	await wait_frames(2)
	var start: Color = veil.vignette_color()
	assert_gt(_distance(start, veil.BLUE_BLACK), 0.2, "it starts with colour to lose")
	assert_gt(veil.glow_alpha(), 0.3, "the glow is there to unravel")
	assert_lt(start.r, start.b, "nothing warm on the way down (GDD §10)")
	await wait_seconds(1.3)
	assert_lt(_distance(veil.vignette_color(), veil.BLUE_BLACK), 0.03, "blue-black at the bottom")
	assert_almost_eq(veil.glow_alpha(), 0.0, 0.02, "the glow has unravelled")


func test_the_way_up_warms_to_rose_gold() -> void:
	var veil := _veil("up", 1.2)
	await wait_frames(2)
	assert_lt(
		_distance(veil.vignette_color(), veil.BLUE_BLACK), 0.1, "it starts where the fall ended"
	)
	assert_lt(veil.glow_alpha(), 0.05, "no glow yet")
	await wait_seconds(1.3)
	var end: Color = veil.vignette_color()
	assert_lt(_distance(end, veil.ROSE_GOLD), 0.03, "rose-gold at the surface")
	assert_gt(end.r, end.b, "warm, not cold, on the way up (GDD §10)")
	assert_gt(veil.glow_alpha(), 0.5, "the glow is back")
