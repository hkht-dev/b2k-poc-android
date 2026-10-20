## Every scheme can reach everything (GDD §11 "Controls", owner review
## 2026-10-20: "what controls are there, what controls are not there").
##
## The suite drives most input with `InputEventAction`, which bypasses the
## input map entirely, so a missing binding looks exactly like a passing
## test. These assertions read the map itself and press the real actions.
extends GutTest

const TITLE := preload("res://scenes/ui/TitleScreen.tscn")
const PAUSE := preload("res://scenes/ui/PauseMenu.tscn")
const SETTINGS := preload("res://scenes/ui/SettingsScreen.tscn")
const HINT := preload("res://scenes/ui/ControlsHint.tscn")
const CARDS := preload("res://scenes/ui/ChoiceCards.tscn")
const SCRATCH := "user://test_controls_coverage_journey.json"
## Godot 4.3 ships these with keys only; the project binds A and B.
const ACCEPT_BUTTON := JOY_BUTTON_A
const CANCEL_BUTTON := JOY_BUTTON_B

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


func _joypad_buttons(action: String) -> Array:
	var out: Array = []
	for event: InputEvent in InputMap.action_get_events(action):
		var button := event as InputEventJoypadButton
		if button != null:
			out.append(button.button_index)
	return out


func _keys(action: String) -> Array:
	var out: Array = []
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			out.append(key.keycode)
	return out


func _press(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


# -- the input map ------------------------------------------------------------


func test_accept_and_cancel_carry_a_gamepad_button() -> void:
	# Every Button in the engine fires on ui_accept. Without these a pad
	# could not press Begin, choose a card or close a screen.
	assert_has(_joypad_buttons("ui_accept"), ACCEPT_BUTTON, "A accepts")
	assert_has(_joypad_buttons("ui_cancel"), CANCEL_BUTTON, "B cancels")


func test_accept_and_cancel_keep_their_keys() -> void:
	# Naming an action in project.godot replaces its default, so the
	# keyboard events have to be written out again beside the pad button.
	assert_has(_keys("ui_accept"), KEY_ENTER, "Enter still accepts")
	assert_has(_keys("ui_accept"), KEY_SPACE, "Space still accepts")
	assert_has(_keys("ui_cancel"), KEY_ESCAPE, "Escape still cancels")


func test_the_world_actions_carry_both_a_key_and_a_button() -> void:
	for action: String in ["contextual", "pause", "move_forward", "move_left"]:
		assert_false(
			InputMap.action_get_events(action).is_empty(), "%s is bound to something" % action
		)
	assert_has(_joypad_buttons("contextual"), JOY_BUTTON_A, "A uses the thing in front of you")
	assert_has(_joypad_buttons("pause"), JOY_BUTTON_START, "Start pauses")


# -- the screens that used to trap the player ---------------------------------


func test_the_title_can_be_started_from_a_pad() -> void:
	var title: Control = add_child_autofree(TITLE.instantiate())
	watch_signals(title)
	await wait_frames(1)
	var begin: Button = title.get_node("%BeginButton")
	assert_true(begin.has_focus(), "the pad has something to press")
	assert_true(begin.focus_mode != Control.FOCUS_NONE, "and it can take focus")
	# A real pad press, through the input map, into the focused button.
	var press := InputEventJoypadButton.new()
	press.button_index = ACCEPT_BUTTON
	press.pressed = true
	assert_true(press.is_action_pressed("ui_accept"), "the map turns A into accept")
	begin._gui_input(press)
	await wait_frames(1)
	assert_signal_emitted(title, "begin_pressed", "A starts the game")


func test_the_pause_menu_closes_with_the_control_that_opened_it() -> void:
	var menu: Control = add_child_autofree(PAUSE.instantiate())
	watch_signals(menu)
	await wait_frames(1)
	menu._unhandled_input(_press("pause"))
	assert_signal_emitted(menu, "resumed", "Start, or Escape, closes it again")
	watch_signals(menu)
	menu._unhandled_input(_press("ui_cancel"))
	assert_signal_emitted(menu, "resumed", "so does cancel")


func test_settings_and_the_controls_card_can_be_cancelled() -> void:
	var settings: Control = add_child_autofree(SETTINGS.instantiate())
	watch_signals(settings)
	await wait_frames(1)
	settings._unhandled_input(_press("ui_cancel"))
	assert_signal_emitted(settings, "closed", "settings close on cancel")
	var hint: Control = add_child_autofree(HINT.instantiate())
	watch_signals(hint)
	await wait_frames(1)
	hint._unhandled_input(_press("ui_cancel"))
	assert_signal_emitted(hint, "dismissed", "the card goes away on cancel")


func test_a_line_with_nothing_to_choose_is_dismissed_by_cancel_or_the_verb_button() -> void:
	for action: String in ["ui_cancel", "contextual"]:
		var cards: Control = add_child_autofree(CARDS.instantiate())
		cards.bind(Content.dialogue)
		cards.show_line(Content.dialogue.get_line("fountain_look"))
		await wait_frames(1)
		assert_eq(cards.card_count(), 0, "a thought, with nothing to choose")
		watch_signals(cards)
		cards._unhandled_input(_press(action))
		assert_signal_emitted(cards, "dismissed", "%s closes the line" % action)


func test_a_card_is_chosen_by_the_same_button_that_uses_the_world() -> void:
	var cards: Control = add_child_autofree(CARDS.instantiate())
	cards.bind(Content.dialogue)
	cards.show_line(Content.dialogue.get_line("gopal_greet"))
	await wait_frames(1)
	assert_gt(cards.card_count(), 0, "a line with cards")
	var card: PanelContainer = cards.card_button(0)
	watch_signals(card)
	card._on_gui_input(_press("contextual"))
	assert_signal_emitted(card, "pressed", "A answers a card")
