## Tests The Counting Man (GDD §7): Talk at the bench, the count screen from
## the card, a hundred and eight taps, the coin card and sitting with him all
## free him through the quest data; he walks off and hums one note; nothing
## on the HUD shows a number while counting.
extends GutTest

const STREET := preload("res://scenes/street/Street.tscn")
const SCRATCH := "user://test_counting_man_journey.json"
## Standing in front of him, on the road side of the bench.
const TALK_SPOT := Vector3(11.4, 0.3, 19.4)
## Standing in front of the empty seat beside him.
const SIT_SPOT := Vector3(10.2, 0.3, 19.7)
const DIGIT := "[0-9]"

var _real_path := ""
var _digit := RegEx.new()


func before_all() -> void:
	_digit.compile(DIGIT)


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


func _man(street: Node3D) -> Node3D:
	return street.get_node("%CountingMan")


func _button(street: Node3D) -> Button:
	return street.get_node("%TouchControls").contextual_button()


func _put(street: Node3D, where: Vector3) -> void:
	street.get_node("%Player").global_position = where
	await wait_frames(8)


func _press(street: Node3D) -> void:
	_button(street).pressed.emit()
	await wait_frames(2)


## Talks to him and picks the card with [param index] on his first line.
func _talk_and_pick(street: Node3D, index: int) -> void:
	await _put(street, TALK_SPOT)
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "counting_man_greet", "his first line")
	Content.dialogue.choose(index)
	await wait_frames(2)


func _texts_with_digits(root: Node) -> PackedStringArray:
	var found := PackedStringArray()
	for node: Node in root.find_children("*", "Control", true, false):
		if not (node as Control).is_visible_in_tree():
			continue
		var text := ""
		if node is Label or node is Button or node is LineEdit:
			text = node.text
		elif node is RichTextLabel:
			text = node.get_parsed_text()
		if _digit.search(text) != null:
			found.append("%s: %s" % [node.get_path(), text])
	return found


func test_he_sits_at_the_bench_counting_and_offers_talk() -> void:
	var street := _street()
	var man := _man(street)
	await wait_frames(2)
	assert_eq(man.figure().state(), "pose", "he sits")
	assert_true(street.get_node("BusStop/Coins").visible, "the coins are on the seat")
	assert_eq(Content.quest("counting_man").status(), Quest.Status.INACTIVE, "nothing yet")
	await _put(street, TALK_SPOT)
	assert_eq(_button(street).current_verb(), "verb.talk", "he offers Talk")
	assert_false(man.is_freed())


func test_the_count_card_opens_the_count_screen() -> void:
	var street := _street()
	var man := _man(street)
	await _talk_and_pick(street, 0)
	assert_true(GameState.has_flag("counting_man_met"))
	assert_eq(Content.quest("counting_man").status(), Quest.Status.ACTIVE, "met: the quest opens")
	assert_true(GameState.has_flag("counting_man_counting"), "the card's flag")
	var screen: Control = man.count_screen()
	assert_not_null(screen, "the count screen opened")
	assert_true(screen.is_visible_in_tree())
	assert_eq(screen.get_parent(), street.get_node("UI"), "on the place's HUD layer")
	assert_false(street.cards().visible, "the cards are gone")
	assert_eq(screen.coins_left(), 108)
	assert_false(screen.is_finished())
	assert_false(man.is_freed())


func test_tapping_every_coin_frees_him_and_ends_the_quest_on_the_counted_branch() -> void:
	var street := _street()
	var man := _man(street)
	watch_signals(man)
	await _talk_and_pick(street, 0)
	var screen: Control = man.count_screen()
	for _i in 107:
		screen.tap_next()
	assert_false(GameState.has_event("counting_man_counted"), "one coin short is not the total")
	assert_false(man.is_freed())
	screen.tap_next()
	assert_true(screen.is_finished())
	assert_true(GameState.has_event("counting_man_counted"))
	assert_true(GameState.has_flag("counting_man_freed"), "the quest's branch set it")
	assert_signal_emitted(man, "freed")
	var quest: Quest = Content.quest("counting_man")
	assert_eq(quest.status(), Quest.Status.ENDED)
	assert_eq(quest.ended_branch(), "counted")
	assert_true(GameState.journey_lines.has("journey.counting_man.counted"))
	assert_eq(screen.hint_text(), Strings.t("count.total"), "the end line says it in words")
	assert_null(_digit.search(screen.hint_text()), "and not as a figure")
	await wait_frames(2)
	assert_false(man.is_walking(), "he waits for the screen to close")
	screen.tap_next()
	assert_eq(screen.coins_left(), 0, "a tap after the last does nothing more")
	screen.close()
	await wait_frames(3)
	assert_null(man.count_screen(), "closed")
	assert_false(GameState.has_flag("counting_man_counting"), "the card's flag is cleared")
	assert_true(man.is_walking(), "he gets up and goes")
	assert_false(street.get_node("BusStop/Coins").visible, "he took his coins")
	await _put(street, TALK_SPOT)
	assert_ne(_button(street).current_verb(), "verb.talk", "nothing to say now")


func test_enter_taps_the_next_coin_and_escape_stops() -> void:
	var street := _street()
	var man := _man(street)
	await _talk_and_pick(street, 0)
	var screen: Control = man.count_screen()
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	Input.parse_input_event(accept)
	await wait_frames(2)
	assert_eq(screen.coins_left(), 107, "Enter took one coin")
	assert_eq(Content.dialogue.is_running(), false, "and reached no card underneath")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await wait_frames(3)
	assert_null(man.count_screen(), "Escape stopped the count")
	assert_false(street.is_paused(), "without pausing")
	assert_false(man.is_freed(), "stopping frees nobody")
	assert_eq(Content.quest("counting_man").status(), Quest.Status.ACTIVE)


