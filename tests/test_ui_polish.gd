## Tests the interface on every device (GDD §11 "UI, controls, accessibility";
## docs/BRIEF_AMENDMENT_1.md §A5; owner request 2026-10-20 "intuitive, very
## easy for the users on all devices"): the one theme's sizes and focus ring,
## safe areas and orientation in the HUD, the key badge, the cards at a
## keyboard and on a gamepad, and the place's name on arriving through a door.
extends GutTest

const THEME := preload("res://assets/ui/theme.tres")
const CONTROLS := preload("res://scenes/ui/TouchControls.tscn")
const TOUCH_CONTROLS := preload("res://scripts/ui/touch_controls.gd")
const CARDS := preload("res://scenes/ui/ChoiceCards.tscn")
const SETTINGS := preload("res://scenes/ui/SettingsScreen.tscn")
const STORE := preload("res://scenes/places/Store.tscn")
const STREET := preload("res://scenes/street/Street.tscn")
## Every scene a player sees, with the control that should hold the focus
## when it opens ("" where the focus arrives later or there is none).
const SCREENS := {
	"res://scenes/ui/TitleScreen.tscn": "%BeginButton",
	"res://scenes/ui/ControlsHint.tscn": "%GotItButton",
	"res://scenes/ui/PauseMenu.tscn": "%ResumeButton",
	"res://scenes/ui/SettingsScreen.tscn": "",
	"res://scenes/ui/EndScreen.tscn": "",
	"res://scenes/ui/ChoiceCards.tscn": "",
	"res://scenes/core/DebugPanel.tscn": "%CloseButton",
	"res://scenes/ui/TouchControls.tscn": "",
}
const SCRATCH := "user://test_ui_polish_journey.json"
const MIN_BUTTON_HEIGHT := 72.0
const MIN_TAP := 56.0
const PORTRAIT := Vector2(1080, 1920)
const LANDSCAPE := Vector2(3413, 1920)
const NOTCH := 120.0

var _real_path := ""


func before_each() -> void:
	_real_path = GameState.save_path
	GameState.save_path = SCRATCH
	GameState.set_autosave(false)
	GameState.wipe()
	TOUCH_CONTROLS.safe_area_override = null


func after_each() -> void:
	TOUCH_CONTROLS.safe_area_override = null
	get_tree().paused = false
	get_tree().root.content_scale_factor = 1.0
	GameState.wipe()
	GameState.save_path = _real_path
	GameState.set_autosave(true)


func _controls(scheme: String, size: Vector2 = PORTRAIT) -> Control:
	var controls: Control = add_child_autofree(CONTROLS.instantiate())
	controls.size = size
	controls.apply_scheme(scheme)
	return controls


