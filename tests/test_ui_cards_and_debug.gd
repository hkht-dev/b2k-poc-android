## Tests the choice cards, the debug panel and the five-tap that opens it.
##
## These use the real autoloads (Content, GameState), so the journey is pointed
## at a scratch file and autosave is off for the duration; nothing here can
## touch a player's real save.
extends GutTest

const CARDS := preload("res://scenes/ui/ChoiceCards.tscn")
const TITLE := preload("res://scenes/ui/TitleScreen.tscn")
const MAIN := preload("res://scenes/core/Main.tscn")
const SCRATCH := "user://test_ui_journey.json"

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


func _press(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	control.gui_input.emit(event)


# -- cards --------------------------------------------------------------------


func test_cards_are_hidden_until_a_line_is_shown() -> void:
	var cards: Control = add_child_autofree(CARDS.instantiate())
	assert_false(cards.visible, "the HUD is empty by default")


func test_a_line_shows_speaker_text_and_one_button_per_card_from_data() -> void:
	var cards: Control = add_child_autofree(CARDS.instantiate())
	var line := Content.dialogue.get_line("gopal_greet")
	cards.show_line(line)
	assert_true(cards.visible)
	assert_eq(cards.get_node("%Speaker").text, Strings.t("speaker.gopal"))
	assert_eq(cards.get_node("%Line").text, Strings.t("line.gopal_greet"))
	assert_eq(cards.card_count(), 3)
	for index: int in cards.card_count():
		assert_eq(
			cards.card_button(index).text,
			Strings.t(line["cards"][index]["text_id"]),
			"each button wears its own card's words, from the table"
		)


func test_every_card_is_drawn_the_same_way() -> void:
	var cards: Control = add_child_autofree(CARDS.instantiate())
	cards.show_line(Content.dialogue.get_line("gopal_admit"))
	var first: PanelContainer = cards.card_button(0)
	var second: PanelContainer = cards.card_button(1)
	assert_eq(first.find_children("*", "TextureRect", true, false).size(), 0, "no icon on a card")
	assert_eq(first.modulate, second.modulate, "no colour difference")
	assert_eq(first.theme_type_variation, second.theme_type_variation, "no style difference")
	assert_eq(first.custom_minimum_size, second.custom_minimum_size, "no size difference")


func test_pressing_a_card_reports_its_index() -> void:
	var cards: Control = add_child_autofree(CARDS.instantiate())
	cards.show_line(Content.dialogue.get_line("gopal_greet"))
	watch_signals(cards)
	cards.card_button(1).pressed.emit()
	assert_signal_emitted_with_parameters(cards, "card_pressed", [1])


func test_bound_cards_follow_the_conversation_and_hide_at_the_end() -> void:
	var cards: Control = add_child_autofree(CARDS.instantiate())
	cards.bind(Content.dialogue)
	assert_true(Content.dialogue.start("gopal_greet"))
	assert_true(cards.visible)
	cards.card_button(0).pressed.emit()
	assert_eq(Content.dialogue.current_line_id(), "gopal_fear_1")
	assert_eq(
		cards.get_node("%Line").text, Strings.t("line.gopal_fear_1"), "the next line is drawn"
	)
	cards.card_button(0).pressed.emit()
	cards.card_button(0).pressed.emit()
	cards.card_button(1).pressed.emit()
	assert_true(GameState.has_flag("gopal_admitted_fear"), "the card set its flag")
	assert_eq(cards.card_count(), 0, "gopal_decline offers no cards")
	_press(cards.get_node("%Dim"))
	assert_false(cards.visible, "a tap anywhere dismisses a cardless line")
	assert_false(Content.dialogue.is_running())
	cards.unbind()
	await wait_frames(1)


func test_a_tap_outside_does_nothing_while_cards_are_offered() -> void:
	var cards: Control = add_child_autofree(CARDS.instantiate())
	cards.show_line(Content.dialogue.get_line("gopal_greet"))
	watch_signals(cards)
	_press(cards.get_node("%Dim"))
	assert_signal_not_emitted(cards, "dismissed", "with cards up, only a card is an answer")


# -- debug panel --------------------------------------------------------------


func test_the_debug_panel_lists_every_flag_the_data_knows() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	main.open_debug_panel()
	var panel: Control = main.debug_panel()
	assert_not_null(panel)
	for flag in Content.known_flags():
		assert_not_null(panel.flag_toggle(flag), "a toggle for '%s'" % flag)
	main.close_debug_panel()
	await wait_frames(1)


func test_toggling_a_flag_in_the_panel_sets_it_in_the_journey() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	main.open_debug_panel()
	var panel: Control = main.debug_panel()
	var toggle: CheckButton = panel.flag_toggle("heard_tulu")
	if toggle == null:
		toggle = panel.flag_toggle("looked_dry_fountain")
	assert_not_null(toggle)
	toggle.button_pressed = true
	assert_true(GameState.has_flag(toggle.text), "the tester set a flag")
	toggle.button_pressed = false
	assert_false(GameState.has_flag(toggle.text), "and cleared it again")
	main.close_debug_panel()
	await wait_frames(1)


func test_the_panel_never_uses_score_or_progress_wording() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	main.open_debug_panel()
	var panel: Control = main.debug_panel()
	var forbidden := ["score", "points", "progress", "complete", "%", "correct"]
	for label: Node in panel.find_children("*", "Label", true, false):
		for word in forbidden:
			assert_false(
				label.text.to_lower().contains(word),
				"'%s' must not appear in the debug panel: '%s'" % [word, label.text]
			)
	main.close_debug_panel()
	await wait_frames(1)


func test_playing_a_line_from_the_panel_steps_the_quest_from_json_alone() -> void:
	# P2's gate: a quest defined only in JSON can be stepped through with
	# cards and sets flags; the debug panel shows them.
	var main: Node = add_child_autofree(MAIN.instantiate())
	main.open_debug_panel()
	var panel: Control = main.debug_panel()
	var cards: Control = panel.get_node("%Cards")
	var quest: Quest = Content.quest("dry_fountain")
	assert_eq(quest.current_step_id(), "notice")

	Content.dialogue.start("fountain_look")
	_press(cards.get_node("%Dim"))
	assert_eq(quest.current_step_id(), "hear_him_out", "looking advanced the quest")

	Content.dialogue.start("gopal_greet")
	for index in [0, 0, 1, 0]:
		cards.card_button(index).pressed.emit()
	assert_eq(quest.current_step_id(), "carry", "hearing him out advanced it again")
	await wait_frames(2)
	assert_true(
		panel.flag_toggle("gopal_will_carry").button_pressed, "and the panel shows the flag"
	)
	main.close_debug_panel()
	await wait_frames(1)


# -- five taps ----------------------------------------------------------------


func test_five_quick_taps_on_the_title_ask_for_the_debug_panel() -> void:
	var title: Control = add_child_autofree(TITLE.instantiate())
	watch_signals(title)
	for _i in 4:
		_press(title.get_node("%Title"))
	assert_signal_not_emitted(title, "debug_requested", "four is not five")
	_press(title.get_node("%Title"))
	assert_signal_emitted(title, "debug_requested")


func test_main_opens_the_panel_on_request_and_closes_it_again() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	var title: Control = main.current_screen()
	assert_null(main.debug_panel())
	for _i in 5:
		_press(title.get_node("%Title"))
	assert_not_null(main.debug_panel(), "five taps opened it")
	main.debug_panel().closed.emit()
	assert_null(main.debug_panel(), "close put it away")
	await wait_frames(1)


# -- controls hint ------------------------------------------------------------


func test_begin_shows_the_controls_card_on_a_fresh_journey() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	main.current_screen().begin_pressed.emit()
	await wait_frames(1)
	assert_true(main.current_screen().has_signal("dismissed"), "the card, not the street")
	var hint: Control = main.current_screen()
	var scheme: String = hint.current_scheme()
	assert_true(["touch", "desktop", "gamepad"].has(scheme), "a known scheme: %s" % scheme)
	var lines: VBoxContainer = hint.get_node("%Lines")
	await wait_frames(1)
	assert_eq(hint.LINE_KEYS.size(), 9, "the amendment's lines, the car's, the climb and the pause")
	assert_eq(lines.get_child_count(), hint.LINE_KEYS.size(), "a line per key")
	assert_eq(lines.get_child(0).text, Strings.t("controls.%s.move" % scheme), "its words are data")


func test_got_it_opens_the_street_and_the_card_never_comes_back() -> void:
	var main: Node = add_child_autofree(MAIN.instantiate())
	main.current_screen().begin_pressed.emit()
	await wait_frames(1)
	main.current_screen().get_node("%GotItButton").pressed.emit()
	await wait_frames(1)
	assert_not_null(main.current_screen().get_node_or_null("%Player"), "the street opened")
	assert_true(GameState.settings.get("controls_seen", false), "and the journey remembers")

	main.show_screen(main.TITLE_SCREEN)
	await wait_frames(1)
	main.current_screen().begin_pressed.emit()
	await wait_frames(1)
	assert_not_null(main.current_screen().get_node_or_null("%Player"), "straight to the street now")


func test_play_again_brings_the_card_back() -> void:
	GameState.settings["controls_seen"] = true
	GameState.wipe()
	assert_false(GameState.settings.get("controls_seen", false), "a wiped journey has not seen it")