func test_stopping_the_count_frees_nobody_and_it_can_start_again() -> void:
	var street := _street()
	var man := _man(street)
	await _talk_and_pick(street, 0)
	var screen: Control = man.count_screen()
	for _i in 20:
		screen.tap_next()
	screen.stop_button().pressed.emit()
	await wait_frames(3)
	assert_null(man.count_screen())
	assert_false(GameState.has_flag("counting_man_counting"))
	assert_false(man.is_freed())
	await _put(street, TALK_SPOT)
	assert_eq(_button(street).current_verb(), "verb.talk", "he is still there")
	await _press(street)
	assert_eq(Content.dialogue.current_line_id(), "counting_man_again", "his second greeting")
	Content.dialogue.choose(0)
	await wait_frames(2)
	assert_not_null(man.count_screen(), "the count starts over")
	assert_eq(man.count_screen().coins_left(), 108, "from the first coin")


func test_the_coin_card_frees_him_at_once() -> void:
	var street := _street()
	var man := _man(street)
	await _talk_and_pick(street, 1)
	assert_true(GameState.has_flag("counting_man_given_coin"))
	assert_true(GameState.has_flag("counting_man_freed"))
	var quest: Quest = Content.quest("counting_man")
	assert_eq(quest.status(), Quest.Status.ENDED)
	assert_eq(quest.ended_branch(), "coin")
	assert_true(GameState.journey_lines.has("journey.counting_man.coin"))
	assert_eq(Content.dialogue.current_line_id(), "counting_man_coin", "he says the round number")
	assert_false(man.is_walking(), "he waits for his line to be dismissed")
	Content.dialogue.dismiss()
	await wait_frames(3)
	assert_true(man.is_walking())
	assert_null(man.count_screen(), "no count screen on this path")


func test_sitting_with_him_until_he_laughs_frees_him() -> void:
	var street := _street()
	var man := _man(street)
	man.sit_seconds = 0.3
	watch_signals(man)
	await _put(street, SIT_SPOT)
	assert_eq(_button(street).current_verb(), "verb.sit", "the seat beside him offers Sit")
	await _press(street)
	var rig: CharacterRig = street.get_node("%Player/Mesh")
	assert_eq(rig.state(), "pose", "the player sits")
	assert_true(man.is_sitting_with_player())
	assert_false(man.is_freed())
	await wait_seconds(0.6)
	assert_signal_emitted(man, "laughed")
	assert_true(GameState.has_event("counting_man_laughed"))
	assert_true(GameState.has_flag("counting_man_freed"))
	var quest: Quest = Content.quest("counting_man")
	assert_eq(quest.status(), Quest.Status.ENDED, "sitting with him is meeting him")
	assert_eq(quest.ended_branch(), "sat")
	assert_true(GameState.journey_lines.has("journey.counting_man.sat"))
	assert_eq(
		street.get_node("%TouchControls").subtitle_text(),
		Strings.t("sub.counting_man_laugh"),
		"the laugh is subtitled"
	)
	assert_ne(rig.state(), "pose", "the player is let up")
	assert_true(man.is_walking())


func test_he_walks_off_down_the_street_and_hums_one_note_once() -> void:
	var street := _street()
	var man := _man(street)
	man.walk_speed = 30.0
	watch_signals(man)
	var bench := man.global_position
	GameState.fire_event("counting_man_laughed")
	assert_true(man.is_freed())
	await wait_frames(6)
	assert_true(man.is_walking())
	assert_gt(man.global_position.distance_to(bench), 0.5, "he has left the bench")
	assert_ne(man.figure().state(), "pose", "on his feet")
	await wait_seconds(2.0)
	assert_signal_emit_count(man, "note_hummed", 1, "one note, once")
	assert_true(man.note_played())
	assert_signal_emitted(man, "walked_off")
	assert_true(man.has_gone())
	assert_false(man.visible, "gone down the street")
	assert_false(man.get_node("%Talk").is_available())
	assert_true(GameState.journey_lines.has("journey.counting_man.sat"), "the journey has its line")


func test_nothing_on_the_hud_shows_a_number_while_counting() -> void:
	var street := _street()
	var man := _man(street)
	await _talk_and_pick(street, 0)
	var screen: Control = man.count_screen()
	for _i in 50:
		screen.tap_next()
	await wait_frames(2)
	assert_eq(_texts_with_digits(street), PackedStringArray(), "no figure anywhere on screen")
	for node: Node in street.find_children("*", "Range", true, false):
		assert_false((node as Control).is_visible_in_tree(), "no meter: %s" % node.name)
	for index in 108:
		var coin: Button = screen.coin(index)
		assert_eq(coin.text, "", "coins carry no number")
		assert_eq(
			coin.get_theme_stylebox("normal"),
			screen.coin(0).get_theme_stylebox("normal"),
			"every coin drawn the same"
		)
	assert_false(street.cards().visible, "no cards while counting")
	assert_true(screen.get_node("%Coins").visible)


func test_a_freed_man_is_not_at_the_bench_on_a_loaded_journey() -> void:
	GameState.set_flag("counting_man_freed")
	var street := _street()
	var man := _man(street)
	await wait_frames(2)
	assert_true(man.has_gone())
	assert_false(man.visible)
	assert_false(street.get_node("BusStop/Coins").visible)
	await _put(street, TALK_SPOT)
	assert_ne(_button(street).current_verb(), "verb.talk")
	assert_ne(_button(street).current_verb(), "verb.sit")
	assert_false(man.note_played(), "no note for an empty bench")
