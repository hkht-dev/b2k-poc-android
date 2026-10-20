## Tests the Path card (GDD §16a "Path card"): the route the street samples
## into the journey, the card drawn from it, and the end screen's *Share your
## path* that saves it.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const END := preload("res://scenes/ui/EndScreen.tscn")
const GAME_STATE := preload("res://scripts/core/game_state.gd")
const SCRATCH := "user://test_path_card_journey.json"
const SCRATCH_PNG := "user://test_path_card.png"

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
	if FileAccess.file_exists(SCRATCH_PNG):
		DirAccess.remove_absolute(SCRATCH_PNG)


func _street() -> Node3D:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	return street


static func _is_paper(pixel: Color) -> bool:
	return (
		absf(pixel.r - PathCard.PAPER.r) < 0.03
		and absf(pixel.g - PathCard.PAPER.g) < 0.03
		and absf(pixel.b - PathCard.PAPER.b) < 0.03
	)


# -- the route ----------------------------------------------------------------


func test_the_street_samples_the_route_while_the_player_walks_and_not_paused() -> void:
	var street := _street()
	street.route_sample_seconds = 0.05
	var player: CharacterBody3D = street.get_node("%Player")
	player.global_position = Vector3(-10.0, 0.3, 16.0)
	await wait_frames(10)
	assert_eq(GameState.route.size(), 0, "standing still adds nothing")
	player.walk_to(Vector3(-2.0, 0.0, 16.0))
	await wait_frames(40)
	var walked := GameState.route.size()
	assert_gt(walked, 2, "walking adds points")
	var first: Array = GameState.route[0]
	assert_almost_eq(float(first[0]), -10.0, 1.0, "the first point is where the walk began")
	assert_almost_eq(float(first[1]), 16.0, 0.5)
	var last: Array = GameState.route[walked - 1]
	assert_gt(float(last[0]), float(first[0]), "and the line follows the player east")
	# No awaits while paused: the tree is paused and GUT's frame waiter with it.
	street.pause()
	street._physics_process(1.0)
	assert_eq(GameState.route.size(), walked, "paused, nothing is sampled")
	street.resume()
	await wait_frames(1)


func test_the_route_keeps_the_newest_six_hundred_points() -> void:
	for i in GameState.ROUTE_CAP + 100:
		GameState.add_route_point(float(i), 0.0)
	assert_eq(GameState.route.size(), GameState.ROUTE_CAP)
	assert_eq(float(GameState.route[0][0]), 100.0, "the oldest went first")


func test_the_route_is_in_the_journey_file_and_gone_after_the_wipe() -> void:
	GameState.add_route_point(1.5, -2.25)
	GameState.add_route_point(3.0, 4.0)
	GameState.save()
	var loaded: Node = GAME_STATE.new()
	loaded.save_path = SCRATCH
	assert_true(loaded.load_journey())
	assert_eq(loaded.route.size(), 2)
	assert_almost_eq(float(loaded.route[0][1]), -2.25, 0.001)
	assert_almost_eq(float(loaded.route[1][0]), 3.0, 0.001)
	loaded.free()
	GameState.wipe()
	assert_true(GameState.route.is_empty())


# -- the card -----------------------------------------------------------------


func test_the_card_is_a_phone_story_with_the_route_in_ink() -> void:
	var corners: Array[Vector2] = [
		Vector2(-60.0, -40.0), Vector2(60.0, -40.0), Vector2(60.0, 40.0), Vector2(-60.0, 40.0)
	]
	for corner in corners:
		GameState.add_route_point(corner.x, corner.y)
	GameState.add_journey_line("journey.dry_fountain.gave")
	var card := PathCard.new()
	var image := card.render()
	assert_eq(image.get_size(), Vector2i(PathCard.WIDTH, PathCard.HEIGHT), "1080 x 1920")
	# From one step in: the first point is the centre of the start ring, paper.
	for i in corners.size() - 1:
		for step in range(1, 11):
			var at := PathCard.to_card(corners[i].lerp(corners[i + 1], step / 10.0))
			assert_false(_is_paper(image.get_pixelv(Vector2i(at.round()))), "ink at %s" % at)
	assert_true(_is_paper(image.get_pixel(20, 20)), "the margin is paper")
	var labels := card.labels()
	assert_has(labels, Strings.t("app.title"))
	assert_has(labels, Strings.t("end.line"))
	assert_has(labels, Strings.t("journey.dry_fountain.gave"), "Your journey is on it")


func test_nothing_on_the_card_is_a_number() -> void:
	GameState.add_route_point(0.0, 0.0)
	GameState.add_route_point(10.0, 10.0)
	GameState.add_journey_line("journey.dry_fountain.gave")
	GameState.add_journey_line("journey.glimpse.traffic_light")
	var card := PathCard.new()
	card.render()
	var digit := RegEx.create_from_string("\\d")
	assert_gt(card.labels().size(), 3, "title, subtitle, lines and the end line")
	for label in card.labels():
		assert_null(digit.search(label), "no digit in '%s'" % label)


func test_save_png_writes_the_card_under_user() -> void:
	GameState.add_route_point(0.0, 0.0)
	var card := PathCard.new()
	assert_true(card.save_png(SCRATCH_PNG))
	assert_true(FileAccess.file_exists(SCRATCH_PNG))
	var saved := Image.new()
	assert_eq(saved.load_png_from_buffer(FileAccess.get_file_as_bytes(SCRATCH_PNG)), OK)
	assert_eq(saved.get_size(), Vector2i(1080, 1920))


func test_the_street_hands_the_block_to_the_card() -> void:
	var street := _street()
	await wait_frames(1)
	var blocks := PathCard.blocks()
	assert_gt(blocks.size(), 3, "the minimap's footprints reached the card")
	var card := PathCard.new()
	var image := card.render()
	var road: Rect2 = blocks[0]["rect"]
	var centre := PathCard.to_card(road.get_center())
	assert_false(
		_is_paper(image.get_pixelv(Vector2i(centre.round()))), "the block is drawn, faintly"
	)
	street.queue_free()


# -- the end screen -----------------------------------------------------------


func test_the_end_screen_offers_share_beside_play_again_and_writes_the_card() -> void:
	GameState.add_route_point(-20.0, 10.0)
	GameState.add_route_point(20.0, 10.0)
	var screen: Control = add_child_autofree(END.instantiate())
	screen.card_path = SCRATCH_PNG
	watch_signals(screen)
	await wait_frames(1)
	var share: Button = screen.get_node("%ShareButton")
	assert_eq(share.text, "Share your path")
	assert_eq(screen.get_node("%PlayAgainButton").text, "Play again")
	var buttons := screen.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), 2, "Play again and Share your path, nothing else")
	share.pressed.emit()
	assert_signal_emitted_with_parameters(screen, "path_card_saved", [SCRATCH_PNG])
	assert_true(FileAccess.file_exists(SCRATCH_PNG), "the card is on the device")