func _key(keycode: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	return event


## A real keypress: through Input to the window, as the keyboard sends it,
## pressed and released so no action is left held for the next test.
func _type(keycode: Key) -> void:
	Input.parse_input_event(_key(keycode))
	await wait_frames(1)
	Input.parse_input_event(_key(keycode, false))
	await wait_frames(1)


func _buttons(root: Node) -> Array[Node]:
	return root.find_children("*", "Button", true, false)


# -- the one theme -------------------------------------------------------------


func test_the_theme_gives_a_plain_button_the_minimum_height() -> void:
	var button := Button.new()
	button.text = Strings.t("controls.got_it")
	add_child_autofree(button)
	assert_eq(
		button.get_theme_stylebox("normal"),
		THEME.get_stylebox("normal", "Button"),
		"the project theme reaches a bare Button"
	)
	assert_gte(button.get_combined_minimum_size().y, MIN_BUTTON_HEIGHT)


func test_focus_is_visible_and_the_mouse_states_differ() -> void:
	assert_true(THEME.has_stylebox("focus", "Button"), "a focus stylebox exists")
	var focus: StyleBoxFlat = THEME.get_stylebox("focus", "Button")
	assert_gte(focus.border_width_top, 3, "a thick ring")
	assert_false(focus.draw_center, "drawn over the button, not instead of it")
	assert_true(THEME.has_stylebox("focus", "CheckButton"), "toggles show it too")
	var normal: StyleBox = THEME.get_stylebox("normal", "Button")
	assert_ne(THEME.get_stylebox("hover", "Button"), normal, "hover reads differently")
	assert_ne(THEME.get_stylebox("pressed", "Button"), normal, "so does pressed")
	assert_ne(THEME.get_stylebox("pressed", "Button"), THEME.get_stylebox("hover", "Button"))
	assert_gte((normal as StyleBoxFlat).corner_radius_top_left, 6, "rounded corners")


func test_the_slider_grabber_is_sized_for_a_thumb() -> void:
	var grabber: Texture2D = THEME.get_icon("grabber", "HSlider")
	assert_not_null(grabber)
	assert_gte(grabber.get_width(), 28)
	assert_gte(grabber.get_height(), 28)


func test_every_screen_uses_the_theme_and_every_button_is_a_tap_target() -> void:
	for path: String in SCREENS:
		var screen: Control = add_child_autofree(load(path).instantiate())
		assert_null(screen.theme, "%s inherits the project theme" % path)
		var buttons := _buttons(screen)
		for button: Button in buttons:
			var where := "%s %s" % [path.get_file(), button.name]
			assert_gte(button.get_combined_minimum_size().y, MIN_TAP, where)
			assert_eq(
				button.get_theme_stylebox("focus"),
				THEME.get_stylebox("focus", button.get_class()),
				"%s draws the theme's focus ring" % where
			)
		screen.queue_free()
		await wait_frames(1)


func test_the_first_control_takes_the_focus_when_a_screen_opens() -> void:
	for path: String in SCREENS:
		var wanted: String = SCREENS[path]
		if wanted.is_empty():
			continue
		var screen: Control = add_child_autofree(load(path).instantiate())
		assert_eq(
			screen.get_viewport().gui_get_focus_owner(),
			screen.get_node(wanted),
			"%s opens with %s focused" % [path.get_file(), wanted]
		)
		screen.queue_free()
		await wait_frames(1)


func test_settings_focus_starts_on_the_first_row_and_walks_down_to_back() -> void:
	var settings: Control = add_child_autofree(SETTINGS.instantiate())
	var first: Control = settings.first_control()
	assert_eq(settings.get_viewport().gui_get_focus_owner(), first)
	assert_ne(first, settings.get_node("%CloseButton"), "a setting, not Back, comes first")
	var control: Control = first
	var steps := 0
	while control != settings.get_node("%CloseButton") and steps < settings.ROWS.size() + 1:
		var below: Control = control.get_node(control.focus_neighbor_bottom)
		assert_eq(below.get_node(below.focus_neighbor_top), control, "and up comes back")
		control = below
		steps += 1
	assert_eq(steps, settings.ROWS.size(), "every row is one step down")
	assert_eq(control.get_node(control.focus_neighbor_bottom), first, "Back wraps to the top")
	for key: String in ["joystick_side", "large_text"]:
		var toggle: Control = settings.control_for(key)
		assert_gte(toggle.get_combined_minimum_size().y, MIN_TAP, key)
		assert_gte(toggle.get_combined_minimum_size().x, MIN_TAP, key)
	var slider: Control = settings.control_for("camera_sensitivity")
	assert_gte(slider.get_combined_minimum_size().y, MIN_TAP)


# -- the HUD: safe areas and orientation -------------------------------------


func test_the_hud_sits_a_gutter_inside_the_screen_by_default() -> void:
	var controls := _controls("touch")
	var pause: Button = controls.pause_button()
	assert_eq(pause.position, Vector2(32, 48), "the pause button where it has always been")
	assert_gte(pause.size.y, 88.0, "and still a thumb")
	assert_eq(pause.size.x, pause.size.y, "and square")
	assert_eq(controls.compass().offset_top, 40.0)
	assert_eq(controls.contextual_button().offset_right, -48.0)
	assert_eq(controls.contextual_button().offset_bottom, -112.0)


func test_a_notch_at_the_top_moves_the_pause_button_and_the_compass_down() -> void:
	var controls := _controls("touch")
	var before: Vector2 = controls.pause_button().position
	var compass_before: float = controls.compass().offset_top
	TOUCH_CONTROLS.safe_area_override = Rect2(0, NOTCH, PORTRAIT.x, PORTRAIT.y - NOTCH)
	controls.layout()
	assert_eq(controls.pause_button().position, before + Vector2(0, NOTCH))
	assert_eq(controls.compass().offset_top, compass_before + NOTCH)
	assert_eq(controls.contextual_button().offset_bottom, -112.0, "the bottom did not move")


func test_a_safe_area_inset_on_every_side_keeps_the_hud_a_gutter_inside_it() -> void:
	var controls := _controls("touch")
	var safe := Rect2(30, NOTCH, PORTRAIT.x - 30 - 40, PORTRAIT.y - NOTCH - 60)
	TOUCH_CONTROLS.safe_area_override = safe
	controls.layout()
	var gutter: float = controls.GUTTER
	var pause: Rect2 = controls.pause_button().get_rect()
	assert_gte(pause.position.x, safe.position.x + gutter)
	assert_gte(pause.position.y, safe.position.y + gutter)
	var button: Rect2 = controls.contextual_button().get_rect()
	assert_lte(button.end.x, safe.end.x - gutter, "the button clears the right inset")
	assert_lte(button.end.y, safe.end.y - gutter, "and the bottom one")
	var subtitle: Rect2 = controls.subtitle_label().get_rect()
	assert_lt(subtitle.end.y, button.position.y, "the subtitle stays above the button")
	assert_lte(controls.compass().get_rect().end.y, controls.minimap().offset_top)
	TOUCH_CONTROLS.safe_area_override = null
	controls.layout()
	assert_eq(controls.pause_button().position, Vector2(32, 48), "and back without one")


func test_portrait_gives_the_subtitle_ninety_percent_and_landscape_a_column() -> void:
	var controls := _controls("touch", PORTRAIT)
	assert_true(controls.is_portrait())
	var subtitle: Label = controls.subtitle_label()
	assert_almost_eq(subtitle.size.x, PORTRAIT.x * 0.9, 0.5, "90 % of a phone held upright")
	assert_almost_eq(subtitle.get_rect().get_center().x, PORTRAIT.x * 0.5, 0.5, "centred")
	assert_almost_eq(controls.compass().get_rect().get_center().x, PORTRAIT.x * 0.5, 0.5)

	controls.size = LANDSCAPE
	assert_false(controls.is_portrait())
	assert_almost_eq(subtitle.size.x, controls.SUBTITLE_WIDTH_LANDSCAPE, 0.5, "re-laid on resize")
	assert_almost_eq(subtitle.get_rect().get_center().x, LANDSCAPE.x * 0.5, 0.5)
	assert_almost_eq(controls.compass().get_rect().get_center().x, LANDSCAPE.x * 0.5, 0.5)
	var button: Rect2 = controls.contextual_button().get_rect()
	assert_almost_eq(button.end.x, LANDSCAPE.x - 48.0, 0.5, "the button stays bottom-right")
	assert_almost_eq(button.end.y, LANDSCAPE.y - 112.0, 0.5)
	assert_eq(controls.pause_button().position, Vector2(32, 48), "and pause top-left")
	assert_true(controls.joystick().owns_point(Vector2(200, 1500)), "the joystick keeps the left")


# -- the key badge -------------------------------------------------------------


func test_the_contextual_button_wears_its_key_off_touch_and_never_on_it() -> void:
	assert_true(Strings.has_id("controls.key.desktop_use"), "the key is a word in the table")
	assert_true(Strings.has_id("controls.key.gamepad_use"))
	var controls := _controls("desktop")
	var button: Button = controls.contextual_button()
	assert_true(button.key_badge_visible(), "a keyboard player is told the key")
	assert_eq(button.key_badge_text(), Strings.t("controls.key.desktop_use"))
	var badge: Label = button.get_node("KeyBadge")
	assert_true(badge.visible)
	assert_gte(badge.size.x, 28.0, "a badge, not a dot")
	controls.apply_scheme("gamepad")
	assert_true(button.key_badge_visible())
	assert_eq(button.key_badge_text(), Strings.t("controls.key.gamepad_use"))
	controls.apply_scheme("touch")
	assert_false(button.key_badge_visible(), "a thumb needs no key")
	assert_eq(button.text, Strings.t("verb.idle"), "the verb label is untouched")


# -- the cards on every device -------------------------------------------------


func test_touch_cards_are_thumb_high_with_room_between_them() -> void:
	var cards: Control = add_child_autofree(CARDS.instantiate())
	cards.apply_scheme("touch")
	cards.show_line(Content.dialogue.get_line("gopal_greet"))
	for index in cards.card_count():
		assert_gte(cards.card_button(index).custom_minimum_size.y, 96.0)
	var stack: VBoxContainer = cards.get_node("%Cards")
	assert_gte(stack.get_theme_constant("separation"), 16)
	assert_eq(cards.focused_card(), -1, "no card is picked out on touch")
	cards.apply_scheme("desktop")
	for index in cards.card_count():
		assert_gte(cards.card_button(index).custom_minimum_size.y, MIN_BUTTON_HEIGHT)


func test_number_keys_choose_a_card_on_desktop_and_escape_dismisses_a_cardless_line() -> void:
	var cards: Control = add_child_autofree(CARDS.instantiate())
	cards.apply_scheme("desktop")
	cards.show_line(Content.dialogue.get_line("gopal_greet"))
	assert_eq(cards.card_count(), 2)
	assert_eq(cards.focused_card(), -1, "nothing is picked out until a key asks")
	watch_signals(cards)
	await _type(KEY_2)
	assert_signal_emitted_with_parameters(cards, "card_pressed", [1])
	cards._unhandled_input(_key(KEY_3))
	assert_signal_emit_count(cards, "card_pressed", 1, "there is no third card")
	cards._unhandled_input(_key(KEY_KP_1))
	assert_signal_emit_count(cards, "card_pressed", 2, "the keypad counts too")
	assert_signal_emitted_with_parameters(cards, "card_pressed", [0], 1)
	cards._unhandled_input(_key(KEY_ESCAPE))
	assert_signal_not_emitted(cards, "dismissed", "with cards up, Esc is not an answer")
	cards.show_line(Content.dialogue.get_line("gopal_decline"))
	assert_eq(cards.card_count(), 0)
	await _type(KEY_ESCAPE)
	assert_signal_emitted(cards, "dismissed", "a line with no cards closes on Esc")


func test_an_arrow_puts_the_focus_on_a_card_at_a_keyboard() -> void:
	var cards: Control = add_child_autofree(CARDS.instantiate())
	cards.apply_scheme("desktop")
	cards.show_line(Content.dialogue.get_line("gopal_greet"))
	cards._unhandled_input(_key(KEY_DOWN))
	assert_eq(cards.focused_card(), 0, "down from nothing lands on the first card")
	cards.get_viewport().push_input(_key(KEY_DOWN))
	assert_eq(cards.focused_card(), 1, "and walks on")
	cards.get_viewport().push_input(_key(KEY_DOWN))
	assert_eq(cards.focused_card(), 0, "wrapping")
	cards.get_viewport().push_input(_key(KEY_UP))
	assert_eq(cards.focused_card(), 1, "and back")
	await wait_frames(1)


func test_on_a_gamepad_the_first_card_has_the_focus_and_accept_chooses() -> void:
	var cards: Control = add_child_autofree(CARDS.instantiate())
	cards.apply_scheme("gamepad")
	cards.show_line(Content.dialogue.get_line("gopal_admit"))
	assert_eq(cards.focused_card(), 0, "the cursor has to be somewhere")
	var first: PanelContainer = cards.card_button(0)
	var second: PanelContainer = cards.card_button(1)
	assert_eq(first.theme_type_variation, second.theme_type_variation, "same style")
	assert_eq(first.modulate, second.modulate, "same colour")
	cards.get_viewport().push_input(_key(KEY_DOWN))
	assert_eq(cards.focused_card(), 1, "the d-pad moves the cursor")
	watch_signals(cards)
	cards.get_viewport().push_input(_key(KEY_ENTER))
	assert_signal_emitted_with_parameters(cards, "card_pressed", [1], 0)


func test_the_place_forwards_the_scheme_to_its_cards() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	var controls: Control = street.get_node("%TouchControls")
	controls.apply_scheme("gamepad")
	assert_eq(street.cards().scheme(), "gamepad")
	controls.apply_scheme("touch")
	assert_eq(street.cards().scheme(), "touch")
	await wait_frames(1)


# -- where am I ----------------------------------------------------------------


func test_arriving_through_a_door_shows_the_place_name_once_as_a_subtitle() -> void:
	GameState.set_place("store", "store_door")
	var store: Node3D = add_child_autofree(STORE.instantiate())
	var controls: Control = store.get_node("%TouchControls")
	assert_eq(controls.subtitle_text(), Strings.t(Places.name_id_of("store")))
	assert_eq(controls.subtitle_text(), "Hollow Vale Stores")
	await wait_seconds(store.PLACE_NAME_SECONDS + 0.4)
	assert_eq(controls.subtitle_text(), "", "and it is gone")


func test_a_fresh_journey_shows_no_place_name() -> void:
	var street: Node3D = add_child_autofree(STREET.instantiate())
	street.get_node("%TouchControls").apply_scheme("touch")
	assert_eq(GameState.spawn, "")
	assert_eq(street.get_node("%TouchControls").subtitle_text(), "")
	await wait_frames(1)
